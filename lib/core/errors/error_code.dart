/// Mirrors backend spec §5.3. Unknown codes map to [ErrorCode.internal].
enum ErrorCode {
  validationFailed('VALIDATION_FAILED'), authRequired('AUTH_REQUIRED'), tokenExpired('TOKEN_EXPIRED'),
  tokenInvalid('TOKEN_INVALID'), tokenReused('TOKEN_REUSED'), forbidden('FORBIDDEN'), premiumRequired('PREMIUM_REQUIRED'),
  accountRequired('ACCOUNT_REQUIRED'), meditationRequired('MEDITATION_REQUIRED'), muted('MUTED'), notFound('NOT_FOUND'),
  accountExists('ACCOUNT_EXISTS'), conflictVersion('CONFLICT_VERSION'), dedicationLinks('DEDICATION_LINKS'),
  dedicationLimit('DEDICATION_LIMIT'), invalidState('INVALID_STATE'), updateRequired('UPDATE_REQUIRED'),
  rateLimited('RATE_LIMITED'), invalidCredentials('INVALID_CREDENTIALS'), gone('GONE'), roomLimit('ROOM_LIMIT'), featureOff('FEATURE_OFF'), maintenance('MAINTENANCE'), dependencyDown('DEPENDENCY_DOWN'),
  network('NETWORK'), timeout('TIMEOUT'), internal('INTERNAL');

  const ErrorCode(this.wire);
  final String wire;
  static ErrorCode parse(String? w) => values.firstWhere((e) => e.wire == w, orElse: () => internal);
}

class ApiException implements Exception {
  ApiException(this.code, {this.status, this.message, this.details, this.traceId});
  final ErrorCode code;
  final int? status;
  final String? message;
  final Object? details;
  final String? traceId;
  @override
  String toString() => 'ApiException(${code.wire}, $status, trace=$traceId)';
}
