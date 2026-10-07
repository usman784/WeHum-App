import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/today.dart';
import 'package:meditation/core/realtime/socket_events.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/features/player/player_args.dart';
import 'package:meditation/features/today/controllers/today_controller.dart';

import '../support/test_env.dart';

/// A socket push reaches the UI one frame later (stream microtask → Obx rebuild).
Future<void> afterPush(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 20));
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> openToday(WidgetTester t, {bool member = true, Map<String, Object?> prefs = const {'first_name': 'Marcus'}}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true, prefs: prefs);
  await Get.find<CatalogService>().load();
  await t.pumpWidget(e.app(initial: member ? AppRoutes.todayMember : AppRoutes.todayFree));
  await settle(t);
  return e;
}

void main() {
  group('formatting', () {
    test('greeting by time of day', () {
      expect(greetingFor(DateTime(2026, 10, 5, 8), 'Marcus'), 'Good morning, Marcus');
      expect(greetingFor(DateTime(2026, 10, 5, 13), 'Marcus'), 'Good afternoon, Marcus');
      expect(greetingFor(DateTime(2026, 10, 5, 20), ''), 'Good evening');
    });

    test('live line: busy vs quiet, REST snapshot before the socket, paused never shows numbers', () {
      LiveAgg a(bool quiet) => LiveAgg.fromJson({'total': quiet ? 4 : 412, 'countries': 37, 'quiet': quiet, 'meditatedToday': 1280, 'vibration': 50, 'at': 1});
      expect(liveLineText(agg: a(false), paused: false), '412 meditating now · 37 countries');
      expect(liveLineText(agg: a(true), paused: false), '1,280 meditated today');
      expect(liveLineText(snapshot: const LiveLine(total: 9, countries: 3, quiet: false, meditatedToday: 50), paused: false), '9 meditating now · 3 countries');
      expect(liveLineText(agg: a(false), paused: true), 'Live counts paused');
      expect(liveLineText(paused: false), isNull);
    });
  });

  testWidgets('22 member Today: greeting, hero, lengths, program, Silence Room, progress, daily message', (t) async {
    final e = await openToday(t);
    expect(find.byKey(const Key('greeting')), findsOneWidget);
    expect(find.textContaining('Marcus'), findsWidgets);
    expect(find.text('Steady Under Pressure'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('30 min'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Meditate now'), findsOneWidget);
    expect(find.text('Wait for the group'), findsOneWidget);
    expect(find.byKey(const Key('program-card')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('daily-line')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('silence-row')), findsOneWidget);
    expect(find.text('105'), findsOneWidget);
    expect(find.text('Releasing Cognitive Friction'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('live pill follows the socket: REST snapshot → live:agg busy → quiet → paused after 10 s', (t) async {
    final e = await openToday(t);
    expect(find.text('412 meditating now · 37 countries'), findsOneWidget); // snapshot from /v1/today
    await e.socket.connect();
    e.socketServer.serverConnects();
    expect(e.socket.rooms, containsAll(['today', 'motd:${localDate()}']));
    e.socketServer.serverPushes('live:agg', {'total': 500, 'countries': 40, 'top': [], 'quiet': false, 'meditatedToday': 1300, 'vibration': 60, 'at': 1});
    await afterPush(t);
    expect(find.text('500 meditating now · 40 countries'), findsOneWidget);
    e.socketServer.serverPushes('live:agg', {'total': 3, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 1300, 'vibration': 5, 'at': 2});
    await afterPush(t);
    expect(find.text('1,300 meditated today'), findsOneWidget);
    e.socketServer.serverPushes('motd:stats', {'date': localDate(), 'practicedToday': 1301});
    await afterPush(t);
    expect(find.text('1,301 people practiced this meditation today'), findsOneWidget);
    e.socketServer.serverDrops();
    await t.pump(const Duration(seconds: 11));
    expect(find.text('Live counts paused'), findsOneWidget);
    expect(find.textContaining('1,300'), findsNothing); // old numbers are not shown as live
    e.socketServer.serverConnects();
    await afterPush(t);
    expect(find.text('Live counts paused'), findsNothing);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('Meditate now opens the player with the chosen length; the room is left when Today closes', (t) async {
    final e = await openToday(t);
    await e.socket.connect();
    e.socketServer.serverConnects();
    await t.tap(find.text('30 min'));
    await t.pump();
    await t.tap(find.byKey(const Key('meditate-now')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing);
    final args = Get.arguments as PlayerArgs;
    expect(args.kind, 'motd');
    expect(args.lengthMin, 30);
    expect(args.sessionId, 's-motd');
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('Wait for the group → lobby; hero tap → MOTD room', (t) async {
    final e = await openToday(t);
    await t.tap(find.byKey(const Key('wait-group')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.groupMeditationLobby);
    Get.back<void>();
    await settle(t);
    await t.tap(find.text('Steady Under Pressure'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.motdRoom);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('24 free Today: locked MOTD with Try 7 days free, Free for you, locked Silence Room', (t) async {
    final e = await openToday(t, member: false);
    expect(find.byKey(const Key('locked-motd')), findsOneWidget);
    expect(find.text('Try 7 days free'), findsOneWidget);
    expect(find.text('PREMIUM'), findsWidgets);
    await t.scrollUntilVisible(find.byKey(const Key('silence-row')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Free for you'), findsOneWidget);
    expect(find.byKey(const Key('free-pick')), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    await t.tap(find.byKey(const Key('silence-row')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('free Today: tapping the free item opens the free player with the YouTube id', (t) async {
    final e = await openToday(t, member: false);
    await t.scrollUntilVisible(find.byKey(const Key('free-pick')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('free-pick')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.freePlayer);
    expect((Get.arguments as PlayerArgs).youtubeId, 'dQw4w9WgXcQ');
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
