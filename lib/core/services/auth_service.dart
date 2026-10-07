import 'dart:io' show Platform;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/contracts/auth_repository.dart';
import '../data/models/session.dart';
import '../network/session_store.dart';
import 'crash_service.dart';

/// Guest-first session (spec §6.2). `ensureSession()` on launch; the refresh interceptor keeps it alive.
class AuthService extends GetxService {
  AuthService(this._repo, this._store, this._crash, {Future<DeviceInfoDto> Function(String installId)? device}) : _device = device ?? _platformDevice;
  final Future<DeviceInfoDto> Function(String installId) _device;
  final AuthRepository _repo;
  final SessionStore _store;
  final CrashService _crash;

  final me = Rxn<Me>();
  bool get isGuest => me.value?.isGuest ?? true;

  Future<Me> ensureSession() async {
    if (me.value != null && _store.accessToken != null) return me.value!;
    final s = await _repo.guest(await _device(await _store.installId()));
    _set(s);
    return s.me;
  }

  static Future<DeviceInfoDto> _platformDevice(String installId) async {
    final info = await PackageInfo.fromPlatform();
    return DeviceInfoDto(
      installId: installId,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: info.version,
      timezone: (await FlutterTimezone.getLocalTimezone()).identifier,
    );
  }

  /// Google / Apple through Firebase. The Firebase id token is verified by our API.
  Future<Me> signInWithFirebase(String provider, String idToken, {String? firstName}) async {
    final s = await _repo.social(provider, idToken, firstName: firstName);
    _set(s);
    return s.me;
  }

  /// Local sign-out: server revokes the device and leaves the push topic, then a fresh guest is created.
  Future<void> signOut() async {
    await _repo.logout();
    me.value = null;
    await _crash.setUser(null);
    await ensureSession();
  }

  void _set(AuthSession s) {
    me.value = s.me;
    _crash.setUser(s.me.id);
  }
}
