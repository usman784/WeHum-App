import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/network/api_client.dart';
import 'package:meditation/core/network/session_store.dart';

import 'fake_adapter.dart';

Future<ApiClient> client(FakeAdapter a, {SessionStore? store, void Function()? onSignedOut}) async {
  final s = store ?? SessionStore(MemoryKv());
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
  return ApiClient(s, dio: dio, headers: () async => {'X-App-Version': '1.0.0'}, onSignedOut: onSignedOut, retryDelay: const Duration(milliseconds: 1));
}

void main() {
  group('auth + refresh', () {
    test('attaches the access token and static headers', () async {
      final seen = <RequestOptions>[];
      final a = FakeAdapter((o, n) async {
        seen.add(o);
        return json({'data': 1});
      });
      final store = SessionStore(MemoryKv())..accessToken = 'abc';
      final c = await client(a, store: store);
      await c.dio.get('/v1/me');
      expect(seen.single.headers['Authorization'], 'Bearer abc');
      expect(seen.single.headers['X-App-Version'], '1.0.0');
    });

    test('five parallel TOKEN_EXPIRED responses share ONE refresh, then each retries once', () async {
      final kv = MemoryKv()..map['refresh_token'] = 'old-refresh';
      final store = SessionStore(kv)..accessToken = 'expired';
      final a = FakeAdapter((o, n) async {
        if (o.path == '/v1/auth/refresh') {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return json({'data': {'accessToken': 'fresh', 'refreshToken': 'new-refresh'}});
        }
        return o.headers['Authorization'] == 'Bearer fresh' ? json({'data': 'ok'}) : apiError('TOKEN_EXPIRED', 401);
      });
      final c = await client(a, store: store);
      final rs = await Future.wait(List.generate(5, (i) => c.dio.get('/v1/thing/$i')));
      expect(rs.map((r) => r.data['data']), everyElement('ok'));
      expect(c.refreshCalls, 1);
      expect(a.log.where((l) => l == 'POST /v1/auth/refresh').length, 1);
      expect(kv.map['refresh_token'], 'new-refresh');
      expect(store.accessToken, 'fresh');
    });

    test('a failed refresh signs out cleanly (TOKEN_REUSED) and surfaces the error', () async {
      final kv = MemoryKv()..map['refresh_token'] = 'reused';
      final store = SessionStore(kv)..accessToken = 'expired';
      var signedOut = 0;
      final a = FakeAdapter((o, n) async => o.path == '/v1/auth/refresh' ? apiError('TOKEN_REUSED', 401) : apiError('TOKEN_EXPIRED', 401));
      final c = await client(a, store: store, onSignedOut: () => signedOut++);
      await expectLater(c.dio.get('/v1/x'), throwsA(isA<DioException>()));
      expect(signedOut, 1);
      expect(kv.map.containsKey('refresh_token'), false);
      expect(store.accessToken, isNull);
    });

    test('offline during refresh keeps the session (no sign-out); the next call tries again', () async {
      final kv = MemoryKv()..map['refresh_token'] = 'r';
      final store = SessionStore(kv)..accessToken = 'expired';
      var signedOut = 0;
      final a = FakeAdapter((o, n) async {
        if (o.path == '/v1/auth/refresh') throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
        return apiError('TOKEN_EXPIRED', 401);
      });
      final c = await client(a, store: store, onSignedOut: () => signedOut++);
      await expectLater(c.dio.get('/v1/x'), throwsA(isA<DioException>()));
      expect(signedOut, 0);
      expect(kv.map['refresh_token'], 'r');
      expect(await c.refreshAccessToken(), false);
      expect(c.refreshCalls, 2);
    });

    test('a request is retried only once after refresh (no loop)', () async {
      final store = SessionStore(MemoryKv()..map['refresh_token'] = 'r')..accessToken = 'x';
      final a = FakeAdapter((o, n) async => o.path == '/v1/auth/refresh'
          ? json({'data': {'accessToken': 'fresh', 'refreshToken': 'r2'}})
          : apiError('TOKEN_EXPIRED', 401));
      final c = await client(a, store: store);
      await expectLater(c.dio.get('/v1/x'), throwsA(isA<DioException>()));
      expect(a.log.where((l) => l == 'GET /v1/x').length, 2);
    });

    test('UPDATE_REQUIRED and MAINTENANCE call their gates', () async {
      var update = 0, maint = 0;
      var code = 'UPDATE_REQUIRED';
      final a = FakeAdapter((o, n) async => apiError(code, code == 'UPDATE_REQUIRED' ? 426 : 503));
      final s = SessionStore(MemoryKv());
      final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
      final c = ApiClient(s, dio: dio, headers: () async => {}, onUpdateRequired: () => update++, onMaintenance: () => maint++);
      await expectLater(c.dio.post('/v1/x'), throwsA(isA<DioException>()));
      code = 'MAINTENANCE';
      await expectLater(c.dio.post('/v1/x'), throwsA(isA<DioException>()));
      expect([update, maint], [1, 1]);
    });
  });

  group('retry', () {
    test('GET retries on 5xx up to 3 times then succeeds', () async {
      final a = FakeAdapter((o, n) async => n < 2 ? json({'error': {'code': 'INTERNAL'}}, status: 503) : json({'data': 'ok'}));
      final c = await client(a);
      final r = await c.dio.get('/v1/today');
      expect(r.data['data'], 'ok');
      expect(a.log.length, 3);
    });

    test('GET gives up after 3 retries', () async {
      final a = FakeAdapter((o, n) async => json({'error': {'code': 'INTERNAL'}}, status: 500));
      final c = await client(a);
      await expectLater(c.dio.get('/v1/today'), throwsA(isA<DioException>()));
      expect(a.log.length, 4); // 1 + 3 retries
    });

    test('POST is never retried', () async {
      final a = FakeAdapter((o, n) async => json({'error': {'code': 'INTERNAL'}}, status: 500));
      final c = await client(a);
      await expectLater(c.dio.post('/v1/meditations'), throwsA(isA<DioException>()));
      expect(a.log.length, 1);
    });
  });

  group('ETag', () {
    test('sends If-None-Match and serves the cached body on 304', () async {
      final a = FakeAdapter((o, n) async => n == 0
          ? json({'data': {'v': 1}}, headers: {'etag': ['"abc"']})
          : (o.headers['If-None-Match'] == '"abc"' ? ResponseBody.fromString('', 304) : json({'data': 'wrong'})));
      final c = await client(a);
      final opt = Options(extra: {'etag': true});
      final first = await c.dio.get('/v1/bootstrap', options: opt);
      final second = await c.dio.get('/v1/bootstrap', options: opt);
      expect(first.data['data']['v'], 1);
      expect(second.data['data']['v'], 1);
      expect(second.extra['fromCache'], true);
      expect(second.statusCode, 200);
    });

    test('requests that do not opt in are untouched', () async {
      final seen = <RequestOptions>[];
      final a = FakeAdapter((o, n) async {
        seen.add(o);
        return json({'data': 1}, headers: {'etag': ['"z"']});
      });
      final c = await client(a);
      await c.dio.get('/v1/other');
      await c.dio.get('/v1/other');
      expect(seen.last.headers.containsKey('If-None-Match'), false);
    });
  });

  group('error mapping', () {
    test('maps API errors, timeouts and unknown codes', () {
      final e = DioException(requestOptions: RequestOptions(), response: Response(requestOptions: RequestOptions(), statusCode: 403, data: {'error': {'code': 'PREMIUM_REQUIRED', 'message': 'm', 'traceId': 't1'}}));
      final m = ApiClient.map(e);
      expect(m.code, ErrorCode.premiumRequired);
      expect(m.status, 403);
      expect(m.traceId, 't1');
      expect(ApiClient.map(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionTimeout)).code, ErrorCode.timeout);
      expect(ApiClient.map(DioException(requestOptions: RequestOptions(), type: DioExceptionType.connectionError)).code, ErrorCode.network);
      expect(ErrorCode.parse('SOMETHING_NEW'), ErrorCode.internal);
    });
  });

  group('session store', () {
    test('install id is created once and survives sign-out', () async {
      final s = SessionStore(MemoryKv());
      final a = await s.installId();
      await s.save(access: 'a', refresh: 'r');
      await s.clear();
      expect(await s.installId(), a);
      expect(await s.refreshToken(), isNull);
    });
  });
}
