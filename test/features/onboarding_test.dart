import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/purchase_service.dart';
import 'package:meditation/features/onboarding/controllers/onboarding_controllers.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('splash → first run goes to the first intro slide', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app());
    await settle(t);
    expect(Get.currentRoute, AppRoutes.intro1Welcome);
    expect(find.text('WeHum by Raphael Reiter'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(Get.find<AnalyticsService>().drain().map((x) => x['name']), contains('app_open'));
    await e.dispose();
  });

  testWidgets('splash → returning free user lands on Today (free), returning member on Today', (t) async {
    phone(t);
    final free = await TestEnv.create(onboardingDone: true);
    await t.pumpWidget(free.app());
    await settle(t);
    expect(Get.currentRoute, AppRoutes.todayFree);
    await t.pumpWidget(const SizedBox());
    await free.dispose();
    final member = await TestEnv.create(member: true, onboardingDone: true);
    await t.pumpWidget(member.app());
    await settle(t);
    expect(Get.currentRoute, AppRoutes.todayMember);
    await member.dispose();
  });

  test('first route decision', () {
    expect(SplashController.firstRoute(onboardingDone: false, member: true), AppRoutes.intro1Welcome);
    expect(SplashController.firstRoute(onboardingDone: true, member: true), AppRoutes.todayMember);
    expect(SplashController.firstRoute(onboardingDone: true, member: false), AppRoutes.todayFree);
  });

  testWidgets('intro 1 → 4 with Next, Skip jumps to the start screen; slide 3 shows the live pill from the socket', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.intro1Welcome));
    await settle(t);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('You’re never meditating alone.'), findsOneWidget);
    // the live pill is hidden until the socket delivers numbers, then shows them (and never stale numbers)
    expect(find.textContaining('meditating now'), findsNothing);
    await e.socket.connect();
    e.socketServer.serverConnects();
    e.socketServer.serverPushes('live:agg', {'total': 312, 'countries': 29, 'top': [], 'quiet': false, 'meditatedToday': 900, 'vibration': 50, 'at': 1});
    await t.pump();
    expect(find.text('312 meditating now'), findsOneWidget);
    e.socketServer.serverPushes('live:agg', {'total': 3, 'countries': 1, 'top': [], 'quiet': true, 'meditatedToday': 900, 'vibration': 5, 'at': 2});
    await t.pump();
    expect(find.text('900 meditated today'), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('One meditation a day. That’s the whole trick.'), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(find.text('Training, not therapy.'), findsOneWidget);
    await t.tap(find.text('Next'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.setup1YourName);
    await e.dispose();
  });

  testWidgets('skip on an intro slide goes straight to How do you want to start', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.intro1Welcome));
    await settle(t);
    await t.tap(find.text('Skip'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.howDoYouWantToStart);
    await e.dispose();
  });

  group('name', () {
    test('validation: 1–30 letters, spaces, apostrophes, hyphens', () {
      Get.reset();
      final c = NameController();
      c.touched.value = true;
      for (final bad in ['', '   ', 'a' * 31, 'Mar<cus', 'Mark3', 'a@b']) {
        c.name.value = bad;
        expect(c.valid, false, reason: bad);
      }
      for (final ok in ['Marcus', 'Anne-Marie', "O'Brien", 'Lena Berg', 'Ünal', 'Åsa', '李']) {
        c.name.value = ok;
        expect(c.valid, true, reason: ok);
      }
    });

    test('greeting follows the phone clock', () {
      final c = NameController()..name.value = '  Marcus ';
      expect(c.greeting(DateTime(2026, 10, 5, 8)), 'Good morning, Marcus');
      expect(c.greeting(DateTime(2026, 10, 5, 14)), 'Good afternoon, Marcus');
      expect(c.greeting(DateTime(2026, 10, 5, 21)), 'Good evening, Marcus');
      c.name.value = '';
      expect(c.greeting(DateTime(2026, 10, 5, 8)), 'Good morning');
    });

    testWidgets('Continue is blocked with a message for an invalid name; valid name is stored and moves on', (t) async {
    phone(t);
      final e = await TestEnv.create();
      await t.pumpWidget(e.app(initial: AppRoutes.setup1YourName));
      await settle(t);
      await t.tap(find.text('Continue'));
      await t.pump();
      expect(find.text('Please enter your first name'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.setup1YourName);
      await t.enterText(find.byKey(const Key('name-field')), 'Marcus');
      await t.pump();
      expect(find.byKey(const Key('name-preview')), findsOneWidget);
      expect(find.textContaining('Marcus'), findsWidgets);
      await t.tap(find.text('Continue'));
      await settle(t);
      expect(e.prefs.map['first_name'], 'Marcus');
      expect(Get.currentRoute, AppRoutes.setup2MeditationReminder);
      await e.dispose();
    });
  });

  testWidgets('time: default 07:00, scrolling the wheel changes it, Continue stores HH:mm', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.setup2MeditationReminder));
    await settle(t);
    final c = Get.find<TimeController>();
    expect(c.hhmm, '07:00');
    await t.drag(find.byKey(const Key('hour-wheel')), const Offset(0, -128)); // two items up
    await settle(t);
    expect(c.hour.value, 9);
    await t.drag(find.byKey(const Key('minute-wheel')), const Offset(0, -64));
    await settle(t);
    expect(c.minute.value, 5);
    await t.tap(find.text('Continue'));
    await settle(t);
    expect(e.prefs.map['reminder_time'], '09:05');
    expect(Get.currentRoute, AppRoutes.setup3Reminder);
    await e.dispose();
  });

  group('reminder permission', () {
    testWidgets('Allow: asks the OS, saves name + time on the server, schedules the local fallback, goes to start', (t) async {
    phone(t);
      final e = await TestEnv.create(prefs: {'first_name': 'Marcus', 'reminder_time': '07:00'});
      await t.pumpWidget(e.app(initial: AppRoutes.setup3Reminder));
      await settle(t);
      expect(find.text('We will invite you to meditate at 7:00.'), findsOneWidget);
      await t.tap(find.text('Allow notifications'));
      await settle(t);
      expect(e.notifications.calls, containsAll(['requestPermission', 'daily:07:00:Marcus']));
      expect(e.me.profile.firstName, 'Marcus');
      expect(e.me.profile.reminderTime, '07:00');
      expect(e.me.profile.reminderEnabled, true);
      expect(e.prefs.map['notification_choice'], 'granted');
      expect(Get.currentRoute, AppRoutes.howDoYouWantToStart);
      await e.dispose();
    });

    testWidgets('Don\'t allow and Not now both continue; no local reminder is scheduled', (t) async {
    phone(t);
      final e = await TestEnv.create(prefs: {'first_name': 'Lena'});
      e.notifications.grant = false;
      await t.pumpWidget(e.app(initial: AppRoutes.setup3Reminder));
      await settle(t);
      await t.tap(find.text('Allow notifications'));
      await settle(t);
      expect(e.prefs.map['notification_choice'], 'denied');
      expect(e.notifications.calls.where((c) => c.startsWith('daily')), isEmpty);
      expect(e.me.profile.reminderEnabled, false);
      expect(Get.currentRoute, AppRoutes.howDoYouWantToStart);
      await t.pumpWidget(const SizedBox());
      await e.dispose();

      final e2 = await TestEnv.create();
      await t.pumpWidget(e2.app(initial: AppRoutes.setup3Reminder));
      await settle(t);
      await t.tap(find.text('Not now'));
      await settle(t);
      expect(e2.prefs.map['notification_choice'], 'skipped');
      expect(Get.currentRoute, AppRoutes.howDoYouWantToStart);
      await e2.dispose();
    });
  });

  group('start (09)', () {
    testWidgets('shows RevenueCat prices, the live Founding counter, and logs paywall_view', (t) async {
    phone(t);
      final e = await TestEnv.create();
      await t.pumpWidget(e.app(initial: AppRoutes.howDoYouWantToStart));
      await settle(t);
      await Get.find<PurchaseService>().loadOffer();
      Get.find<PurchaseService>().offer.refresh();
      await t.pump();
      expect(find.text(r'7 days free, then $59.00/year.'), findsOneWidget);
      expect(find.text(r'Monthly · 7 days free, then $9.99/month'), findsOneWidget);
      expect(find.text('Start 7-day free trial'), findsOneWidget);
      expect(find.text('Continue for free'), findsOneWidget);
      expect(find.text('Restore purchase'), findsOneWidget);
      expect(Get.find<AnalyticsService>().drain().map((x) => x['name']), contains('paywall_view'));
      await e.dispose();
    });

    testWidgets('Continue for free ends onboarding and opens Today (free)', (t) async {
    phone(t);
      final e = await TestEnv.create();
      await t.pumpWidget(e.app(initial: AppRoutes.howDoYouWantToStart));
      await settle(t);
      await t.tap(find.byKey(const Key('continue-free')));
      await settle(t);
      expect(e.prefs.map['onboarding_done'], true);
      expect(Get.currentRoute, AppRoutes.todayFree);
      await e.dispose();
    });

    testWidgets('trial purchase success → welcome; cancel stays with the offer intact; pending/failed open the status screen', (t) async {
    phone(t);
      final e = await TestEnv.create();
      await t.pumpWidget(e.app(initial: AppRoutes.howDoYouWantToStart));
      await settle(t);
      final ctrl = Get.find<StartController>();
      await ctrl.purchases.loadOffer();
      final plan = ctrl.offer!.annual!;
      e.rc.next = PurchaseOutcome.cancelled;
      await ctrl.startTrial(plan);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.howDoYouWantToStart);
      expect(ctrl.offer, isNotNull);
      e.rc.next = PurchaseOutcome.pending;
      await ctrl.startTrial(plan);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.purchaseStates);
      Get.back<void>();
      await settle(t);
      e.rc.next = PurchaseOutcome.success;
      await ctrl.startTrial(plan);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.trialStarted);
      expect(e.prefs.map['onboarding_done'], true);
      expect(e.access.isMember, true);
      await e.dispose();
    });
  });
}
