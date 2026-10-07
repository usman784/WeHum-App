import 'package:dio/dio.dart' show Options;
import '../../network/api_client.dart';
import '../../network/session_store.dart';
import '../contracts/auth_repository.dart';
import '../models/session.dart';

class AuthApi implements AuthRepository {
  AuthApi(this._api, this._session);
  final ApiClient _api;
  final SessionStore _session;

  Future<AuthSession> _save(Map<String, dynamic> body) async {
    final s = AuthSession.fromJson((body['data'] as Map).cast<String, dynamic>());
    await _session.save(access: s.accessToken, refresh: s.refreshToken);
    return s;
  }

  @override
  Future<AuthSession> guest(DeviceInfoDto d) async {
    try {
      final r = await _api.dio.post('/v1/auth/guest', data: {
        'installId': d.installId, 'platform': d.platform, 'appVersion': d.appVersion, 'timezone': d.timezone, 'locale': d.locale,
        if (d.osVersion != null) 'osVersion': d.osVersion, if (d.model != null) 'model': d.model,
      }, options: Options(extra: {'noAuth': true}));
      return _save((r.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiClient.map(e);
    }
  }

  @override
  Future<AuthSession> social(String provider, String firebaseIdToken, {String? firstName}) async {
    try {
      final r = await _api.dio.post('/v1/auth/$provider', data: {'idToken': firebaseIdToken, if (firstName != null) 'firstName': firstName});
      return _save((r.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiClient.map(e);
    }
  }

  Future<Map<String, dynamic>> _post(String path, Object? body, {bool noAuth = false}) async {
    try {
      final r = await _api.dio.post(path, data: body, options: Options(extra: {if (noAuth) 'noAuth': true}));
      final d = r.data;
      return d is Map ? ((d['data'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{}) : <String, dynamic>{};
    } catch (e) {
      throw ApiClient.map(e);
    }
  }

  Map<String, dynamic> _social(String idToken, String? firstName) => {'idToken': idToken, if (firstName != null && firstName.isNotEmpty) 'firstName': firstName};

  @override
  Future<AuthSession> linkSocial(String provider, String firebaseIdToken, {String? firstName}) async =>
      _saveJson(await _post('/v1/auth/link/$provider', _social(firebaseIdToken, firstName)));

  @override
  Future<AuthSession> linkEmail({required String email, required String password, String? firstName}) async =>
      _saveJson(await _post('/v1/auth/link/email', {'email': email, 'password': password, if (firstName != null && firstName.isNotEmpty) 'firstName': firstName}));

  @override
  Future<AuthSession> emailLogin({required String email, required String password}) async => _saveJson(await _post('/v1/auth/email/login', {'email': email, 'password': password}));

  @override
  Future<void> forgotPassword(String email) async {
    await _post('/v1/auth/password/forgot', {'email': email}, noAuth: true);
  }

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    await _post('/v1/auth/password/reset', {'token': token, 'password': password}, noAuth: true);
  }

  @override
  Future<void> sendMagicLink(String email) async {
    await _post('/v1/auth/email/magic-link', {'email': email}, noAuth: true);
  }

  @override
  Future<AuthSession> verifyMagicLink(String token) async => _saveJson(await _post('/v1/auth/email/verify-link', {'token': token}));

  @override
  Future<void> verifyEmail(String token) async {
    await _post('/v1/auth/email/verify', {'token': token}, noAuth: true);
  }

  @override
  Future<void> merge(String mergeToken) async {
    await _post('/v1/auth/merge', {'mergeToken': mergeToken});
  }

  Future<AuthSession> _saveJson(Map<String, dynamic> j) async {
    final s = AuthSession.fromJson(j);
    await _session.save(access: s.accessToken, refresh: s.refreshToken);
    return s;
  }

  @override
  Future<void> logout() async {
    try {
      final rt = await _session.refreshToken();
      await _api.dio.post('/v1/auth/logout', data: {if (rt != null) 'refreshToken': rt});
    } catch (_) {
      // best effort: the session is cleared locally either way
    } finally {
      await _session.clear();
    }
  }
}
