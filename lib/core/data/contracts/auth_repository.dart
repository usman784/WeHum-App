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

  /// Log in with a Firebase id token (Google/Apple). [provider] is `google` or `apple`. With a guest session the result may
  /// carry a `mergeToken` (the account already existed).
  Future<AuthSession> social(String provider, String firebaseIdToken, {String? firstName});

  /// Attach Google/Apple to the current guest (keeps id, purchases and history). Throws `ACCOUNT_EXISTS` with details.mergeToken.
  Future<AuthSession> linkSocial(String provider, String firebaseIdToken, {String? firstName});

  /// Create an email account on the current guest. Throws `ACCOUNT_EXISTS` when the email is taken.
  Future<AuthSession> linkEmail({required String email, required String password, String? firstName});
  Future<AuthSession> emailLogin({required String email, required String password});
  Future<void> forgotPassword(String email);
  Future<void> resetPassword({required String token, required String password});
  Future<void> sendMagicLink(String email);
  Future<AuthSession> verifyMagicLink(String token);
  Future<void> verifyEmail(String token);

  /// Moves the guest's data into the signed-in account (spec §5.2).
  Future<void> merge(String mergeToken);

  Future<void> logout();
}
