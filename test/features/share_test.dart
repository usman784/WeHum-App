import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/instagram_share.dart';
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/player/player_args.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

const sid = '11111111-1111-4111-8111-111111111111';
const _ig = MethodChannel('app.wehum/share');
const _paths = MethodChannel('plugins.flutter.io/path_provider');
const _sharePlus = MethodChannel('dev.fluttercommunity.plus/share');

/// Opens 45 (payoff) for a finished 5-minute meditation, then 46 (share) from "Share your meditation".
Future<TestEnv> openShare(WidgetTester t, {required bool instagramInstalled, String appId = '1234567890'}) async {
  phone(t);
  t.view.physicalSize = const Size(1170, 5600);
  final tmp = Directory.systemTemp.createTempSync('wehum-share');
  final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  m.setMockMethodCallHandler(_paths, (c) async => tmp.path);
  // the render needs real async (t.runAsync), where the deep-link plugin would otherwise find no platform side
  m.setMockMethodCallHandler(const MethodChannel('com.llfbandit.app_links/messages'), (c) async => null);
  m.setMockMethodCallHandler(const MethodChannel('com.llfbandit.app_links/events'), (c) async => null);
  final e = await TestEnv.create(member: true, onboardingDone: true);
  Get.put(InstagramShare(appId: appId));
  m.setMockMethodCallHandler(_ig, (c) async {
    igCalls.add(c);
    return c.method == 'instagramAvailable' ? instagramInstalled : true;
  });
  m.setMockMethodCallHandler(_sharePlus, (c) async {
    sheetCalls.add(c);
    return 'dev.fluttercommunity.plus/share/unavailable';
  });
  final rec = MeditationRecord(id: 'm-1', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 22, 8), endedAt: DateTime.utc(2026, 10, 22, 8, 5), durationSec: 300, completed: true);
  await t.pumpWidget(e.app());
  await settle(t);
  Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(
      player: const PlayerArgs(kind: 'motd', mode: 'solo', title: 'Steady Under Pressure', sessionId: sid), record: rec, counted: true));
  await settle(t);
  await t.tap(find.byKey(const Key('share-sit')));
  await settle(t);
  return e;
}

final igCalls = <MethodCall>[];
final sheetCalls = <MethodCall>[];

Future<void> tapAndWait(WidgetTester t, Key key) async {
  await t.runAsync(() async {
    await t.tap(find.byKey(key));
    for (var i = 0; i < 30 && igCalls.where((c) => c.method == 'instagramStory').isEmpty && sheetCalls.isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  });
  await t.pump();
}

void main() {
  setUp(() {
    igCalls.clear();
    sheetCalls.clear();
  });

  testWidgets('46 share card: the minutes as the hero number, "meditation" wording, Story and Post formats', (t) async {
    final e = await openShare(t, instagramInstalled: true);
    expect(Get.currentRoute, AppRoutes.shareYourMeditation);
    expect(find.text('Share your meditation'), findsOneWidget);
    expect(find.byKey(const Key('share-minutes')), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('MEDITATION COMPLETE'), findsOneWidget);
    expect(find.text('I meditated today.'), findsOneWidget);
    expect(find.text('Steady Under Pressure'), findsWidgets);
    expect(find.textContaining(' sat '), findsNothing); // never "I sat"
    expect(find.byKey(const Key('share-instagram')), findsOneWidget);
    await t.tap(find.text('Post'));
    await settle(t);
    expect(find.byKey(const Key('share-minutes')), findsOneWidget);
    expect(find.byKey(const Key('share-instagram')), findsNothing); // Stories are 9:16: the post goes through the share sheet
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('46 Instagram installed: one tap hands the 1080×1920 card to the story composer with our Meta App ID', (t) async {
    final e = await openShare(t, instagramInstalled: true);
    await tapAndWait(t, const Key('share-instagram'));
    expect(igCalls.map((c) => c.method), ['instagramAvailable', 'instagramStory']);
    final args = igCalls.last.arguments as Map;
    expect(args['appId'], '1234567890');
    final f = File(args['path'] as String);
    expect(f.path, endsWith('wehum-meditation-9x16.png'));
    final png = f.readAsBytesSync();
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    final w = png.buffer.asByteData().getUint32(16), h = png.buffer.asByteData().getUint32(20);
    expect((w, h), (1080, 1920));
    expect(sheetCalls, isEmpty); // Instagram opened: no share sheet
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('46 no Instagram on the phone: the same image goes to the share sheet instead (never a dead button)', (t) async {
    final e = await openShare(t, instagramInstalled: false);
    await tapAndWait(t, const Key('share-instagram'));
    expect(igCalls.map((c) => c.method), ['instagramAvailable']);
    expect(sheetCalls, isNotEmpty);
    expect(sheetCalls.first.arguments.toString(), contains('wehum-meditation-9x16.png'));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('46 iPhone without a Meta App ID: the share sheet (Instagram → Story there), Instagram is not asked directly', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final e = await openShare(t, instagramInstalled: true, appId: '');
    await tapAndWait(t, const Key('share-instagram'));
    expect(igCalls, isEmpty);
    expect(sheetCalls, isNotEmpty);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('46 Android without a Meta App ID: a share intent goes straight to Instagram (no share sheet)', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final e = await openShare(t, instagramInstalled: true, appId: '');
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('share-instagram')));
      for (var i = 0; i < 30 && igCalls.where((c) => c.method == 'instagramSend').isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    });
    await t.pump();
    expect(igCalls.map((c) => c.method), ['instagramAvailable', 'instagramSend']);
    expect((igCalls.last.arguments as Map)['path'], endsWith('wehum-meditation-9x16.png'));
    expect((igCalls.last.arguments as Map).containsKey('appId'), isFalse);
    expect(sheetCalls, isEmpty);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('45 the Share button is in view on a normal phone without scrolling, with a swipeable preview of the card', (t) async {
    phone(t);
    final tmp = Directory.systemTemp.createTempSync('wehum-share');
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    m.setMockMethodCallHandler(_paths, (c) async => tmp.path);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    final rec = MeditationRecord(id: 'm-2', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 22, 8), endedAt: DateTime.utc(2026, 10, 22, 8, 5), durationSec: 300, completed: true);
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(
        player: const PlayerArgs(kind: 'motd', mode: 'solo', title: 'Steady Under Pressure', sessionId: sid), record: rec, counted: true));
    await settle(t);
    final screen = t.view.physicalSize / t.view.devicePixelRatio;
    final share = t.getRect(find.byKey(const Key('share-sit')));
    expect(share.bottom <= screen.height && share.top >= 0, isTrue, reason: 'Share must be on screen at once');
    expect(find.byKey(const Key('share-preview')), findsOneWidget);
    expect(find.textContaining('Night'), findsOneWidget);
    await t.drag(find.byType(PageView), const Offset(-300, 0));
    await settle(t);
    expect(find.textContaining('Dawn'), findsOneWidget);
    await t.tap(find.byKey(const Key('share-sit')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.shareYourMeditation);
    expect(find.byKey(const Key('style-dawn')), findsOneWidget); // the picked look carries over
    expect(find.byKey(const Key('style-world')), findsNothing); // no shared moment: no World look
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
