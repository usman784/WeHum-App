import '../contracts/auth_repository.dart';
import '../contracts/bootstrap_repository.dart';
import '../models/bootstrap.dart';
import '../models/session.dart';

/// Mocks return the payloads from backend spec §5.4 (spec §0 rule 6). Used with USE_MOCKS=true and in widget tests.
class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> guest(DeviceInfoDto d) async => const AuthSession(
        accessToken: 'mock-access', refreshToken: 'mock-refresh-token-0000000000', me: Me(id: 'mock-user', isGuest: true));

  @override
  Future<AuthSession> social(String provider, String firebaseIdToken, {String? firstName}) async => AuthSession(
        accessToken: 'mock-access', refreshToken: 'mock-refresh-token-0000000000', me: Me(id: 'mock-user', isGuest: false, firstName: firstName));

  @override
  Future<void> logout() async {}
}

class MockBootstrapRepository implements BootstrapRepository {
  @override
  Future<Bootstrap> bootstrap() async => Bootstrap.fromJson({
        'serverTime': DateTime.now().toUtc().millisecondsSinceEpoch,
        'updateRequired': false,
        'maintenance': false,
        'features': {'intent': false, 'challenges': false, 'gratitude': false, 'breathwork': false, 'milestones': false},
        'catalogVersion': 1,
        'me': {'id': 'mock-user', 'isGuest': true, 'theme': 'system'},
      });
}
