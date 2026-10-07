import '../models/session.dart';

class DeviceInfoDto {
  const DeviceInfoDto({required this.installId, required this.platform, required this.appVersion, required this.timezone, this.locale = 'en', this.osVersion, this.model});
  final String installId;
  final String platform;
  final String appVersion;
  final String timezone;
  final String locale;
  final String? osVersion;
  final String? model;
}

abstract class AuthRepository {
  /// Create or resume the guest for this install.
  Future<AuthSession> guest(DeviceInfoDto device);

  /// Sign in with a Firebase id token (Google/Apple). [provider] is `google` or `apple`.
  Future<AuthSession> social(String provider, String firebaseIdToken, {String? firstName});

  Future<void> logout();
}
