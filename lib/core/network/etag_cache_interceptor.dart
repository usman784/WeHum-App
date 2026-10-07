import 'package:dio/dio.dart';

/// `If-None-Match` for requests that opt in with `Options(extra: {'etag': true})` (bootstrap, today, catalog, sos).
/// A 304 is turned back into the cached body, so callers never see it. Memory only; drift keeps the durable copy.
class EtagCacheInterceptor extends Interceptor {
  final _cache = <String, ({String etag, Object? data})>{};

  String _key(RequestOptions o) => '${o.method} ${o.uri}';
  void clear() => _cache.clear();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final o = options, h = handler;
    if (o.extra['etag'] == true) {
      final hit = _cache[_key(o)];
      if (hit != null) o.headers['If-None-Match'] = hit.etag;
      final original = o.validateStatus;
      o.validateStatus = (s) => s == 304 || original(s);
    }
    h.next(o);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final r = response, h = handler;
    final o = r.requestOptions;
    if (o.extra['etag'] != true) return h.next(r);
    final k = _key(o);
    if (r.statusCode == 304) {
      final hit = _cache[k];
      if (hit != null) {
        return h.resolve(Response(requestOptions: o, data: hit.data, statusCode: 200, extra: {'fromCache': true}));
      }
    }
    final tag = r.headers.value('etag');
    if (tag != null && r.statusCode == 200) _cache[k] = (etag: tag, data: r.data);
    h.next(r);
  }
}
