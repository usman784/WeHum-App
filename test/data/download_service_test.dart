import 'dart:io';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/audio/download_engine.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/download_service.dart';

class FakeEngine implements DownloadEngine {
  final calls = <({String url, int resumeFrom})>[];
  int size = 1000;
  int failTimes = 0; // first N calls throw 403 after writing half
  bool slow = false;
  @override
  Future<int> download(String url, String path, {int resumeFrom = 0, void Function(int, int)? onProgress, CancelToken? cancel}) async {
    calls.add((url: url, resumeFrom: resumeFrom));
    final f = File(path);
    if (failTimes > 0) {
      failTimes--;
      await f.writeAsBytes(List.filled(400, 1), mode: resumeFrom > 0 ? FileMode.append : FileMode.write);
      throw DioException(requestOptions: RequestOptions(path: url), type: DioExceptionType.badResponse, response: Response(requestOptions: RequestOptions(path: url), statusCode: 403));
    }
    if (slow) {
      await f.writeAsBytes(List.filled(100, 1));
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        if (cancel?.isCancelled ?? false) throw DioException(requestOptions: RequestOptions(path: url), type: DioExceptionType.cancel);
      }
    }
    final remaining = size - resumeFrom;
    await f.writeAsBytes(List.filled(remaining, 2), mode: resumeFrom > 0 ? FileMode.append : FileMode.write);
    onProgress?.call(size, size);
    return size;
  }
}

class CountingMedia extends MockMediaRepository {
  final calls = <({bool download, bool fresh})>[];
  @override
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false}) async {
    calls.add((download: download, fresh: fresh));
    return PlayUrl(type: 'audio', url: 'https://cdn/${calls.length}', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 6)));
  }
}

class FixedStorage implements StorageProbe {
  FixedStorage(this.free);
  final int free;
  @override
  Future<int?> freeBytes() async => free;
}

Future<void> until(bool Function() cond) async {
  for (var i = 0; i < 400 && !cond(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  late AppDatabase db;
  late Directory dir;
  late FakeEngine engine;
  late CountingMedia media;
  late AccessService access;
  late AnalyticsService analytics;

  Future<DownloadService> make({StorageProbe? storage, bool wifiOnly = false, bool wifi = true}) async {
    final s = DownloadService(db: db, media: media, engine: engine, root: dir, access: access, analytics: analytics, storage: storage, wifiOnly: () => wifiOnly, onWifi: () async => wifi);
    return s.init();
  }

  setUp(() async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase.memory();
    dir = await Directory.systemTemp.createTemp('wehum-dl');
    engine = FakeEngine();
    media = CountingMedia();
    access = AccessService()..entitlement.value = const Entitlement(active: true);
    analytics = AnalyticsService();
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('download completes: file on disk, index done, pathFor finds it (offline playback), events tracked', () async {
    final s = await make();
    await s.start(const DownloadKey('s-deep'), title: 'The Long Meditation');
    await until(() => s.isDownloaded('s-deep'));
    expect(s.isDownloaded('s-deep'), true);
    final path = await s.pathFor(const PlaySession('s-deep'));
    expect(path, isNotNull);
    expect(await File(path!).length(), 1000);
    expect(media.calls.single.download, true); // the 7-day download URL
    expect(s.downloadedIds, {'s-deep'});
    expect(s.usedBytes, 1000);
    expect(analytics.drain().map((e) => e['name']), containsAll(['download_start', 'download_complete']));
    expect(await s.pathFor(const PlaySession('other')), isNull);
  });

  test('the file gets the extension its bytes say (AVPlayer refuses a bare .media): mp4 → .mp4, mp3 → .mp3', () async {
    final s = await make();
    await s.start(const DownloadKey('s-deep'), title: 'Video');
    await until(() => s.isDownloaded('s-deep'));
    final raw = (await s.pathFor(const PlaySession('s-deep')))!; // fake bytes: unknown, stays as is
    expect(raw.endsWith('.media'), true);
    final f = File(raw);
    final bytes = await f.readAsBytes();
    bytes.setRange(0, 12, [0, 0, 0, 0x20, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d]); // ....ftypisom
    await f.writeAsBytes(bytes);
    final p = (await s.pathFor(const PlaySession('s-deep')))!;
    expect(p.endsWith('.mp4'), true);
    expect(await File(p).exists(), true);
    expect(await File(raw).exists(), false);
    expect(await s.pathFor(const PlaySession('s-deep')), p); // stored, found again
    final g = File(p.replaceAll('.mp4', '.media'));
    await File(p).rename(g.path);
    await db.upsertDownload(DownloadsCompanion(sessionId: const Value('s-deep'), filePath: Value(g.path), createdAt: Value(DateTime.now())));
    final b2 = await g.readAsBytes();
    b2.setRange(0, 3, [0x49, 0x44, 0x33]); // ID3
    b2.setRange(4, 12, List.filled(8, 0));
    await g.writeAsBytes(b2);
    expect((await s.pathFor(const PlaySession('s-deep')))!.endsWith('.mp3'), true);
  });

  test('Wi-Fi only: refuses on mobile data, downloads on Wi-Fi, and is off when the switch is off', () async {
    final cell = await make(wifiOnly: true, wifi: false);
    await expectLater(cell.start(const DownloadKey('s-a'), title: 'A'), throwsA(isA<WifiRequired>()));
    expect(media.calls, isEmpty);
    expect(cell.errors['s-a#0'], contains('Wi-Fi'));
    final wifi = await make(wifiOnly: true, wifi: true);
    await wifi.start(const DownloadKey('s-a'), title: 'A');
    await until(() => wifi.isDownloaded('s-a'));
    expect(wifi.isDownloaded('s-a'), true);
    final free = await make(wifiOnly: false, wifi: false);
    await free.start(const DownloadKey('s-b'), title: 'B');
    await until(() => free.isDownloaded('s-b'));
    expect(free.isDownloaded('s-b'), true);
  });

  test('MOTD downloads are per variant', () async {
    final s = await make();
    await s.start(const DownloadKey('motd:2026-10-07', 10), title: 'Steady Under Pressure · 10 min');
    await s.start(const DownloadKey('motd:2026-10-07', 30), title: 'Steady Under Pressure · 30 min');
    await until(() => s.isDownloaded('motd:2026-10-07', 10) && s.isDownloaded('motd:2026-10-07', 30));
    expect(await s.pathFor(const PlayMotd('2026-10-07', 10)), isNot(await s.pathFor(const PlayMotd('2026-10-07', 30))));
    expect(await s.pathFor(const PlayMotd('2026-10-07', 45)), isNull);
    await s.remove(const DownloadKey('motd:2026-10-07', 10));
    expect(await s.pathFor(const PlayMotd('2026-10-07', 10)), isNull);
    expect(await s.pathFor(const PlayMotd('2026-10-07', 30)), isNotNull);
  });

  test('expired signed URL / dropped connection: a fresh URL is requested and the file continues from the byte offset', () async {
    engine.failTimes = 1;
    final s = await make();
    await s.start(const DownloadKey('s-deep'), title: 'x');
    await until(() => s.isDownloaded('s-deep'));
    expect(s.isDownloaded('s-deep'), true);
    expect(engine.calls.length, 2);
    expect(engine.calls[0].resumeFrom, 0);
    expect(engine.calls[1].resumeFrom, 400);
    expect(media.calls.map((c) => c.fresh), [false, true]);
    expect(await File((await s.pathFor(const PlaySession('s-deep')))!).length(), 1000);
  });

  test('gives up after the retries with a friendly message and a failed row (can be retried)', () async {
    engine.failTimes = 10;
    final s = await make();
    await s.start(const DownloadKey('s-deep'), title: 'x');
    await until(() => s.find('s-deep')?.status == 'failed');
    expect(s.find('s-deep')!.status, 'failed');
    expect(s.errors['s-deep#0'], contains('Download failed'));
    expect(analytics.drain().map((e) => e['name']), contains('download_fail'));
  });

  test('pause keeps the partial file; start again resumes from its size', () async {
    engine.slow = true;
    final s = await make();
    await s.start(const DownloadKey('s-deep'), title: 'x');
    await until(() => engine.calls.isNotEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await s.pause(const DownloadKey('s-deep'));
    await until(() => s.find('s-deep')?.status == 'paused');
    engine.slow = false;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await s.start(const DownloadKey('s-deep'), title: 'x');
    await until(() => s.isDownloaded('s-deep'));
    expect(engine.calls.last.resumeFrom, 100); // the partial bytes were kept
    expect(s.isDownloaded('s-deep'), true);
  });

  test('not enough space is refused before anything is downloaded', () async {
    final s = await make(storage: FixedStorage(5 * 1024 * 1024));
    await expectLater(s.start(const DownloadKey('s-big'), title: 'x', estimatedBytes: 40 * 1024 * 1024), throwsA(isA<NotEnoughSpace>()));
    expect(s.errors['s-big#0'], contains('Not enough space'));
    expect(engine.calls, isEmpty);
    expect(s.find('s-big'), isNull);
  });

  test('delete and clear all remove files and rows', () async {
    final s = await make();
    await s.start(const DownloadKey('a'), title: 'a');
    await s.start(const DownloadKey('b'), title: 'b');
    await until(() => s.isDownloaded('a') && s.isDownloaded('b'));
    final pa = (await s.pathFor(const PlaySession('a')))!;
    await s.remove(const DownloadKey('a'));
    expect(await File(pa).exists(), false);
    expect(s.isDownloaded('a'), false);
    await s.clearAll();
    await until(() => s.items.isEmpty);
    expect(s.items, isEmpty);
    expect(dir.listSync(), isEmpty);
  });

  test('membership ended: downloads are removed after 7 days, not before; members keep them', () async {
    final s = await make();
    await s.start(const DownloadKey('a'), title: 'a');
    await until(() => s.isDownloaded('a'));
    final ends = DateTime.utc(2026, 10, 12);
    access.entitlement.value = Entitlement(active: false, expiresAt: ends);
    await s.purgeIfNotMember(now: ends.add(const Duration(days: 6)));
    expect(s.isDownloaded('a'), true);
    await s.purgeIfNotMember(now: ends.add(const Duration(days: 8)));
    await until(() => s.items.isEmpty);
    expect(s.isDownloaded('a'), false);
    access.entitlement.value = const Entitlement(active: true);
    await s.start(const DownloadKey('b'), title: 'b');
    await until(() => s.isDownloaded('b'));
    await s.purgeIfNotMember(now: ends.add(const Duration(days: 400)));
    expect(s.isDownloaded('b'), true);
  });
}
