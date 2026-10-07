import 'package:dio/dio.dart';

/// Retries idempotent GETs on network/5xx errors: 3 attempts, 300 ms × 2^n + jitter (spec §2).
class RetryInterceptor extends Interceptor {
  RetryInterceptor(this.dio, {this.baseDelay = const Duration(milliseconds: 300)});
  final Dio dio;
  final Duration baseDelay;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final e = err, h = handler;
    final o = e.requestOptions;
    final n = (o.extra['attempt'] as int?) ?? 0;
    final retriable = o.method == 'GET' &&
        n < 3 &&
        (e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            (e.response?.statusCode ?? 0) >= 500);
    if (!retriable) return h.next(e);
    await Future.delayed(baseDelay * (1 << n) + Duration(milliseconds: DateTime.now().millisecond % 150));
    o.extra['attempt'] = n + 1;
    try {
      h.resolve(await dio.fetch(o));
    } catch (x) {
      h.next(x as DioException);
    }
  }
}
