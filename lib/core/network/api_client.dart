import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../config/env.dart';
import '../errors/error_code.dart';
import 'etag_cache_interceptor.dart';
import 'retry_interceptor.dart';
import 'session_store.dart';

typedef HeaderProvider = Future<Map<String, String>> Function();

/// Single dio instance with auth, single-flight refresh, ETag, retry and error mapping (spec §6.2).
class ApiClient {
  ApiClient(
    this.session, {
    Dio? dio,
    HeaderProvider? headers,
    this.onSignedOut,
    this.onUpdateRequired,
    this.onMaintenance,
    this.onApiError,
    Duration retryDelay = const Duration(milliseconds: 300),
  }) : _headers = headers ?? _deviceHeaders(session) {
    this.dio = dio ??
        Dio(BaseOptions(
          baseUrl: Env.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          responseType: ResponseType.json,
        ));
    this.dio.interceptors.addAll([
      InterceptorsWrapper(onRequest: _attachHeaders, onError: _onError),
      etag,
      RetryInterceptor(this.dio, baseDelay: retryDelay),
    ]);
  }

  final SessionStore session;
  final HeaderProvider _headers;
  final void Function()? onSignedOut;
  final void Function()? onUpdateRequired;
  final void Function()? onMaintenance;
  /// Called for every failed response with its mapped error (Sentry tags + non-fatals).
  final void Function(ApiException e)? onApiError;
  late final Dio dio;
  final etag = EtagCacheInterceptor();
  Completer<bool>? _refreshing;
  int refreshCalls = 0; // for tests

  static HeaderProvider _deviceHeaders(SessionStore session) {
    Map<String, String>? cached;
    return () async {
      if (cached != null) return cached!;
      final info = await PackageInfo.fromPlatform();
      return cached = {
        'X-App-Version': info.version,
        'X-Platform': Platform.isIOS ? 'ios' : 'android',
        'X-Install-Id': await session.installId(),
        'X-Timezone': (await FlutterTimezone.getLocalTimezone()).identifier,
      };
    };
  }

  Future<void> _attachHeaders(RequestOptions o, RequestInterceptorHandler h) async {
    o.headers.addAll(await _headers());
    final t = session.accessToken;
    if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final code = ErrorCode.parse((e.response?.data is Map) ? (e.response!.data['error']?['code'] as String?) : null);
    if (code == ErrorCode.tokenExpired && e.requestOptions.extra['retried'] != true) {
      if (await _refreshOnce()) {
        final o = e.requestOptions..extra['retried'] = true;
        o.headers['Authorization'] = 'Bearer ${session.accessToken}';
        try {
          return h.resolve(await dio.fetch(o));
        } catch (err) {
          return h.next(err as DioException);
        }
      }
    }
    if (e.response != null) onApiError?.call(map(e));
    if (code == ErrorCode.updateRequired) onUpdateRequired?.call();
    if (code == ErrorCode.maintenance) onMaintenance?.call();
    h.next(e);
  }

  /// Refreshes the access token now (sockets use this). Concurrent callers share one call.
  Future<bool> refreshAccessToken() => _refreshOnce();

  /// Concurrent TOKEN_EXPIRED responses share one refresh call.
  Future<bool> _refreshOnce() {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    () async {
      try {
        refreshCalls++;
        final rt = await session.refreshToken();
        if (rt == null) throw StateError('no refresh token');
        final r = await dio.post('/v1/auth/refresh', data: {'refreshToken': rt}, options: Options(extra: {'noAuth': true}));
        await session.save(access: r.data['data']['accessToken'], refresh: r.data['data']['refreshToken']);
        c.complete(true);
      } catch (e) {
        // Only a real rejection signs the user out (TOKEN_REUSED / TOKEN_INVALID → new guest). Being offline or a server
        // error keeps the session: the next call tries again (spec §10).
        final rejected = e is StateError || (e is DioException && const [400, 401, 403].contains(e.response?.statusCode));
        if (rejected) {
          await session.clear();
          onSignedOut?.call();
        }
        c.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return c.future;
  }

  /// Maps any error to [ApiException] (use in repositories).
  static ApiException map(Object e) {
    if (e is ApiException) return e;
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) return ApiException(ErrorCode.timeout);
      if (e.type == DioExceptionType.connectionError) return ApiException(ErrorCode.network);
      final err = (e.response?.data is Map) ? e.response!.data['error'] as Map? : null;
      return ApiException(ErrorCode.parse(err?['code'] as String?),
          status: e.response?.statusCode, message: err?['message'] as String?, details: err?['details'], traceId: err?['traceId'] as String?);
    }
    return ApiException(ErrorCode.internal, message: e.toString());
  }
}
