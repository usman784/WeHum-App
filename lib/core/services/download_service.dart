import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:get/get.dart' hide Value;
import 'package:path/path.dart' as p;
import '../audio/download_engine.dart';
import '../audio/local_media.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/activity.dart';
import '../errors/error_code.dart';
import 'access_service.dart';
import 'analytics_service.dart';

/// A download target: an ordinary session (variant 0) or a Meditation-of-the-Day length (`motd:{date}` + 10/30/45).
class DownloadKey {
  const DownloadKey(this.id, [this.variant = 0]);
  final String id;
  final int variant;
  PlayTarget get target => id.startsWith('motd:') ? PlayMotd(id.substring(5), variant) : PlaySession(id);
  static DownloadKey? forTarget(PlayTarget t) => switch (t) { PlaySession() => DownloadKey(t.id), PlayMotd() => DownloadKey('motd:${t.date}', t.lengthMin), _ => null };
}

/// Offline downloads (spec §10, §12 #58): files per variant in the app's documents folder, index in drift,
/// resumable, signed URL re-requested when it expires, auto-removed 7 days after the membership ends.
class DownloadService extends GetxService implements LocalMedia {
  DownloadService({required AppDatabase db, required MediaRepository media, required DownloadEngine engine, required Directory root, required AccessService access, AnalyticsService? analytics, StorageProbe? storage, this.maxRetries = 2, this.wifiOnly, this.onWifi})
      : _db = db, _media = media, _engine = engine, _root = root, _access = access, _analytics = analytics, _storage = storage ?? const NoStorageProbe();
  final AppDatabase _db;
  final MediaRepository _media;
  final DownloadEngine _engine;
  final Directory _root;
  final AccessService _access;
  final AnalyticsService? _analytics;
  final StorageProbe _storage;
  final int maxRetries;
  /// Settings switch and link check; both null = no restriction (tests).
  final bool Function()? wifiOnly;
  final Future<bool> Function()? onWifi;

  final items = <Download>[].obs;
  final progress = <String, double>{}.obs; // "id#variant" → 0..1
  final errors = <String, String>{}.obs;
  StreamSubscription<List<Download>>? _sub;
  final _cancels = <String, CancelToken>{};

  String _k(String id, int v) => '$id#$v';
  Set<String> get downloadedIds => {for (final d in items) if (d.status == 'done') d.sessionId};
  int get usedBytes => items.fold(0, (s, d) => s + d.bytes);

  Download? find(String id, [int variant = 0]) => items.where((d) => d.sessionId == id && d.variant == variant).firstOrNull;
  bool isDownloaded(String id, [int variant = 0]) => find(id, variant)?.status == 'done';

  /// The list the UI shows. Re-read after every change (the drift stream only backs up changes from elsewhere).
  Future<void> _reload() async => items.assignAll(await _db.allDownloads());

  Future<DownloadService> init() async {
    await _reload();
    _sub = _db.watchDownloads().listen((l) => items.assignAll(l));
    if (!_root.existsSync()) _root.createSync(recursive: true); // sync: cheap, and startup never waits on disk
    await purgeIfNotMember();
    return this;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  @override
  Future<String?> pathFor(PlayTarget target) async {
    final k = DownloadKey.forTarget(target);
    if (k == null) return null;
    final d = await _db.downloadFor(k.id, k.variant);
    if (d == null || d.status != 'done' || d.filePath == null) return null;
    return await File(d.filePath!).exists() ? d.filePath : null;
  }

  Future<void> start(DownloadKey key, {required String title, int? estimatedBytes}) async {
    final k = _k(key.id, key.variant);
    if (_cancels.containsKey(k)) return;
    errors.remove(k);
    if ((wifiOnly?.call() ?? false) && !(await (onWifi?.call() ?? Future.value(true)))) {
      errors[k] = 'Wi-Fi only is on. Connect to Wi-Fi to download.';
      throw WifiRequired();
    }
    final free = await _storage.freeBytes();
    if (free != null && estimatedBytes != null && free < estimatedBytes * 1.2) {
      errors[k] = 'Not enough space (needs ${(estimatedBytes / 1048576).ceil()} MB)';
      throw NotEnoughSpace(estimatedBytes);
    }
    final existing = await _db.downloadFor(key.id, key.variant);
    final path = existing?.filePath ?? p.join(_root.path, '${key.id.replaceAll(':', '_')}_${key.variant}.media');
    await _db.upsertDownload(DownloadsCompanion.insert(sessionId: key.id, variant: Value(key.variant), title: Value(title), filePath: Value(path), status: const Value('running'), createdAt: existing?.createdAt ?? DateTime.now()));
    await _reload();
    _analytics?.track('download_start', {'session_id': key.id});
    _cancels[k] = CancelToken();
    unawaited(_run(key, path, title));
  }

  Future<void> _run(DownloadKey key, String path, String title) async {
    final k = _k(key.id, key.variant);
    var attempts = 0;
    try {
      while (true) {
        final have = await File(path).exists() ? await File(path).length() : 0;
        final url = await _media.playUrl(key.target, download: true, fresh: attempts > 0);
        final u = url.url ?? url.hlsUrl;
        if (u == null) throw ApiException(ErrorCode.notFound);
        try {
          final total = await _engine.download(u, path, resumeFrom: have, cancel: _cancels[k], onProgress: (r, t) {
            if (t > 0) progress[k] = r / t;
            _db.upsertDownload(DownloadsCompanion(sessionId: Value(key.id), variant: Value(key.variant), bytes: Value(r), totalBytes: Value(t), status: const Value('running'), createdAt: Value(DateTime.now())));
          });
          await _db.upsertDownload(DownloadsCompanion(sessionId: Value(key.id), variant: Value(key.variant), title: Value(title), filePath: Value(path), bytes: Value(total), totalBytes: Value(total), expiresAt: Value(url.expiresAt), status: const Value('done'), createdAt: Value(DateTime.now())));
          progress.remove(k);
          await _reload();
          _analytics?.track('download_complete', {'session_id': key.id, 'bytes': total});
          return;
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) rethrow;
          // expired signed URL (403) or a dropped connection: ask for a fresh URL and continue from the byte offset
          if (++attempts > maxRetries) rethrow;
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return; // paused/cancelled: the row is updated by pause()/remove()
      await _fail(key, 'Download failed. Check your connection and try again.');
    } on FileSystemException catch (e) {
      await _fail(key, e.osError?.errorCode == 28 ? 'Not enough space on this phone' : 'Couldn’t save the file');
    } catch (_) {
      await _fail(key, 'Download failed. Try again later.');
    } finally {
      _cancels.remove(k);
    }
  }

  Future<void> _fail(DownloadKey key, String msg) async {
    errors[_k(key.id, key.variant)] = msg;
    await _db.upsertDownload(DownloadsCompanion(sessionId: Value(key.id), variant: Value(key.variant), status: const Value('failed'), createdAt: Value(DateTime.now())));
    await _reload();
    _analytics?.track('download_fail', {'session_id': key.id});
  }

  /// Pause keeps the partial file; [start] again resumes from its size.
  Future<void> pause(DownloadKey key) async {
    _cancels[_k(key.id, key.variant)]?.cancel();
    await _db.upsertDownload(DownloadsCompanion(sessionId: Value(key.id), variant: Value(key.variant), status: const Value('paused'), createdAt: Value(DateTime.now())));
    await _reload();
  }

  Future<void> remove(DownloadKey key) async {
    _cancels[_k(key.id, key.variant)]?.cancel();
    final d = await _db.downloadFor(key.id, key.variant);
    if (d?.filePath != null) {
      final f = File(d!.filePath!);
      if (await f.exists()) await f.delete();
    }
    await _db.removeDownload(key.id, key.variant);
    await _reload();
    progress.remove(_k(key.id, key.variant));
    _analytics?.track('download_delete', {'session_id': key.id});
  }

  Future<void> clearAll() async {
    for (final d in List.of(items)) {
      await remove(DownloadKey(d.sessionId, d.variant));
    }
  }

  /// Downloads belong to the membership: gone 7 days after it ended (spec §12 #58). Called at start and on entitlement changes.
  Future<void> purgeIfNotMember({DateTime? now, Duration grace = const Duration(days: 7)}) async {
    if (_access.isMember) return;
    final ends = _access.entitlement.value.expiresAt;
    if (ends == null) return; // never a member: nothing was downloaded
    if ((now ?? DateTime.now().toUtc()).isAfter(ends.add(grace))) await clearAll();
  }
}
