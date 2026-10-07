import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Named timings (spec §11.3): `cold_start`, `today_first_content`, `player_ready` (tap → audio playing),
/// `download_duration`, `paywall_ready`, `socket_connect`. Sent to Sentry Performance when it is on; always kept
/// in memory so tests and debug builds can read them. Targets: cold start < 2.0 s, player ready < 1 s.
class PerfService extends GetxService {
  PerfService({this.sentryEnabled = false});
  final bool sentryEnabled;
  final _running = <String, (Stopwatch, ISentrySpan?)>{};
  final results = <String, Duration>{};

  void start(String name) {
    if (_running.containsKey(name)) return;
    ISentrySpan? tx;
    if (sentryEnabled) {
      try {
        tx = Sentry.startTransaction(name, 'perf');
      } catch (_) {}
    }
    _running[name] = (Stopwatch()..start(), tx);
  }

  /// Ends [name] and returns how long it took (null when it was never started).
  Duration? finish(String name) {
    final r = _running.remove(name);
    if (r == null) return null;
    final d = r.$1.elapsed;
    results[name] = d;
    r.$2?.finish();
    return d;
  }

  Future<T> measure<T>(String name, Future<T> Function() f) async {
    start(name);
    try {
      return await f();
    } finally {
      finish(name);
    }
  }
}

/// Starts when the process starts (set in `bootstrap()`); `cold_start` ends when the first screen shows.
final Stopwatch appStartWatch = Stopwatch()..start();

/// Fire-and-forget facade: does nothing when [PerfService] is not registered (tests, early startup).
abstract final class Perf {
  static PerfService? get _s => Get.isRegistered<PerfService>() ? Get.find<PerfService>() : null;
  static void start(String name) => _s?.start(name);
  static Duration? finish(String name) => _s?.finish(name);
}
