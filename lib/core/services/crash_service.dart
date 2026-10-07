import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/env.dart';
import '../utils/redact.dart';

/// Sentry wrapper (spec §11). A no-op when no DSN is configured, so local runs and tests stay quiet.
class CrashService extends GetxService {
  bool get enabled => Env.sentryDsn.isNotEmpty;

  /// Used as `SentryFlutter.init` options callback.
  static void configure(SentryFlutterOptions o) {
    o.dsn = Env.sentryDsn;
    o.environment = Env.flavor;
    o.tracesSampleRate = Env.flavor == 'prod' ? 0.1 : 1.0;
    o.attachScreenshot = false;
    o.sendDefaultPii = false;
    o.beforeSend = scrub;
  }

  /// Removes tokens and emails from messages and breadcrumbs.
  static SentryEvent? scrub(SentryEvent e, Hint hint) {
    final msg = e.message;
    if (msg != null) e.message = SentryMessage(redact(msg.formatted));
    for (final b in e.breadcrumbs ?? const <Breadcrumb>[]) {
      if (b.message != null) b.message = redact(b.message!);
      b.data = null;
    }
    e.request = null;
    return e;
  }

  Future<void> setUser(String? id) async => Sentry.configureScope((s) => s.setUser(id == null ? null : SentryUser(id: id)));
  Future<void> tag(String key, String value) async => Sentry.configureScope((s) => s.setTag(key, value));
  Future<void> capture(Object error, [StackTrace? st]) async {
    if (enabled) await Sentry.captureException(error, stackTrace: st);
  }
}
