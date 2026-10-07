import 'package:dio/dio.dart';
import '../../network/api_client.dart';
import '../models/json.dart';

/// Shared request helpers: unwrap `{data}`, map errors to [ApiException] (never leak dio to controllers).
abstract class ApiBase {
  ApiBase(this.api);
  final ApiClient api;

  Future<Json> getJson(String path, {Map<String, dynamic>? query, bool etag = false, CancelToken? cancel}) => _run(() async {
        final r = await api.dio.get(path, queryParameters: query, cancelToken: cancel, options: Options(extra: {if (etag) 'etag': true}));
        return asJson((r.data as Map)['data']);
      });

  Future<(List<Json>, String?)> getPage(String path, {Map<String, dynamic>? query}) => _run(() async {
        final r = await api.dio.get(path, queryParameters: query);
        final b = r.data as Map;
        return (asJsonList(b['data']), asStr(asJson(b['meta'])['nextCursor']));
      });

  Future<Json> call(String method, String path, {Object? body, Map<String, dynamic>? query}) => _run(() async {
        final r = await api.dio.request(path, data: body, queryParameters: query, options: Options(method: method));
        final d = r.data;
        return d is Map ? asJson(d['data']) : <String, dynamic>{};
      });

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiClient.map(e);
    }
  }
}
