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
