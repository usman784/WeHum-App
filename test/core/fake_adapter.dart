import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:meditation/core/network/session_store.dart';

class MemoryKv implements SecureKv {
  final map = <String, String>{};
  @override
  Future<String?> read(String key) async => map[key];
  @override
  Future<void> write(String key, String value) async => map[key] = value;
  @override
  Future<void> delete(String key) async => map.remove(key);
}

typedef Handler = Future<ResponseBody> Function(RequestOptions o, int n);

/// Scripted HTTP adapter: the handler decides per request; `log` records every call.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);
  final Handler handler;
  final log = <String>[];
  var _n = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) {
    log.add('${options.method} ${options.path}');
    return handler(options, _n++);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body, {int status = 200, Map<String, List<String>> headers = const {}}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    });

ResponseBody apiError(String code, int status) => json({'error': {'code': code, 'message': code}}, status: status);
