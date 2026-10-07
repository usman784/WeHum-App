import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/activity.dart';
import '../data/models/json.dart';
import '../errors/error_code.dart';
import '../utils/uuid7.dart';

/// Also sends the small community actions queued while offline (`pending_actions`: dedication holds and reports).
/// Meditations are written to the local outbox first and sent in the background (spec §6.2, §10).
/// Items carry a uuid v7 id, so a retry after a lost response is harmless (server is idempotent).
class SyncService extends GetxService {
  SyncService(this._repo, this._db, [this._community]);
  final MeditationRepository _repo;
  final AppDatabase _db;
  final CommunityRepository? _community;

  final pending = 0.obs;
  Future<void>? _run;
  bool _again = false;
  /// Server answers by meditation id (the payoff screen reads its numbers from here).
  final byId = <String, MeditationResult>{}.obs;
  final _waiters = <String, Completer<MeditationResult?>>{};

  /// Called when the player finishes (or is ended after ≥ 3 min, spec §13).
  Future<MeditationResult?> record(MeditationRecord m, {bool waitForServer = true}) async {
    await _db.enqueueMeditation(m.id, jsonEncode(m.toJson()));
    pending.value = await _db.outboxCount();
    final done = _waiters[m.id] = Completer<MeditationResult?>();
    unawaited(flush());
    if (!waitForServer) return null;
    // the payoff screen never waits long for the network
    return done.future.timeout(const Duration(seconds: 3), onTimeout: () => null);
  }

  MeditationResult? resultFor(String id) => byId[id];

  /// Sends everything in the outbox (≤ 50 per request) FIFO. Safe to call at any time; one run at once.
  Future<void> flush() {
    final running = _run;
    if (running != null) {
      _again = true; // something was queued while a pass runs: it gets another pass
      return running;
    }
    return _run = _drain().whenComplete(() => _run = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      await _pass();
    } while (_again);
  }

  Future<void> _pass() async {
    try {
      while (true) {
        final rows = await _db.outboxBatch();
        if (rows.isEmpty) break;
        final records = [for (final r in rows) MeditationRecord.fromJson(asJson(jsonDecode(r.payload)))];
        List<MeditationResult> results;
        try {
          results = records.length == 1 ? [await _repo.record(records.first)] : await _repo.batch(records);
        } on ApiException catch (e) {
          // offline / server down: keep everything and try again later
          for (final r in rows) {
            await _db.outboxFailed(r.id, e.code.wire);
          }
          if (e.code == ErrorCode.validationFailed || e.code == ErrorCode.invalidState) {
            // a rejected payload would block the queue forever: drop it after 5 attempts
            await _db.outboxDone(rows.where((r) => r.attempts >= 4).map((r) => r.id));
          }
          for (final w in _waiters.values) {
            if (!w.isCompleted) w.complete(null);
          }
          _waiters.clear();
          break;
        }
        final ok = <String>[];
        for (final (i, res) in results.indexed) {
          final id = records[i].id;
          if (res.status != 'rejected') byId[id] = res;
          ok.add(id); // created, duplicate or rejected by the server: none of them can succeed by retrying
          final w = _waiters.remove(id);
          if (w != null && !w.isCompleted) w.complete(res);
        }
        await _db.outboxDone(ok);
      }
      await _actions();
    } finally {
      try {
        pending.value = await _db.outboxCount();
      } catch (_) {/* database closed (app shutting down) */}
    }
  }

  /// Queued holds / reports, oldest first. A network failure stops the pass (order is kept); anything the server
  /// refuses for good (post removed, already reported) is dropped.
  Future<void> _actions() async {
    final repo = _community;
    if (repo == null) return;
    for (final p in await _db.pending()) {
      try {
        final j = asJson(jsonDecode(p.payload));
        switch (p.type) {
          case 'hold':
            await repo.hold(j['id'] as String, j['on'] == true);
          case 'report':
            await repo.report(j['id'] as String, reason: j['reason'] as String, block: j['block'] == true);
        }
      } on ApiException catch (e) {
        if (e.code == ErrorCode.network || e.code == ErrorCode.timeout || e.code == ErrorCode.internal) return;
      } on FormatException {
        // unreadable row: drop it
      }
      await _db.removePending(p.id);
    }
  }

  static String newId() => uuid7();
}
