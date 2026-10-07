import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/activity.dart';
import '../data/models/json.dart';
import '../errors/error_code.dart';
import '../utils/uuid7.dart';

/// Meditations are written to the local outbox first and sent in the background (spec §6.2, §10).
/// Items carry a uuid v7 id, so a retry after a lost response is harmless (server is idempotent).
class SyncService extends GetxService {
  SyncService(this._repo, this._db);
  final MeditationRepository _repo;
  final AppDatabase _db;

  final pending = 0.obs;
  Future<void>? _run;
  bool _again = false;
  final _results = <String, MeditationResult>{};
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

  MeditationResult? resultFor(String id) => _results[id];

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
          if (res.status != 'rejected') _results[id] = res;
          ok.add(id); // created, duplicate or rejected by the server: none of them can succeed by retrying
          final w = _waiters.remove(id);
          if (w != null && !w.isCompleted) w.complete(res);
        }
        await _db.outboxDone(ok);
      }
    } finally {
      try {
        pending.value = await _db.outboxCount();
      } catch (_) {/* database closed (app shutting down) */}
    }
  }

  static String newId() => uuid7();
}
