/// Flavor config. Pass with --dart-define-from-file=env/{flavor}.json
abstract final class Env {
  static const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');
  static const socketUrl = String.fromEnvironment('SOCKET_URL', defaultValue: 'http://10.0.2.2:3000');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const rcAppleKey = String.fromEnvironment('RC_APPLE_KEY');
  static const rcGoogleKey = String.fromEnvironment('RC_GOOGLE_KEY');
  static const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);
}
