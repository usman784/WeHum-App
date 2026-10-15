import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/api/api_repositories.dart';
import 'package:meditation/core/network/api_client.dart';
import 'package:meditation/core/network/session_store.dart';

import 'fake_adapter.dart';

ApiClient _client(FakeAdapter a) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'))..httpClientAdapter = a;
  return ApiClient(SessionStore(MemoryKv()), dio: dio, headers: () async => {'X-App-Version': '1.0.0'}, retryDelay: const Duration(milliseconds: 1));
}

void main() {
  group('catalog refresh', () {
    test('a 304 with nothing cached means "nothing newer", not an error', () async {
      final a = FakeAdapter((o, n) async => ResponseBody.fromString('', 304));
      final repo = CatalogApi(_client(a));
      expect(await repo.catalog(knownVersion: 14), isNull);
      expect(a.log, ['GET /v1/catalog']);
    });

    test('a newer catalog is parsed and returned', () async {
      final a = FakeAdapter((o, n) async => json({
            'data': {'version': 15, 'themes': [], 'teachers': [], 'sessions': [], 'programs': []}
          }));
      final c = await CatalogApi(_client(a)).catalog(knownVersion: 14);
      expect(c?.version, 15);
    });

    test('the same version in a 200 answer is also "unchanged"', () async {
      final a = FakeAdapter((o, n) async => json({
            'data': {'version': 14, 'themes': [], 'teachers': [], 'sessions': [], 'programs': []}
          }));
      expect(await CatalogApi(_client(a)).catalog(knownVersion: 14), isNull);
    });
  });
}
