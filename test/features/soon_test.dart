import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/bootstrap.dart';
import 'package:meditation/core/data/models/soon.dart';
import 'package:meditation/core/services/config_service.dart';
import 'package:meditation/features/soon/soon_controllers.dart';

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

void setFlags(Map<String, bool> f) => Get.find<ConfigService>().current.value =
    Bootstrap.fromJson({'serverTime': DateTime.now().millisecondsSinceEpoch, 'features': f, 'catalogVersion': 1});

Future<TestEnv> open(WidgetTester t, String route, {Map<String, bool> flags = const {}, bool member = true, bool account = true}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true);
  if (account) e.access.isGuest.value = false;
  setFlags(flags);
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  group('flags', () {
    testWidgets('flag off: every coming-soon screen shows the teaser, no API call needed', (t) async {
      for (final (route, title) in [
        (AppRoutes.challenges, 'Challenges are coming'), (AppRoutes.gratitude, 'The gratitude feed is coming'), (AppRoutes.breathwork, 'Breathwork is coming'), (AppRoutes.milestones, 'Milestones are coming')
      ]) {
        final e = await open(t, route);
        expect(find.text(title), findsOneWidget, reason: route);
        expect(find.text('COMING SOON'), findsOneWidget);
        await t.pumpWidget(const SizedBox());
        await e.dispose();
      }
    });

    testWidgets('flag on but the API answers FEATURE_OFF (flag flipped meanwhile): still the teaser', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      e.soon.off = true;
      setFlags({'challenges': true});
      await t.pumpWidget(e.app(initial: AppRoutes.challenges));
      await settle(t);
      expect(find.text('Challenges are coming'), findsOneWidget);
      await e.dispose();
    });
  });

  testWidgets('69 challenges: in progress with days, available, finished; join and leave; Meditate today goes to Today', (t) async {
    final e = await open(t, AppRoutes.challenges, flags: {'challenges': true});
    expect(find.text('START ANOTHER'), findsOneWidget);
    expect(find.text('7 days of calm'), findsOneWidget);
    expect(find.text('FINISHED'), findsOneWidget);
    await t.tap(find.text('Join').first);
    await settle(t);
    expect(e.soon.joined, contains('c7'));
    expect(find.text('IN PROGRESS'), findsOneWidget);
    expect(find.text('of 7 days'), findsOneWidget);
    expect(find.text('1,904 people in it'), findsOneWidget);
    await t.tap(find.text('Meditate today'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.todayMember);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  group('70 gratitude (live)', () {
    testWidgets('joins gratitude:{kind}; new posts arrive over the socket; removal disappears; switching tab changes the room', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      setFlags({'gratitude': true});
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app(initial: AppRoutes.gratitude));
      await settle(t);
      expect(e.socket.rooms, contains('gratitude:gratitude'));
      expect(find.textContaining('For a quiet morning.'), findsOneWidget);
      e.socketServer.serverPushes('gratitude:new', {'kind': 'gratitude', 'item': {'id': 'g9', 'kind': 'gratitude', 'firstName': 'Kofi', 'country': 'GH', 'text': 'For rain today.', 'createdAt': DateTime.now().toUtc().toIso8601String()}});
      await afterPush(t);
      expect(find.textContaining('For rain today.'), findsOneWidget);
      e.socketServer.serverPushes('gratitude:new', {'kind': 'love', 'item': {'id': 'g10', 'kind': 'love', 'firstName': 'X', 'text': 'other tab', 'createdAt': DateTime.now().toUtc().toIso8601String()}});
      await afterPush(t);
      expect(find.textContaining('other tab'), findsNothing);
      e.socketServer.serverPushes('gratitude:removed', {'kind': 'gratitude', 'id': 'g9'});
      await afterPush(t);
      expect(find.textContaining('For rain today.'), findsNothing);
      await t.tap(find.text('Sending love'));
      await settle(t);
      expect(e.socket.rooms, contains('gratitude:love'));
      expect(e.socket.rooms, isNot(contains('gratitude:gratitude')));
      await t.pumpWidget(const SizedBox());
      Get.delete<GratitudeController>(force: true);
      await e.dispose();
    });

    testWidgets('posting needs membership and an account; a member with an account posts and sees it', (t) async {
      final free = await open(t, AppRoutes.gratitude, flags: {'gratitude': true}, member: false);
      await t.enterText(find.byKey(const Key('grat-field')), 'Thank you');
      await t.tap(find.byKey(const Key('grat-share')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.membershipPaywall);
      await t.pumpWidget(const SizedBox());
      await free.dispose();

      final e = await open(t, AppRoutes.gratitude, flags: {'gratitude': true});
      await t.enterText(find.byKey(const Key('grat-field')), 'Thank you for today');
      await t.tap(find.byKey(const Key('grat-share')));
      await settle(t);
      expect(e.soon.posts.first.text, 'Thank you for today');
      expect(find.text('“Thank you for today”'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('breathwork', () {
    test('BreathSession: phases in order, zero-second holds are skipped, rounds counted, finishes', () {
      final s = BreathSession(const BreathPattern(name: 'x', inhaleSec: 2, hold1Sec: 0, exhaleSec: 3, hold2Sec: 1, rounds: 2))..start();
      final seen = <String>[];
      var ticks = 0;
      while (!s.done && ticks < 100) {
        seen.add('${s.round}:${s.phase.name}:${s.left}');
        s.tick();
        ticks++;
      }
      expect(ticks, 12); // (2 + 3 + 1) × 2 rounds
      expect(seen.first, '1:inhale:2');
      expect(seen.where((x) => x.contains('hold1')), isEmpty);
      expect(seen, contains('2:hold2:1'));
      expect(s.phase, BreathPhase.done);
    });

    test('designer validation mirrors the server rules', () {
      BreathPattern p({int i = 4, int h1 = 4, int e = 4, int h2 = 4, int r = 10}) => BreathPattern(name: 'n', inhaleSec: i, hold1Sec: h1, exhaleSec: e, hold2Sec: h2, rounds: r);
      expect(PatternDesignerController.problem(p()), isNull);
      expect(PatternDesignerController.problem(p(i: 0)), 'Breathe in and out for at least 1 second');
      expect(PatternDesignerController.problem(p(e: 0)), 'Breathe in and out for at least 1 second');
      expect(PatternDesignerController.problem(p(i: 21)), 'Each beat is 0–20 seconds');
      expect(PatternDesignerController.problem(p(i: 20, h1: 20, e: 20, h2: 1)), 'One round is at most 60 seconds');
      expect(PatternDesignerController.problem(p(r: 0)), 'Rounds are 1–100');
      expect(PatternDesignerController.problem(p(r: 101)), 'Rounds are 1–100');
    });

    testWidgets('71/72: templates, designer steppers update the summary and are bounded; saved pattern shows under Your patterns; run screen counts down', (t) async {
      final e = await open(t, AppRoutes.breathwork, flags: {'breathwork': true});
      expect(find.text('Box breathing'), findsOneWidget);
      await t.tap(find.byKey(const Key('designer-card')));
      await settle(t);
      expect(find.text('4-4-4-4'), findsOneWidget);
      await t.tap(find.byTooltip('More Breathe in'));
      await t.pump();
      expect(find.text('5-4-4-4'), findsOneWidget);
      expect(find.text('5-4-4-4 · 10 rounds · 2.8 min'), findsOneWidget);
      final d = Get.find<PatternDesignerController>();
      for (var i = 0; i < 30; i++) {
        d.adjust(d.hold1, 1);
        d.adjust(d.inhale, 1, min: 1);
        d.adjust(d.exhale, 1, min: 1);
      }
      expect([d.inhale.value, d.hold1.value, d.exhale.value], [20, 20, 20]); // each beat is bounded at 20
      await t.pump();
      expect(find.text('One round is at most 60 seconds'), findsOneWidget); // 20+20+20+4 = 64
      d.adjust(d.exhale, -10, min: 1);
      await t.pump();
      expect(find.byKey(const Key('pattern-error')), findsNothing);
      await t.tap(find.byKey(const Key('pattern-start')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.breathRun);
      expect(find.byKey(const Key('breath-phase')), findsOneWidget);
      expect(find.text('Breathe in'), findsOneWidget);
      await t.pump(const Duration(seconds: 21));
      expect(find.text('Hold'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  testWidgets('73 milestones: awards, reached count, the world so far', (t) async {
    final e = await open(t, AppRoutes.milestones, flags: {'milestones': true});
    expect(find.text('YOUR AWARDS · 4 OF 12'), findsOneWidget);
    expect(find.text('First meditation'), findsOneWidget);
    expect(find.text('4/10'), findsOneWidget);
    await t.scrollUntilVisible(find.text('minutes meditated on WeHum'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('2.4M'), findsOneWidget);
    await e.dispose();
  });

  testWidgets('74 intent: only in the setup flow while features.intent is on; choice is stored', (t) async {
    final off = await open(t, AppRoutes.setup1YourName, flags: {});
    await t.enterText(find.byKey(const Key('name-field')), 'Marcus');
    await t.tap(find.text('Continue'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.setup2MeditationReminder);
    await t.pumpWidget(const SizedBox());
    await off.dispose();

    final e = await open(t, AppRoutes.setup1YourName, flags: {'intent': true});
    await t.enterText(find.byKey(const Key('name-field')), 'Marcus');
    await t.tap(find.text('Continue'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.intent);
    expect(find.text('What brings you here?'), findsOneWidget);
    await t.tap(find.byKey(const Key('intent-sleep')));
    await t.pump();
    await t.tap(find.byKey(const Key('intent-next')));
    await settle(t);
    expect(e.prefs.map['intent'], 'sleep');
    expect(Get.currentRoute, AppRoutes.setup2MeditationReminder);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
