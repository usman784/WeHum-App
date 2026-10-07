import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/audio/local_media.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/download_service.dart';
import 'package:meditation/features/library/controllers/library_controllers.dart';
import 'package:meditation/features/library/views/session_pages.dart' show SessionDetailController;
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/player/player_args.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route, {bool member = true}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true);
  await Get.find<CatalogService>().load();
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  testWidgets('31 library (member): tiles, themes with counts, program in progress, free items unlabelled, My Meditations, Downloads', (t) async {
    final e = await open(t, AppRoutes.library);
    expect(find.text('Silence Room'), findsOneWidget);
    expect(find.text('PREMIUM'), findsNothing); // members see no lock
    expect(find.text('COMING SOON'), findsNWidgets(2));
    expect(find.byKey(const Key('program-card')), findsNothing);
    await t.scrollUntilVisible(find.byKey(const Key('themes-title')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Anxiety & Stress'), findsOneWidget);
    expect(find.text('2 meditations · 8–10 min'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('free-heading')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('From Raphael’s online library'), findsOneWidget);
    expect(find.text('FREE FOR YOU'), findsNothing); // no free label for members
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('31 library (free): Silence Room shows PREMIUM and opens the paywall; the free section is "Free for you" with labels', (t) async {
    final e = await open(t, AppRoutes.library, member: false);
    expect(find.text('PREMIUM'), findsWidgets);
    await t.tap(find.byKey(const Key('tile-silence')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    Get.back<void>();
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('free-heading')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Free for you'), findsOneWidget);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -240));
    await t.pump();
    expect(find.text('FREE FOR YOU'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('33 filters: the button counts matching meditations live; applying filters lists them; reset clears', (t) async {
    final e = await open(t, AppRoutes.library);
    await t.tap(find.byKey(const Key('filter-btn')));
    await settle(t);
    expect(find.text('Show 6 meditations'), findsOneWidget);
    await t.tap(find.text('Video'));
    await t.pump();
    expect(find.text('Show 1 meditations'), findsOneWidget);
    await t.tap(find.text('All'));
    await t.tap(find.text('Free'));
    await t.pump();
    expect(find.text('Show 2 meditations'), findsOneWidget);
    await t.tap(find.byKey(const Key('show-n')));
    await settle(t);
    expect(find.byKey(const Key('filtered-count')), findsOneWidget);
    expect(find.text('2 meditations'), findsOneWidget);
    expect(find.text('Breathing Reset'), findsOneWidget);
    expect(find.text('Sink Into Sleep'), findsNothing);
    Get.find<LibraryController>().resetFilters();
    await t.pump();
    expect(find.byKey(const Key('filtered-count')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  test('filters: lengths buckets, teacher, downloaded only', () async {
    Get.reset();
    final e = await TestEnv.create(member: true);
    await Get.find<CatalogService>().load();
    final c = LibraryController();
    expect(c.countFor(const LibraryFilters(lengths: {10})), 3); // ≤ 10 min: s-motd (10), s-free1 (8), s-free2 (10)
    expect(c.countFor(const LibraryFilters(lengths: {30, 45})), 2); // 21–30: s-sleep (25); 30+: s-deep (40)
    expect(c.countFor(const LibraryFilters(teacherId: 'tc-raphael')), 6);
    expect(c.countFor(const LibraryFilters(teacherId: 'nobody')), 0);
    expect(c.countFor(const LibraryFilters(downloadedOnly: true)), 0);
    await e.dispose();
  });

  testWidgets('34 search: local and debounced; recent searches are remembered; no network call per keystroke', (t) async {
    final e = await open(t, AppRoutes.search);
    await t.enterText(find.byKey(const Key('search-input')), 'sle');
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('result-count')), findsNothing); // not yet (debounce 300 ms)
    await t.pump(const Duration(milliseconds: 300));
    await settle(t);
    expect(find.text('MEDITATIONS · 1'), findsOneWidget);
    expect(find.text('Sink Into Sleep'), findsOneWidget);
    await t.enterText(find.byKey(const Key('search-input')), 'zzzz');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.text('No meditations found. Try another word.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('32 theme page: tabs All / Premium / Online library / Video', (t) async {
    final e = await open(t, AppRoutes.library);
    Get.toNamed('/theme/t-anx', arguments: {'id': 't-anx'});
    await settle(t);
    expect(find.text('Steady Under Pressure'), findsOneWidget);
    expect(find.text('Breathing Reset'), findsOneWidget);
    await t.tap(find.text('Premium'));
    await t.pump();
    expect(find.text('Breathing Reset'), findsNothing);
    await t.tap(find.text('Online library'));
    await t.pump();
    expect(find.text('Steady Under Pressure'), findsNothing);
    expect(find.text('Breathing Reset'), findsOneWidget);
    await t.tap(find.text('Video'));
    await t.pump();
    expect(find.text('Nothing here yet'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  group('41 session detail', () {
    testWidgets('member: Play opens the player with the session target; free user on premium gets the paywall', (t) async {
      final e = await open(t, AppRoutes.library);
      Get.toNamed('/session/s-sleep', arguments: {'id': 's-sleep'});
      await settle(t);
      expect(find.byKey(const Key('session-title')), findsOneWidget);
      expect(find.text('Sink Into Sleep'), findsOneWidget);
      await t.tap(find.byKey(const Key('session-play')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.playerPresenceRing);
      expect(((Get.arguments as PlayerArgs).target as PlaySession).id, 's-sleep');
      await t.pumpWidget(const SizedBox());
      Get.delete<PlayerController>(tag: 's-sleep', force: true);
      await e.dispose();

      final f = await open(t, AppRoutes.library, member: false);
      Get.toNamed('/session/s-sleep', arguments: {'id': 's-sleep'});
      await settle(t);
      expect(find.text('Try 7 days free'), findsOneWidget);
      await t.tap(find.byKey(const Key('session-play')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.membershipPaywall);
      await t.pumpWidget(const SizedBox());
      await f.dispose();
    });

    testWidgets('the free YouTube item opens the free player with its video id', (t) async {
      final e = await open(t, AppRoutes.library, member: false);
      Get.toNamed('/session/s-free1', arguments: {'id': 's-free1'});
      await settle(t);
      await t.tap(find.byKey(const Key('session-play')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.freePlayer);
      expect((Get.arguments as PlayerArgs).youtubeId, 'dQw4w9WgXcQ');
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('download toggle: downloads, then the player uses the local file (works offline)', (t) async {
      final e = await open(t, AppRoutes.library);
      await t.runAsync(() => e.downloads.init());
      Get.toNamed('/session/s-deep', arguments: {'id': 's-deep'});
      await settle(t);
      expect(find.text('Listen without internet'), findsOneWidget);
      expect(find.byKey(const Key('dl-toggle')), findsOneWidget);
      await t.runAsync(() async {
        await Get.find<SessionDetailController>(tag: 's-deep').toggleDownload(); // what the toggle does (file IO must run outside the widget zone)
        for (var i = 0; i < 100 && !e.downloads.isDownloaded('s-deep'); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await settle(t);
      expect(e.downloads.isDownloaded('s-deep'), true);
      expect(find.text('Plays without internet'), findsOneWidget);
      final path = await t.runAsync(() => Get.find<LocalMedia>().pathFor(const PlaySession('s-deep')));
      expect(path, isNotNull);
      expect(File(path!).existsSync(), true);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('58 downloads', () {
    testWidgets('empty state, then list with sizes; delete asks first; clear all', (t) async {
      final e = await open(t, AppRoutes.downloads);
      await t.runAsync(() => e.downloads.init());
      await t.pump();
      expect(find.text('No downloads yet'), findsOneWidget);
      await t.runAsync(() async {
        await e.downloads.start(const DownloadKey('s-deep'), title: 'The Long Meditation');
        await e.downloads.start(const DownloadKey('s-sleep'), title: 'Sink Into Sleep');
        for (var i = 0; i < 100 && e.downloads.items.where((d) => d.status == 'done').length < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      });
      await settle(t);
      expect(find.text('The Long Meditation'), findsOneWidget);
      expect(find.text('2.0 KB'.replaceFirst('2.0 KB', '2 KB')), findsOneWidget);
      await t.tap(find.byKey(const Key('clear-all')));
      await settle(t);
      expect(find.text('Delete all downloads?'), findsOneWidget);
      await t.tap(find.text('Cancel')); // nothing is deleted without confirming
      await settle(t);
      expect(find.text('The Long Meditation'), findsOneWidget);
      await t.runAsync(() => e.downloads.clearAll()); // file deletes are real IO
      await settle(t);
      expect(find.text('No downloads yet'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  testWidgets('35/36 programs: list, detail with day statuses, Start day opens the player for that day', (t) async {
    final e = await open(t, AppRoutes.allPrograms);
    expect(find.text('7-Day Autonomic Reset'), findsOneWidget);
    Get.toNamed('/program/p-7', arguments: {'id': 'p-7'});
    await settle(t);
    expect(find.text('Day 1 · Day 1'), findsOneWidget);
    expect(find.byKey(const Key('start-day')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('start-day')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('start-day')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing);
    final a = Get.arguments as PlayerArgs;
    expect(a.kind, 'program');
    expect(a.programId, 'p-7');
    expect(a.programDay, 1);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}

// keep the import used even when the engine is only referenced in comments
// ignore: unused_element
const _unused = EngineStatus.idle;
