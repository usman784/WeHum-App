import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Minimal key/value port so tests do not need the Keychain.
abstract class SecureKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class KeychainKv implements SecureKv {
  const KeychainKv([this._s = const FlutterSecureStorage()]);
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// Holds tokens. Access token in memory, refresh token + install id in secure storage (spec §6.2).
class SessionStore {
  SessionStore(this._kv);
  final SecureKv _kv;
  String? accessToken;

  Future<String> installId() async {
    var id = await _kv.read('install_id');
    if (id == null) {
      id = const Uuid().v4();
      await _kv.write('install_id', id);
    }
    return id;
  }

  Future<String?> refreshToken() => _kv.read('refresh_token');

  Future<void> save({required String access, required String refresh}) async {
    accessToken = access;
    await _kv.write('refresh_token', refresh);
  }

  /// Signs out locally. The install id stays so the same phone gets the same guest again.
  Future<void> clear() async {
    accessToken = null;
    await _kv.delete('refresh_token');
  }
}
