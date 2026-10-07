import 'dart:convert';
import '../contracts/repositories.dart';
import '../models/activity.dart';

/// Signed play URLs are valid for hours (spec §6.2): Session detail prefetches, the player then starts at once.
/// Entries expire a few minutes before the URL does; `fresh: true` always asks the server (expired-URL recovery).
class CachingMediaRepository implements MediaRepository {
  CachingMediaRepository(this._inner);
  final MediaRepository _inner;
  final _cache = <String, PlayUrl>{};

  String _key(PlayTarget t, bool download) => jsonEncode([t.toBody(download: download)]);

  @override
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false}) async {
    final k = _key(target, download);
    final hit = _cache[k];
    if (!fresh && hit != null && !hit.expired) return hit;
    final u = await _inner.playUrl(target, download: download, fresh: fresh);
    if (!download) _cache[k] = u;
    return u;
  }

  /// Fire and forget: errors are ignored (the player asks again when needed).
  Future<void> prefetch(PlayTarget target) async {
    try {
      await playUrl(target);
    } catch (_) {}
  }

  void clear() => _cache.clear();
}
