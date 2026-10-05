import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import '../config/env.dart';
import '../errors/error_code.dart';

/// Holds tokens. Access token in memory, refresh token + install id in secure storage (spec §6.2).
class SessionStore {
  SessionStore(this._secure);
  final FlutterSecureStorage _secure;
  String? accessToken;

  Future<String> installId() async {
    var id = await _secure.read(key: 'install_id');
    if (id == null) { id = const Uuid().v4(); await _secure.write(key: 'install_id', value: id); }
    return id;
  }
  Future<String?> refreshToken() => _secure.read(key: 'refresh_token');
  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    await _secure.write(key: 'refresh_token', value: refresh);
  }
  Future<void> clear() async { accessToken = null; await _secure.delete(key: 'refresh_token'); }
}

/// Single dio instance with auth, single-flight refresh, retry and error mapping.
class ApiClient {
  ApiClient(this.session, {this.onSignedOut, this.onUpdateRequired, this.onMaintenance}) {
    dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
    ));
    dio.interceptors.addAll([
      InterceptorsWrapper(onRequest: _attachHeaders, onError: _onError),
      _RetryInterceptor(dio),
    ]);
  }

  final SessionStore session;
  final void Function()? onSignedOut;
  final void Function()? onUpdateRequired;
  final void Function()? onMaintenance;
  late final Dio dio;
  Completer<bool>? _refreshing;
  Map<String, String>? _static;

  Future<Map<String, String>> _staticHeaders() async {
    if (_static != null) return _static!;
    final info = await PackageInfo.fromPlatform();
    _static = {
      'X-App-Version': info.version,
      'X-Platform': Platform.isIOS ? 'ios' : 'android',
      'X-Install-Id': await session.installId(),
    };
    return _static!;
  }

  Future<void> _attachHeaders(RequestOptions o, RequestInterceptorHandler h) async {
    o.headers.addAll(await _staticHeaders());
    o.headers['X-Timezone'] = await FlutterTimezone.getLocalTimezone();
    final t = session.accessToken;
    if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
    h.next(o);
  }

  Future<void> _onError(DioException e, ErrorInterceptorHandler h) async {
    final code = ErrorCode.parse((e.response?.data is Map) ? e.response!.data['error']?['code'] as String? : null);
    if (code == ErrorCode.tokenExpired && e.requestOptions.extra['retried'] != true) {
      if (await _refreshOnce()) {
        final o = e.requestOptions..extra['retried'] = true;
        o.headers['Authorization'] = 'Bearer ${session.accessToken}';
        try { return h.resolve(await dio.fetch(o)); } catch (err) { return h.next(err as DioException); }
      }
    }
    if (code == ErrorCode.updateRequired) onUpdateRequired?.call();
    if (code == ErrorCode.maintenance) onMaintenance?.call();
    h.next(e);
  }

  /// Concurrent 401s share one refresh call.
  Future<bool> _refreshOnce() {
    if (_refreshing != null) return _refreshing!.future;
    final c = _refreshing = Completer<bool>();
    () async {
      try {
        final rt = await session.refreshToken();
        if (rt == null) throw StateError('no refresh token');
        final r = await dio.post('/v1/auth/refresh', data: {'refreshToken': rt}, options: Options(extra: {'noAuth': true}));
        await session.save(access: r.data['data']['accessToken'], refresh: r.data['data']['refreshToken']);
        c.complete(true);
      } catch (_) {
        await session.clear();
        onSignedOut?.call(); // TOKEN_REUSED / invalid → new guest session
        c.complete(false);
      } finally {
        _refreshing = null;
      }
    }();
    return c.future;
  }

  /// Maps any error to [ApiException] (use in repositories).
  static ApiException map(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) return ApiException(ErrorCode.timeout);
      if (e.type == DioExceptionType.connectionError) return ApiException(ErrorCode.network);
      final err = (e.response?.data is Map) ? e.response!.data['error'] as Map? : null;
      return ApiException(ErrorCode.parse(err?['code'] as String?), status: e.response?.statusCode,
          message: err?['message'] as String?, details: err?['details'], traceId: err?['traceId'] as String?);
    }
    return ApiException(ErrorCode.internal, message: e.toString());
  }
}

/// Retries idempotent GETs on network/5xx errors: 3 attempts, 300 ms × 2^n + jitter.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this.dio);
  final Dio dio;
  @override
  Future<void> onError(DioException e, ErrorInterceptorHandler h) async {
    final o = e.requestOptions;
    final n = (o.extra['attempt'] as int?) ?? 0;
    final retriable = o.method == 'GET' && n < 3 && (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout || (e.response?.statusCode ?? 0) >= 500);
    if (!retriable) return h.next(e);
    await Future.delayed(Duration(milliseconds: 300 * (1 << n) + DateTime.now().millisecond % 150));
    o.extra['attempt'] = n + 1;
    try { h.resolve(await dio.fetch(o)); } catch (err) { h.next(err as DioException); }
  }
}
