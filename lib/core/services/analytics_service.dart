import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/json.dart';
import '../errors/error_code.dart';

/// Product analytics (spec §11.2): events are queued in memory and drift and flushed in batches to
/// `POST /v1/analytics/events` — every 30 s, at 20 events, or when the app goes to the background; max 50 per batch.
/// Timestamps use the server-synced clock. Never blocks the UI, never throws.
class AnalyticsService extends GetxService {
  AnalyticsService({AnalyticsRepository? repo, AppDatabase? db, DateTime Function()? now, this.flushEvery = const Duration(seconds: 30), this.flushAt = 20, this.maxBatch = 50, this.maxQueue = 500})
      : _repo = repo, _db = db, _now = now ?? (() => DateTime.now().toUtc());
  final AnalyticsRepository? _repo;
  final AppDatabase? _db;
  final DateTime Function() _now;
  final Duration flushEvery;
  final int flushAt, maxBatch, maxQueue;

  static const _key = 'analytics_queue';
  final _queue = <Json>[];
  Timer? _timer;
  Future<void>? _run;
  bool _again = false;

  int get pending => _queue.length;

  /// Source of the server clock (TimeService.now) once it is known.
  DateTime Function()? serverClock;

  Future<void> start() async {
    await _restore();
    if (_repo != null) _timer ??= Timer.periodic(flushEvery, (_) => flush()); // nothing to send to without a repository (tests)
  }

  void track(String name, [Map<String, Object?> params = const {}]) {
    _queue.add({'name': name, 'at': (serverClock?.call() ?? _now()).toUtc().toIso8601String(), 'props': _clean(params)});
    if (_queue.length > maxQueue) _queue.removeAt(0);
    _persistSoon();
    if (_queue.length >= flushAt) unawaited(flush());
  }

  /// Once per session: who is meditating, as properties (no email, no name).
  void userProps({required String plan, required bool isGuest, String? country, required String theme, required String flavor}) =>
      track('user_props', {'plan': plan, 'is_guest': isGuest, 'country': country, 'theme': theme, 'flavor': flavor});

  /// Only strings (≤ 200), numbers, booleans and nulls are accepted by the API; lists become comma lists.
  static Map<String, Object?> _clean(Map<String, Object?> p) => {
        for (final e in p.entries)
          e.key: switch (e.value) {
            null => null,
            num() || bool() => e.value,
            String s => s.length > 200 ? s.substring(0, 200) : s,
            Iterable i => i.join(',').substring(0, i.join(',').length.clamp(0, 200)),
            final o => '$o',
          }
      };

  List<Json> drain() {
    final out = List<Json>.of(_queue);
    _queue.clear();
    return out;
  }

  /// Sends everything queued, in batches. Network errors keep the events for the next try; rejected events are dropped.
  Future<void> flush() {
    final running = _run;
    if (running != null) {
      _again = true; // events arrived during a send: they get another pass
      return running;
    }
    return _run = _drain().whenComplete(() => _run = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      await _pass();
    } while (_again && _queue.isNotEmpty);
  }

  Future<void> _pass() async {
    final repo = _repo;
    if (repo == null || _queue.isEmpty) return;
    try {
      while (_queue.isNotEmpty) {
        final batch = _queue.take(maxBatch).toList();
        try {
          await repo.send(batch);
        } on ApiException catch (e) {
          if (e.code == ErrorCode.validationFailed) {
            _queue.removeRange(0, batch.length); // the server will never accept these
            continue;
          }
          break; // offline / server down / rate limited: try again later
        } catch (_) {
          break;
        }
        _queue.removeRange(0, batch.length);
      }
    } finally {
      await _persist();
    }
  }

  Timer? _persistTimer;
  void _persistSoon() {
    if (_db == null) return;
    _persistTimer ??= Timer(const Duration(seconds: 2), () {
      _persistTimer = null;
      _persist();
    });
  }

  Future<void> _persist() async {
    try {
      await _db?.putCache(_key, jsonEncode(_queue));
    } catch (_) {}
  }

  Future<void> _restore() async {
    try {
      final raw = await _db?.getCache(_key);
      if (raw != null) _queue.insertAll(0, [for (final j in (jsonDecode(raw) as List)) asJson(j)]);
    } catch (_) {}
  }

  /// App went to the background: send now (the OS may stop us soon).
  Future<void> onBackground() => flush();

  @override
  void onClose() {
    _timer?.cancel();
    _persistTimer?.cancel();
    super.onClose();
  }
}
