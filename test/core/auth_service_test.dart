import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/contracts/auth_repository.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/session.dart';
import 'package:meditation/core/network/session_store.dart';
import 'package:meditation/core/services/auth_service.dart';
import 'package:meditation/core/services/crash_service.dart';

import 'fake_adapter.dart';

class CountingAuth extends MockAuthRepository {
  int guests = 0;
  @override
  Future<AuthSession> guest(DeviceInfoDto d) {
    guests++;
    return super.guest(d);
  }
}

Future<DeviceInfoDto> dev(String id) async => DeviceInfoDto(installId: id, platform: 'ios', appVersion: '1.0.0', timezone: 'UTC');

void main() {
  test('first launch: creates a guest and caches it', () async {
    final repo = CountingAuth();
    final kv = MemoryKv();
    final a = AuthService(repo, SessionStore(kv), CrashService(), device: dev, refreshToken: () async => true, cache: kv);
    await a.ensureSession();
    expect(repo.guests, 1);
    expect(kv.map['me_cache'], contains('mock-user'));
  });

  test('later launch with a stored session: no guest call, works offline from the cached profile', () async {
    final repo = CountingAuth();
    final kv = MemoryKv()
      ..map['refresh_token'] = 'stored-refresh-token-0000000000'
      ..map['me_cache'] = '{"id":"u1","isGuest":false,"firstName":"Lena"}';
    // refresh fails because the phone is offline, but the session is still on the phone
    final a = AuthService(repo, SessionStore(kv), CrashService(), device: dev, refreshToken: () async => false, cache: kv);
    final me = await a.ensureSession();
    expect(me.id, 'u1');
    expect(me.firstName, 'Lena');
    expect(repo.guests, 0);
  });

  test('refresh rejected (token cleared by the interceptor): falls back to a new guest', () async {
    final repo = CountingAuth();
    final kv = MemoryKv()..map['refresh_token'] = 'revoked-refresh-token-000000000';
    final store = SessionStore(kv);
    final a = AuthService(repo, store, CrashService(), device: dev, refreshToken: () async {
      await store.clear(); // what ApiClient does on TOKEN_REUSED / TOKEN_INVALID
      return false;
    }, cache: kv);
    await a.ensureSession();
    expect(repo.guests, 1);
  });

  test('resetToGuest keeps the install id, creates a fresh guest and remembers that an account was signed out', () async {
    final repo = CountingAuth();
    final kv = MemoryKv();
    final store = SessionStore(kv);
    final a = AuthService(repo, store, CrashService(), device: dev, cache: kv);
    await a.ensureSession();
    final install = await store.installId();
    await a.resetToGuest(keepAccountHint: true);
    expect(await store.installId(), install);
    expect(repo.guests, 2);
    expect(a.wasAccount.value, true);
  });
}
