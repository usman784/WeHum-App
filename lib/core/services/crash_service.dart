import 'package:get/get.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../config/env.dart';
import '../errors/error_code.dart';
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
  Future<void> breadcrumb(String message, {String category = 'app'}) async {
    if (enabled) Sentry.addBreadcrumb(Breadcrumb(message: redact(message), category: category));
  }

  /// Every caught API error carries the backend `traceId` so app and backend events line up; only unexpected codes
  /// become non-fatal events (network, validation, auth expiry and gates are normal life).
  Future<void> captureApiError(ApiException e) async {
    if (!enabled) return;
    const quiet = {ErrorCode.network, ErrorCode.timeout, ErrorCode.validationFailed, ErrorCode.tokenExpired, ErrorCode.authRequired, ErrorCode.premiumRequired, ErrorCode.accountRequired, ErrorCode.rateLimited, ErrorCode.notFound, ErrorCode.invalidCredentials, ErrorCode.featureOff, ErrorCode.updateRequired, ErrorCode.maintenance};
    await Sentry.configureScope((s) {
      if (e.traceId != null) s.setTag('traceId', e.traceId!);
      s.setTag('error_code', e.code.wire);
    });
    if (!quiet.contains(e.code)) await Sentry.captureException(e);
  }

  Future<void> capture(Object error, [StackTrace? st]) async {
    if (enabled) await Sentry.captureException(error, stackTrace: st);
  }
}
