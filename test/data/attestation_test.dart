import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/api/auth_api.dart';
import 'package:meditation/core/data/contracts/auth_repository.dart';
import 'package:meditation/core/network/api_client.dart';
import 'package:meditation/core/network/session_store.dart';
import 'package:meditation/core/services/attestation.dart';

import '../core/fake_adapter.dart';

class FakeAttestation implements AttestationProvider {
  FakeAttestation(this.proof);
  final Map<String, dynamic>? Function(String challenge) proof;
  final challenges = <String>[];
  @override
  Future<Map<String, dynamic>?> prove(String challenge) async {
    challenges.add(challenge);
    return proof(challenge);
  }
}

const device = DeviceInfoDto(installId: 'i-1', platform: 'ios', appVersion: '1.0.0', timezone: 'Europe/Berlin');

Future<Map<String, dynamic>?> guestBody(AttestationProvider provider, {bool challengeFails = false}) async {
  Map<String, dynamic>? sent;
  final a = FakeAdapter((o, n) async {
    if (o.path == '/v1/auth/attest/challenge') return challengeFails ? apiError('INTERNAL', 500) : json({'data': {'challenge': 'c' * 43, 'expiresIn': 300}});
    sent = (o.data as Map).cast<String, dynamic>();
    return apiError('STOP', 400); // the session body isn't the subject here
  });
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
  final store = SessionStore(MemoryKv());
  final api = ApiClient(store, dio: dio, headers: () async => {}, retryDelay: const Duration(milliseconds: 1));
  try {
    await AuthApi(api, store, provider).guest(device);
  } catch (_) {}
  return sent;
}

void main() {
  test('guest create asks for a challenge and sends the device proof with it', () async {
    final p = FakeAttestation((c) => {'challenge': c, 'keyId': 'k' * 20, 'object': 'o' * 20});
    final body = await guestBody(p);
    expect(p.challenges, ['c' * 43]);
    expect((body!['attestation'] as Map)['keyId'], 'k' * 20);
    expect(body['installId'], 'i-1');
  });

  test('a device that cannot attest still creates the guest (no attestation field)', () async {
    final body = await guestBody(FakeAttestation((_) => null));
    expect(body, isNotNull);
    expect(body!.containsKey('attestation'), false);
  });

  test('a failing challenge request never blocks sign-in', () async {
    final p = FakeAttestation((c) => {'challenge': c, 'token': 't' * 20});
    final body = await guestBody(p, challengeFails: true);
    expect(body, isNotNull);
    expect(body!.containsKey('attestation'), false);
    expect(p.challenges, isEmpty);
  });
}
