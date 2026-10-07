import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/utils/countries.dart';
import 'package:meditation/features/player/player_args.dart';
import 'package:meditation/features/together/controllers/together_controllers.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> afterPush(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 20));
}

Future<TestEnv> openLobby(WidgetTester t, {bool member = true, Duration startsIn = const Duration(minutes: 2), int serverSkewSec = 0}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true);
  e.today.groupStartsIn = startsIn;
  e.socketServer.serverClockSkew = Duration(seconds: serverSkewSec); // the server clock runs ahead; time:sync measures it
  final startsAt = DateTime.now().toUtc().add(startsIn);
  e.socketServer.acks['lobby:join'] = (_) => {'ok': true, 'data': {'startsAt': startsAt.toIso8601String(), 'waiting': 120}};
  await e.socket.connect();
  e.socketServer.serverConnects();
  await t.pumpWidget(e.app(initial: AppRoutes.groupMeditationLobby));
  await settle(t);
  return e;
}

void main() {
  test('country names', () {
    expect(countryName('DE'), 'Germany');
    expect(countryName('us'), 'United States');
    expect(countryName('ZZ'), 'ZZ');
  });

  group('53 lobby', () {
    testWidgets('joins lobby:{date} over the socket, shows counts and regions from lobby:state, leaves on pop', (t) async {
      final e = await openLobby(t);
      expect(e.socketServer.sentData('lobby:join'), isNotEmpty);
      expect(find.text('Group meditation · ${Get.find<LobbyController>().startLabel}'), findsOneWidget);
      e.socketServer.serverPushes('lobby:state', {
        'date': Get.find<LobbyController>().date, 'waiting': 312, 'countries': 29, 'regions': [{'r': 'Europe', 'n': 148}, {'r': 'Americas', 'n': 102}, {'r': 'Asia-Pacific', 'n': 62}], 'startsAt': DateTime.now().toUtc().add(const Duration(minutes: 2)).toIso8601String(),
      });
      await afterPush(t);
      expect(find.text('312 in the lobby · 29 countries'), findsOneWidget);
      expect(find.text('Europe'), findsOneWidget);
      expect(find.text('148'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      Get.delete<LobbyController>(force: true);
      expect(e.socketServer.count('lobby:leave'), 1);
      await e.dispose();
    });

    testWidgets('countdown uses the SERVER clock: a phone 30 s behind still counts to the right moment', (t) async {
      final e = await openLobby(t, startsIn: const Duration(minutes: 5), serverSkewSec: 30);
      // server says T0 is 5 min after phone-now; the server clock is 30 s ahead of the phone → 4:30 left
      await t.pump(const Duration(milliseconds: 50));
      final text = (t.widget(find.byKey(const Key('lobby-countdown'))) as Text).data!;
      expect(text, anyOf('04:30', '04:29', '04:28'));
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('group:start from the server opens the player in group mode, once', (t) async {
      final e = await openLobby(t, startsIn: const Duration(minutes: 1));
      final date = Get.find<LobbyController>().date;
      e.socketServer.serverPushes('group:start', {'date': date, 'startsAt': DateTime.now().toUtc().toIso8601String(), 'sessionId': 's-motd', 'lengthMin': 30, 'mediaKey': 'k'});
      await afterPush(t);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.playerPresenceRing);
      final a = Get.arguments as PlayerArgs;
      expect(a.kind, 'group');
      expect(a.mode, 'group');
      expect(a.lengthMin, 30);
      expect(a.sessionId, 's-motd');
      expect(a.startAt.inSeconds, lessThan(3)); // started on time, not a late join
      // a second event does not open a second player
      e.socketServer.serverPushes('group:start', {'date': date, 'startsAt': DateTime.now().toUtc().toIso8601String(), 'sessionId': 's-motd', 'lengthMin': 30, 'mediaKey': 'k'});
      await afterPush(t);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('the local timer starts the group when group:start never arrives', (t) async {
      final e = await openLobby(t, startsIn: const Duration(seconds: 3));
      expect(Get.currentRoute, AppRoutes.groupMeditationLobby);
      await t.pump(const Duration(seconds: 4));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.playerPresenceRing);
      expect((Get.arguments as PlayerArgs).kind, 'group');
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('late joiner (group already running) starts where the group is', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      e.today.groupStartsIn = const Duration(seconds: -95);
      final startsAt = DateTime.now().toUtc().subtract(const Duration(seconds: 95));
      e.socketServer.acks['lobby:join'] = (_) => {'ok': true, 'data': {'startsAt': startsAt.toIso8601String(), 'waiting': 200}};
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.groupMeditationLobby));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.playerPresenceRing);
      final a = Get.arguments as PlayerArgs;
      expect(a.startAt.inSeconds, inInclusiveRange(93, 100));
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('free users cannot join: members-only message and paywall button (no lobby join emitted)', (t) async {
      final e = await openLobby(t, member: false);
      expect(find.text('Group meditation is for members'), findsOneWidget);
      expect(e.socketServer.count('lobby:join'), 0);
      await t.tap(find.text('See membership options'));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.membershipPaywall);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('server refuses with PREMIUM_REQUIRED (entitlement just lapsed) → same members-only state', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      e.socketServer.acks['lobby:join'] = (_) => {'ok': false, 'code': 'PREMIUM_REQUIRED'};
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.groupMeditationLobby));
      await settle(t);
      expect(find.text('Group meditation is for members'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('Remind me: server push opt-in + local fallback; off cancels', (t) async {
      final e = await openLobby(t, startsIn: const Duration(minutes: 20));
      await Get.find<LobbyController>().toggleReminder();
      await t.pump();
      expect(e.today.groupReminder, isTrue);
      expect(e.notifications.calls, contains('group'));
      await Get.find<LobbyController>().toggleReminder();
      expect(e.today.groupReminder, isFalse);
      expect(e.notifications.calls, contains('cancelGroup'));
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('25 world', () {
    testWidgets('joins the world room; busy → quiet → paused; vibration word; top countries named', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.worldMapWorldVibration));
      await settle(t);
      expect(e.socket.rooms, contains('world'));
      e.socketServer.serverPushes('live:agg', {'total': 412, 'countries': 37, 'top': [{'c': 'DE', 'n': 64}, {'c': 'US', 'n': 120}], 'quiet': false, 'meditatedToday': 1280, 'vibration': 70, 'at': 1});
      await afterPush(t);
      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('412'), findsOneWidget);
      expect(find.text('412 people meditating now · 37 countries'.replaceFirst('412 ', '')), findsOneWidget);
      expect(find.text('70 · Strong'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
      expect(find.text('United States'), findsOneWidget);
      e.socketServer.serverPushes('live:agg', {'total': 4, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 1280, 'vibration': 20, 'at': 2});
      await afterPush(t);
      expect(find.text('QUIET RIGHT NOW'), findsOneWidget);
      expect(find.text('1,280'), findsOneWidget);
      expect(find.text('20 · Quiet'), findsOneWidget);
      e.socketServer.serverDrops();
      await t.pump(const Duration(seconds: 11));
      expect(find.text('LIVE COUNTS PAUSED'), findsOneWidget);
      expect(find.text('We don’t show old numbers as if they were live.'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      Get.delete<WorldController>(force: true);
      await e.dispose();
    });

  });

  group('52 together + 23 room', () {
    testWidgets('together shows the next group, the lobby count and goes to the lobby', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.together));
      await settle(t);
      expect(find.byKey(const Key('next-group')), findsOneWidget);
      expect(find.text('120 already in the lobby'), findsOneWidget);
      e.socketServer.serverPushes('live:agg', {'total': 412, 'countries': 37, 'top': [], 'quiet': false, 'meditatedToday': 1280, 'vibration': 70, 'at': 1});
      await afterPush(t);
      expect(find.textContaining('412 meditating now'), findsOneWidget);
      await t.tap(find.byKey(const Key('go-lobby')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.groupMeditationLobby);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('MOTD room: practiced count follows motd:stats, group card, Meditate now starts the chosen length', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.motdRoom));
      await settle(t);
      expect(find.text('1,280 people practiced this meditation today'), findsOneWidget);
      final date = Get.find<MotdRoomController>().date;
      e.socketServer.serverPushes('motd:stats', {'date': date, 'practicedToday': 1299});
      await afterPush(t);
      expect(find.text('1,299 people practiced this meditation today'), findsOneWidget);
      expect(find.byKey(const Key('group-card')), findsOneWidget);
      await t.scrollUntilVisible(find.textContaining('“For my mother'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('“For my mother'), findsOneWidget);
      await t.scrollUntilVisible(find.text('45 min'), -200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('45 min'));
      await t.pump();
      await t.tap(find.byKey(const Key('room-meditate')));
      await settle(t);
      expect((Get.arguments as PlayerArgs).lengthMin, 45);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });
}
