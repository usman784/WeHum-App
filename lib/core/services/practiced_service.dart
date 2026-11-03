import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import 'access_service.dart';

/// Which meditations the person has finished (free and premium alike): the "Practiced" mark on every list and the Library filter.
///
/// Live three ways: the moment a sit is finished on this phone ([markLocal], before the server answers, works offline),
/// the socket `practiced:changed` for a sit finished on another device, and a reload whenever the socket reconnects or the app resumes.
/// The server decides what counts (a sit stopped early does not): its answer for a local mark either confirms or takes it back.
class PracticedService extends GetxService {
  PracticedService(this._repo, this._db, this._access);
  final MeditationRepository _repo;
  final AppDatabase _db;
  final AccessService _access;

  static const _cacheKey = 'practiced';

  /// Finished according to the server (and the stored copy of it).
  final _server = <String>{}.obs;

  /// Finished on this phone, not yet confirmed by the server.
  final _local = <String>{}.obs;
  /// Grows with every change, for screens that list the history and refresh with it.
  final revision = 0.obs;
  String? _owner;
  bool _loading = false;

  /// Reading this inside an `Obx` makes the widget rebuild when a meditation becomes practiced.
  bool isDone(String sessionId) =>
      _server.contains(sessionId) || _local.contains(sessionId);
  int get count => {..._server, ..._local}.length;

  /// Stored copy first (instant, works offline), then the server.
  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    try {
      final uid = _access.userId;
      if (_owner != null && uid != null && uid != _owner) {
        _clear(); // another account took over
      }
      _owner = uid ?? _owner;
      if (_server.isEmpty) {
        final raw = await _db.getCache(_cacheKey);
        if (raw != null) {
          try {
            final j = jsonDecode(raw) as Map;
            if (j['user'] == uid || uid == null) {
              _server.addAll((j['ids'] as List).cast<String>());
            }
          } catch (_) {
            /* unreadable copy: the server answer below replaces it */
          }
        }
      }
      try {
        final ids = await _repo.practiced();
        _server.assignAll(ids);
        _local.removeWhere(ids.contains);
        revision.value++;
        await _db.putCache(
            _cacheKey, jsonEncode({'user': uid, 'ids': ids.toList()}));
      } catch (_) {/* offline: what is stored stays */}
    } finally {
      _loading = false;
    }
  }

  /// A sit was finished on this phone.
  void markLocal(String sessionId) {
    _local.add(sessionId);
    revision.value++;
  }

  /// The server answered for a sit of this phone: it counted (keep) or it did not (take the early mark back).
  void confirm(String sessionId, {required bool counted}) {
    _local.remove(sessionId);
    if (counted) {
      _server.add(sessionId);
      _persist();
    }
    revision.value++;
  }

  /// Socket `practiced:changed`: a sit was finished (any device).
  void onSocket(String sessionId) {
    _local.remove(sessionId);
    if (_server.add(sessionId)) _persist();
    revision.value++;
  }

  /// Sign-out or another account.
  Future<void> reset() async {
    _clear();
    await _db.putCache(
        _cacheKey, jsonEncode({'user': null, 'ids': <String>[]}));
  }

  void _clear() {
    _server.clear();
    _local.clear();
    _owner = null;
  }

  Future<void> _persist() => _db.putCache(
      _cacheKey, jsonEncode({'user': _access.userId, 'ids': _server.toList()}));
}
