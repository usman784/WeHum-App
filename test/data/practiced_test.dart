import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/practiced_service.dart';
import 'package:meditation/core/services/sync_service.dart';

/// The server is unreachable until [offline] is switched off.
class _Flaky extends MockMeditationRepository {
  bool offline = false;
  @override
  Future<MeditationResult> record(MeditationRecord m) async {
    if (offline) throw ApiException(ErrorCode.network);
    return super.record(m);
  }

  @override
  Future<Set<String>> practiced() async {
    if (offline) throw ApiException(ErrorCode.network);
    return super.practiced();
  }
}

MeditationRecord sit(String id, String session, {int sec = 600, bool completed = true}) =>
    MeditationRecord(id: id, kind: 'solo', sessionId: session, startedAt: DateTime.utc(2026, 11, 3, 8), endedAt: DateTime.utc(2026, 11, 3, 8, 10), durationSec: sec, completed: completed);

void main() {
  late AppDatabase db;
  late _Flaky repo;
  late AccessService access;
  late PracticedService practiced;
  setUp(() {
    Get.reset();
    db = AppDatabase.memory();
    repo = _Flaky();
    access = AccessService()..userId = 'u1';
    practiced = PracticedService(repo, db, access);
  });
  tearDown(() => db.close());

  group('PracticedService', () {
    test('load: what the server says is finished is practiced, free and premium alike', () async {
      repo.recorded.addAll([sit('a', 's-motd'), sit('b', 's-free1')]);
      expect(practiced.isDone('s-free1'), false);
      await practiced.load();
      expect(practiced.isDone('s-motd'), true);
      expect(practiced.isDone('s-free1'), true); // a free meditation counts the same
      expect(practiced.isDone('s-sleep'), false);
      expect(practiced.count, 2);
    });

    test('offline start: the stored copy is shown, the server answer replaces it later', () async {
      repo.recorded.add(sit('a', 's-motd'));
      await practiced.load();
      final again = PracticedService(repo, db, access);
      repo.offline = true;
      await again.load();
      expect(again.isDone('s-motd'), true); // from the stored copy
      repo.offline = false;
      repo.recorded.add(sit('b', 's-sleep'));
      await again.load();
      expect(again.isDone('s-sleep'), true);
    });

    test('socket practiced:changed marks it at once (a sit finished on another device)', () async {
      await practiced.load();
      expect(practiced.isDone('s-deep'), false);
      practiced.onSocket('s-deep');
      expect(practiced.isDone('s-deep'), true);
      final after = PracticedService(repo, db, access);
      repo.offline = true;
      await after.load();
      expect(after.isDone('s-deep'), true, reason: 'the event is stored, not only kept in memory');
    });

    test('an early mark is kept when the server counts it and taken back when it does not', () async {
      practiced.markLocal('s-motd');
      practiced.markLocal('s-free1');
      expect(practiced.isDone('s-motd'), true);
      practiced.confirm('s-motd', counted: true);
      practiced.confirm('s-free1', counted: false);
      expect(practiced.isDone('s-motd'), true);
      expect(practiced.isDone('s-free1'), false);
    });

    test('another account sees none of the first account’s marks; sign-out clears them', () async {
      repo.recorded.add(sit('a', 's-motd'));
      await practiced.load();
      expect(practiced.isDone('s-motd'), true);
      repo.recorded.clear();
      access.userId = 'u2';
      await practiced.load();
      expect(practiced.isDone('s-motd'), false);
      practiced.onSocket('s-sleep');
      await practiced.reset();
      expect(practiced.count, 0);
      final fresh = PracticedService(repo, db, access);
      repo.offline = true;
      await fresh.load();
      expect(fresh.count, 0);
    });
  });

  group('SyncService + PracticedService', () {
    test('finishing a sit marks it immediately, even offline, and the server confirms it later', () async {
      repo.offline = true;
      final sync = SyncService(repo, db, null, practiced);
      await sync.record(sit('m1', 's-free1'), waitForServer: false);
      expect(practiced.isDone('s-free1'), true, reason: 'no waiting for the network');
      repo.offline = false;
      await sync.flush();
      expect(practiced.isDone('s-free1'), true);
      final fresh = PracticedService(repo, db, access);
      await fresh.load();
      expect(fresh.isDone('s-free1'), true);
    });

    test('a sit stopped early or too short is not practiced', () async {
      final sync = SyncService(repo, db, null, practiced);
      await sync.record(sit('m2', 's-motd', completed: false), waitForServer: false);
      expect(practiced.isDone('s-motd'), false);
      await sync.record(sit('m3', 's-sleep', sec: 60), waitForServer: false); // marked at first, the server does not count it
      await sync.flush();
      expect(practiced.isDone('s-sleep'), false);
    });
  });

  group('Library filter', () {
    test('practiced / not yet practiced split the whole library, free ones included', () async {
      final catalog = CatalogService(MockCatalogRepository(), db);
      await catalog.load();
      practiced.onSocket('s-motd');
      practiced.onSocket('s-free1');
      final done = catalog.filter(practice: 'done', isPracticed: practiced.isDone).map((s) => s.id).toSet();
      final todo = catalog.filter(practice: 'todo', isPracticed: practiced.isDone).map((s) => s.id).toSet();
      final all = catalog.filter().map((s) => s.id).toSet();
      expect(done, {'s-motd', 's-free1'});
      expect(done.intersection(todo), isEmpty);
      expect(done.union(todo), all);
      expect(catalog.filter(practice: 'todo', type: 'free', isPracticed: practiced.isDone).map((s) => s.id), ['s-free2']);
      practiced.onSocket('s-free2'); // real time: the lists follow the next event
      expect(catalog.filter(practice: 'todo', type: 'free', isPracticed: practiced.isDone), isEmpty);
    });
  });
}
