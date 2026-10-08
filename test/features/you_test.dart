import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/notification_service.dart';
import 'package:meditation/core/theme/theme_controller.dart';
import 'package:meditation/features/you/controllers/you_controllers.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route, {bool member = true, MeProfile? profile}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true, prefs: const {'first_name': 'Marcus'});
  if (profile != null) e.me.profile = profile;
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  testWidgets('54 You: name, plan, stats, rows with COMING SOON badges; guests get the Save progress card', (t) async {
    final e = await open(t, AppRoutes.you);
    expect(find.byKey(const Key('you-name')), findsOneWidget);
    expect(find.text('Marcus'), findsWidgets);
    expect(find.text('days this week'), findsOneWidget);
    expect(find.text('COMING SOON'), findsNWidgets(3));
    expect(find.byKey(const Key('guest-card')), findsOneWidget); // the mock profile is a guest
    await t.drag(find.byType(ListView).first, const Offset(0, -500)); // clear of the bottom bar
    await t.pump();
    await t.tap(find.byKey(const Key('r-reminders')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.reminders);
    await t.pumpWidget(const SizedBox());
    await e.dispose();

    final acct = await open(t, AppRoutes.you, profile: const MeProfile(id: 'u', firstName: 'Lena', isGuest: false, entitlement: Entitlement(active: true)));
    expect(find.byKey(const Key('guest-card')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await acct.dispose();
  });

  testWidgets('54 Sign out asks first, then signs out on the server, drops the push token and returns to the start', (t) async {
    final e = await open(t, AppRoutes.you, profile: const MeProfile(id: 'u', firstName: 'Lena', isGuest: false, entitlement: Entitlement(active: true)));
    await t.scrollUntilVisible(find.byKey(const Key('sign-out')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('sign-out')));
    await settle(t);
    expect(find.text('Your downloads stay on this phone. You can log in again any time.'), findsOneWidget);
    await t.tap(find.byKey(const Key('confirm-sign-out')));
    await settle(t);
    expect(e.authRepo.calls, contains('logout'));
    expect(e.notifications.calls, contains('signedOut'));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('55 progress: week dots, tabs switch period, data cached for offline', (t) async {
    final e = await open(t, AppRoutes.yourProgress);
    expect(find.byKey(const Key('days-big')), findsOneWidget);
    expect(find.text('4'), findsWidgets);
    expect(find.text('MINUTES'), findsOneWidget);
    await t.tap(find.text('Month'));
    await settle(t);
    expect(Get.find<ProgressController>().period.value, Period.month);
    await t.runAsync(() async => expect(await e.db.getCache('progress:month'), isNotNull));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('56 edit profile: validation, save to the server, theme applied at once', (t) async {
    final e = await open(t, AppRoutes.editProfile);
    await t.enterText(find.byKey(const Key('profile-first')), '  ');
    await t.tap(find.byKey(const Key('profile-save')));
    await t.pump();
    expect(find.text('Please enter your first name'), findsOneWidget);
    await t.enterText(find.byKey(const Key('profile-first')), 'Anne-Marie');
    await t.tap(find.byKey(const Key('profile-save')));
    await settle(t);
    expect(e.me.profile.firstName, 'Anne-Marie');
    await t.tap(find.text('Light'));
    await settle(t);
    expect(e.me.profile.theme, 'light');
    expect(Get.find<ThemeController>().mode.value, ThemeMode.light);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('57 reminders: toggles are saved to the server; time sheet; notifications-off banner; wifi-only pref', (t) async {
    final e = await open(t, AppRoutes.reminders);
    await t.tap(find.byKey(const Key('sw-group')));
    await settle(t);
    expect(e.me.profile.groupWarning, true);
    await t.tap(find.byKey(const Key('sw-daily')));
    await settle(t);
    expect(e.me.profile.reminderEnabled, false);
    expect(e.notifications.calls, contains('cancelDaily'));
    await t.tap(find.byKey(const Key('sw-daily')));
    await settle(t);
    expect(e.notifications.calls.any((c) => c.startsWith('daily:')), true);
    await t.tap(find.byKey(const Key('sw-wifi')));
    await settle(t);
    expect(e.prefs.map['wifi_only'], false);
    expect(find.byKey(const Key('notif-off')), findsNothing);
    e.notifications.permission.value = PushPermission.denied;
    await t.pump();
    expect(find.byKey(const Key('notif-off')), findsOneWidget);
    expect(find.text('Notifications are off.'), findsOneWidget);
    await t.tap(find.text('See what the notifications look like'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.pushPreview);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('59 privacy: presence toggle, data export, delete needs confirmation and wipes this phone', (t) async {
    final e = await open(t, AppRoutes.privacyData);
    await t.tap(find.byKey(const Key('sw-presence')));
    await settle(t);
    expect(e.me.profile.showCountry, false);
    await t.runAsync(() => Get.find<PrivacyController>().exportData());
    await settle(t);
    expect(Get.find<PrivacyController>().exportState.value, 'done');
    expect(find.text('Your data is ready'), findsOneWidget);

    await t.scrollUntilVisible(find.byKey(const Key('delete')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('delete')));
    await settle(t);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining(RegExp('does not cancel your (App Store|Google Play) subscription')), findsOneWidget);
    await t.tap(find.text('Keep my account'));
    await settle(t);
    expect(e.me.deleted, false);
    final before = Map.of(e.prefs.map);
    expect(before['first_name'], 'Marcus');
    final ok = await t.runAsync(() => Get.find<PrivacyController>().deleteAccount());
    expect(ok, true);
    expect(e.me.deleted, true);
    // local choices wiped: nothing of the deleted person is left (name, reminder, theme, onboarding state).
    // The only thing that may be written afterwards is which fresh guest the (now empty) name belongs to.
    expect(e.prefs.map.keys.toSet().difference({'first_name_owner'}), isEmpty);
    expect(e.prefs.map['first_name'], isNull);
    expect(e.prefs.map['first_name_owner'], isNot(before['first_name_owner']));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('60 help: rows and version line', (t) async {
    final e = await open(t, AppRoutes.helpAbout);
    for (final s in ['Watch the intro again', 'Restore purchase', 'Questions & answers', 'Contact support', 'Terms of use', 'Privacy policy']) {
      expect(find.text(s), findsOneWidget);
    }
    expect(find.text('Meditation training, not therapy.'), findsOneWidget);
    await e.dispose();
  });
}
