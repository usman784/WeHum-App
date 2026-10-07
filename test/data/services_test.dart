import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/data/mock/mock_data.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/data/models/content.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/realtime/socket_events.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/sync_service.dart';
import 'package:meditation/core/utils/uuid7.dart';

class FlakyMeditations extends MockMeditationRepository {
  bool offline = true;
  @override
  Future<MeditationResult> record(MeditationRecord m) async {
    if (offline) throw ApiException(ErrorCode.network);
    return super.record(m);
  }

  @override
  Future<List<MeditationResult>> batch(List<MeditationRecord> items) async {
    if (offline) throw ApiException(ErrorCode.network);
    return super.batch(items);
  }
}

MeditationRecord med(String id, {int sec = 600}) =>
    MeditationRecord(id: id, kind: 'solo', sessionId: 's-motd', startedAt: DateTime.utc(2026, 10, 7, 8), endedAt: DateTime.utc(2026, 10, 7, 8, 10), durationSec: sec, completed: true);

void main() {
  late AppDatabase db;
  setUp(() {
    Get.reset();
    db = AppDatabase.memory();
  });
  tearDown(() => db.close());

  group('CatalogService', () {
    test('downloads once, stores locally, then starts from the stored copy offline', () async {
      final s1 = CatalogService(MockCatalogRepository(), db);
      await s1.load();
      expect(s1.catalog.value!.sessions, isNotEmpty);
      // a new app start with no network: stored snapshot is used
      final s2 = CatalogService(_Offline(), db);
      await s2.load(serverVersion: 99);
      expect(s2.catalog.value!.version, 1);
      expect(s2.catalog.value!.sessions.length, s1.catalog.value!.sessions.length);
      expect(s2.lastError, isNotNull);
      expect(s2.catalog.value!.sos.tiles, isNotEmpty);
      expect(s2.catalog.value!.programs.single.days.length, 7);
    });

    test('same version → no download; local search and filters', () async {
      final s = CatalogService(MockCatalogRepository(), db);
      await s.load();
      await s.load(serverVersion: 1); // returns null from repo, nothing replaced
      expect((await s.search('pressure')).map((e) => e.id), ['s-motd']);
      expect((await s.search('sleep')).map((e) => e.id), contains('s-sleep'));
      expect(s.filter(themeId: 't-slp').map((e) => e.id), ['s-sleep']);
      expect(s.filter(lengthBuckets: {10}).every((e) => e.minutes <= 10), true);
      expect(s.filter(type: 'free').every((e) => !e.isPremium), true);
      expect(s.filter(type: 'video').single.id, 's-focus');
      expect(s.filter(downloadedOnly: true, downloadedIds: {'s-deep'}).single.id, 's-deep');
      expect(s.themeLine(MockData.themes.first), startsWith('2 meditations'));
    });
  });

  group('SyncService outbox', () {
    test('offline: stays queued; online: flushed FIFO, idempotent, payoff gets numbers', () async {
      final repo = FlakyMeditations();
      final sync = SyncService(repo, db);
      final r = await sync.record(med('11111111-1111-7111-8111-111111111111'));
      expect(r, isNull);
      await sync.record(med('22222222-2222-7222-8222-222222222222'), waitForServer: false);
      expect(sync.pending.value, 2);
      repo.offline = false;
      await sync.flush();
      expect(sync.pending.value, 0);
      expect(repo.recorded.map((e) => e.id), ['11111111-1111-7111-8111-111111111111', '22222222-2222-7222-8222-222222222222']);
      // online record returns the server numbers for the payoff screen
      final res = await sync.record(med('33333333-3333-7333-8333-333333333333'));
      expect(res!.togetherPeople, 412);
      expect(res.canDedicate, true);
      await sync.flush(); // wait until idle
    });

    test('a run in progress is not started twice', () async {
      final repo = FlakyMeditations()..offline = false;
      final sync = SyncService(repo, db);
      await db.enqueueMeditation('a', '{"id":"a","kind":"solo","startedAt":"2026-10-07T08:00:00Z","endedAt":"2026-10-07T08:10:00Z","durationSec":600}');
      await Future.wait([sync.flush(), sync.flush(), sync.flush()]);
      expect(repo.recorded.length, 1);
      expect(sync.pending.value, 0);
    });
  });

  test('uuid v7: version/variant bits, time ordered, unique', () {
    final a = uuid7(DateTime.utc(2026, 1, 1)), b = uuid7(DateTime.utc(2026, 1, 2));
    expect(a, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')));
    expect(a.compareTo(b) < 0, true);
    expect({for (var i = 0; i < 500; i++) uuid7()}.length, 500);
  });

  test('AccessService: plans, socket entitlement and SDK/server precedence', () {
    final a = AccessService();
    expect(a.plan, 'guest_free');
    a.sdkPremium.value = true; // SDK says premium before the server confirms (spec §9)
    expect(a.isMember, true);
    expect(a.serverMember, false);
    expect(a.plan, 'guest_member');
    a.sdkPremium.value = false;
    a.isGuest.value = false;
    a.onSocket(const EntitlementChanged(active: true, periodType: 'trial', productId: 'wehum_annual'));
    expect(a.plan, 'trial');
    a.onSocket(const EntitlementChanged(active: true, periodType: 'normal', billingIssue: true));
    expect(a.plan, 'member');
    expect(a.billingIssue, true);
    a.onSocket(const EntitlementChanged(active: false));
    expect(a.plan, 'free');
  });

  test('model parsing is tolerant: missing optional fields never throw', () {
    final s = SessionSummary.fromJson({'id': 'x', 'title': 'T'});
    expect(s.access, Access.premium);
    expect(s.minutes, 0);
    final t = Catalog.fromJson({'version': 2});
    expect(t.sessions, isEmpty);
    expect(t.sos.title, 'How can I help?');
  });
}

class _Offline extends MockCatalogRepository {
  @override
  Future<Catalog?> catalog({int? knownVersion}) async => throw ApiException(ErrorCode.network);
}
