import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/contracts/auth_repository.dart';
import '../data/models/activity.dart';
import '../data/models/session.dart';
import '../network/session_store.dart';
import 'crash_service.dart';

/// Guest-first session (spec §6.2). `ensureSession()` on launch; the refresh interceptor keeps it alive.
class AuthService extends GetxService {
  AuthService(this._repo, this._store, this._crash, {Future<DeviceInfoDto> Function(String installId)? device, this.refreshToken, SecureKv? cache})
      : _device = device ?? _platformDevice,
        _cache = cache;
  /// Refreshes the access token from the stored refresh token (ApiClient.refreshAccessToken).
  final Future<bool> Function()? refreshToken;
  final SecureKv? _cache;
  final Future<DeviceInfoDto> Function(String installId) _device;
  final AuthRepository _repo;
  final SessionStore _store;
  final CrashService _crash;

  final me = Rxn<Me>();
  bool get isGuest => me.value?.isGuest ?? true;

  /// Resumes the stored session without a guest call when there is one (works offline); otherwise creates the guest.
  Future<Me> ensureSession() async {
    if (me.value != null && _store.accessToken != null) return me.value!;
    if (refreshToken != null && await _store.refreshToken() != null) {
      final cached = await _readCachedMe();
      final ok = await refreshToken!();
      if (ok || (await _store.refreshToken()) != null) {
        // refreshed, or offline with a session still on the phone: carry on with what we know
        if (cached != null) {
          me.value = cached;
          return cached;
        }
        if (ok) {
          final m = const Me(id: '', isGuest: true);
          me.value = m;
          return m;
        }
      }
      // refresh was rejected (revoked / reused): a new guest below
    }
    final s = await _repo.guest(await _device(await _store.installId()));
    _set(s);
    return s.me;
  }

  Future<Me?> _readCachedMe() async {
    final raw = await _cache?.read('me_cache');
    if (raw == null) return null;
    try {
      return Me.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCachedMe(Me m) async => _cache?.write('me_cache', jsonEncode({'id': m.id, 'isGuest': m.isGuest, 'firstName': m.firstName, 'theme': m.theme}));

  static Future<DeviceInfoDto> _platformDevice(String installId) async {
    final info = await PackageInfo.fromPlatform();
    return DeviceInfoDto(
      installId: installId,
      platform: Platform.isIOS ? 'ios' : 'android',
      appVersion: info.version,
      timezone: (await FlutterTimezone.getLocalTimezone()).identifier,
    );
  }

  /// A new session after link / login / merge: tokens are already saved by the repository.
  Me applySession(AuthSession s) {
    _set(s);
    wasAccount.value = false;
    return s.me;
  }

  /// Local sign-out: the server revokes the device (and the push token / topic), then a fresh guest is created.
  Future<void> signOut() async {
    await _repo.logout();
    me.value = null;
    await _crash.setUser(null);
    await ensureSession();
  }

  /// Shown instead of a real profile when `/v1/me` is unreachable (offline start).
  MeProfile profileFallback() => MeProfile(id: me.value?.id ?? '', firstName: me.value?.firstName, isGuest: me.value?.isGuest ?? true);

  /// The token is gone (revoked, reused, account deleted): local sign-out and a new guest. Downloads are kept.
  Future<void> resetToGuest({bool keepAccountHint = false}) async {
    me.value = null;
    await _store.clear();
    wasAccount.value = keepAccountHint;
    await _crash.setUser(null);
    await ensureSession();
  }

  /// True after a forced sign-out of a real account: the UI says "Please log in again" (spec §10).
  final wasAccount = false.obs;

  void _set(AuthSession s) {
    me.value = s.me;
    _writeCachedMe(s.me);
    _crash.setUser(s.me.id);
  }
}
