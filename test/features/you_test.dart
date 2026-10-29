import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/contracts/repositories.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/services/notification_service.dart';
import 'package:meditation/core/theme/theme_controller.dart';
import 'package:meditation/features/you/controllers/you_controllers.dart';

import '../support/test_env.dart';

/// Holds the progress answers until [gate] completes, to see the page while it waits.
class _GatedMe extends MockMeRepository {
  final gate = Completer<void>();
  @override
  Future<ProgressData> progress(Period p) async {
    await gate.future;
    return super.progress(p);
  }
}

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route, {bool member = true, MeProfile? profile, bool account = false}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true, prefs: const {'first_name': 'Marcus'});
  if (profile != null) e.me.profile = profile;
  if (account) e.access.isGuest.value = false;
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

/// Scrolls to Save and taps it once the layout is still (the username chips grow in with an animation).
Future<void> tapSave(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 300));
  await t.scrollUntilVisible(find.byKey(const Key('profile-save')), 200, scrollable: find.byType(Scrollable).first);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(find.byKey(const Key('profile-save')));
}

void main() {
  testWidgets('54 You as a guest: the Save progress card, and no progress or metrics at all', (t) async {
    final e = await open(t, AppRoutes.you);
    expect(find.byKey(const Key('guest-card')), findsOneWidget); // the mock profile is a guest
    expect(find.byKey(const Key('guest-progress-note')), findsOneWidget);
    for (final k in ['streak-block', 'week-chart', 'week-minutes', 'hr-shift', 'r-milestones']) {
      expect(find.byKey(Key(k)), findsNothing, reason: k);
    }
    expect(find.text('CURRENT'), findsNothing);
    expect(find.text('WEEKLY CADENCE (MINUTES)'), findsNothing);
    expect(find.text('Lifetime volume & practice depth'), findsNothing);
    await t.scrollUntilVisible(find.byKey(const Key('r-help')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('sign-out')), findsNothing); // nothing to sign out of
    expect(Get.find<YouController>().week.value, isNull); // not even asked for
    expect(Get.find<YouController>().lifetime.value, isNull);
    Get.toNamed(AppRoutes.yourProgress); // a link to the progress page
    await settle(t);
    expect(find.byKey(const Key('account-only')), findsOneWidget);
    Get.offAllNamed(AppRoutes.milestones);
    await settle(t);
    expect(find.byKey(const Key('account-only')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('54 You loading: placeholders where the streak and week cards go, nothing jumps when they arrive, and a revisit shows the last data at once', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true, prefs: const {'first_name': 'Marcus'});
    final me = _GatedMe()..profile = const MeProfile(id: 'u-loading', firstName: 'Marcus', isGuest: false);
    Get.replace<MeRepository>(me);
    e.access.isGuest.value = false;
    await t.pumpWidget(e.app(initial: AppRoutes.you));
    await settle(t); // entrance animations done, progress still on its way
    // before the progress answer: placeholders, and no week chart sitting where the streak block will be
    expect(find.byKey(const Key('you-loading')), findsOneWidget);
    expect(find.byKey(const Key('week-chart')), findsNothing);
    expect(find.text('Practice ritual & forgiving streaks'), findsOneWidget);
    final placeholderTop = t.getTopLeft(find.byKey(const Key('you-loading'))).dy;
    me.gate.complete();
    await settle(t);
    expect(find.byKey(const Key('you-loading')), findsNothing);
    expect(t.getTopLeft(find.byKey(const Key('streak-block'))).dy, placeholderTop); // the streak block lands where its placeholder was
    expect(t.getTopLeft(find.byKey(const Key('week-chart'))).dy, greaterThan(t.getTopLeft(find.byKey(const Key('streak-block'))).dy));

    Get.offAllNamed(AppRoutes.library); // the bottom nav rebuilds the page and its controller
    await settle(t);
    Get.offAllNamed(AppRoutes.you);
    await t.pump();
    expect(find.byKey(const Key('you-loading')), findsNothing); // last answers shown straight away
    expect(find.byKey(const Key('streak-block')), findsOneWidget);
    await settle(t);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('54 You: name, plan, stats, rows with COMING SOON badges (an account)', (t) async {
    final e = await open(t, AppRoutes.you, account: true, profile: const MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', isGuest: false));
    expect(find.byKey(const Key('you-name')), findsOneWidget);
    expect(find.text('Marcus'), findsWidgets);
    expect(find.byKey(const Key('guest-card')), findsNothing);
    expect(find.byKey(const Key('streak-block')), findsOneWidget);
    expect(find.text('CURRENT'), findsOneWidget);
    expect(find.text('WEEKLY CADENCE (MINUTES)'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('hr-shift')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('64'), findsOneWidget); // lifetime sits
    expect(find.text('-14 bpm'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('r-breath')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('COMING SOON'), findsAtLeastNWidgets(2));
    await t.ensureVisible(find.byKey(const Key('r-reminders')));
    await t.drag(find.byType(ListView).first, const Offset(0, 200)); // content down: the row clear of the top edge
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

  testWidgets('The top-right button is Settings (not the profile): it opens the settings list directly, with Sign out', (t) async {
    final e = await open(t, AppRoutes.you, profile: const MeProfile(id: 'u', firstName: 'Lena', isGuest: false, entitlement: Entitlement(active: true)));
    expect(find.bySemanticsLabel('Profile'), findsNothing);
    await t.tap(find.byKey(const Key('open-settings')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.settings);
    expect(find.text('Settings'), findsWidgets);
    expect(find.byKey(const Key('r-reminders')), findsOneWidget);
    expect(find.byKey(const Key('r-privacy')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('sign-out')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('sign-out')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('54 Sign out asks first, then signs out on the server, drops the push token and returns to the start', (t) async {
    final e = await open(t, AppRoutes.you, profile: const MeProfile(id: 'u', firstName: 'Lena', isGuest: false, entitlement: Entitlement(active: true)));
    await t.scrollUntilVisible(find.byKey(const Key('sign-out')), 300, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300)); // clear of the bottom nav
    await t.pump();
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

  testWidgets('54 Sign out still finishes when the new guest session cannot be created: the button stops loading and the app goes back to the start', (t) async {
    final e = await open(t, AppRoutes.you, profile: const MeProfile(id: 'u', firstName: 'Lena', isGuest: false, entitlement: Entitlement(active: true)));
    e.authRepo.guestError = ApiException(ErrorCode.authRequired, status: 401); // e.g. attestation refused / offline right after the logout
    final you = Get.find<YouController>(); // the start screen replaces the page (and the controller) afterwards
    await t.scrollUntilVisible(find.byKey(const Key('sign-out')), 300, scrollable: find.byType(Scrollable).first);
    await t.drag(find.byType(Scrollable).first, const Offset(0, -300)); // clear of the bottom nav
    await t.pump();
    await t.tap(find.byKey(const Key('sign-out')));
    await settle(t);
    await t.tap(find.byKey(const Key('confirm-sign-out')));
    await settle(t);
    expect(e.authRepo.calls, contains('logout'));
    expect(you.signingOut.value, false);
    expect(Get.currentRoute, AppRoutes.splash);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('55 progress: week dots, tabs switch period, data cached for offline', (t) async {
    final e = await open(t, AppRoutes.yourProgress, account: true, profile: const MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', isGuest: false));
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

  testWidgets('56 edit profile is for accounts only: a guest sees no Edit link and the screen asks for an account', (t) async {
    final e = await open(t, AppRoutes.you);
    expect(find.byKey(const Key('guest-card')), findsOneWidget);
    expect(find.byKey(const Key('you-edit')), findsNothing);
    Get.toNamed(AppRoutes.editProfile); // a deep link or a stale route
    await settle(t);
    expect(find.byKey(const Key('account-only')), findsOneWidget);
    expect(find.byKey(const Key('profile-save')), findsNothing);
    expect(find.byKey(const Key('profile-photo')), findsNothing);
    e.access.isGuest.value = false; // signed up meanwhile: the screen opens by itself
    await settle(t);
    expect(find.byKey(const Key('profile-save')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('54 → 56 → 54: back from Edit profile, the You tab shows the new name at once', (t) async {
    final e = await open(t, AppRoutes.you, account: true, profile: const MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', isGuest: false));
    await t.tap(find.byKey(const Key('you-edit')));
    await settle(t);
    await t.enterText(find.byKey(const Key('profile-first')), 'Aurelia');
    await tapSave(t);
    await settle(t);
    Get.back<void>();
    await settle(t);
    expect(Get.currentRoute, AppRoutes.you);
    expect(find.text('Aurelia'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('56 edit profile: an account without a username sees suggestions, no green tick, and must pick one', (t) async {
    final e = await open(t, AppRoutes.editProfile, account: true, profile: const MeProfile(id: 'u1', firstName: 'Marcus', email: 'm@example.com', isGuest: false));
    expect(find.byKey(const Key('username-ok')), findsNothing);
    expect(find.textContaining('Please enter'), findsNothing); // no field errors before Save
    expect(find.byWidgetPredicate((w) => w is ActionChip), findsWidgets);
    await tapSave(t);
    await settle(t);
    expect(find.byKey(const Key('profile-error')), findsOneWidget);
    expect(find.textContaining('Pick a username'), findsOneWidget);
    expect(e.me.profile.username, isNull);
    await t.dragUntilVisible(find.byWidgetPredicate((w) => w is ActionChip).first, find.byType(Scrollable).first, const Offset(0, 200));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byWidgetPredicate((w) => w is ActionChip).first);
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    expect(find.byKey(const Key('username-ok')), findsOneWidget);
    await tapSave(t);
    await settle(t);
    expect(e.me.profile.username, isNotNull);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('56 edit profile: photos of any size or format are sent as JPEG/PNG under the server limit', (t) async {
    await t.runAsync(() async {
      final small = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0, ...List.filled(5000, 1)]);
      expect((await EditProfileController.fitPhoto(small)).$2, 'image/jpeg'); // already fine: sent as is
      // a noisy 900×900 PNG (several MB) is redrawn smaller until it fits
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      final rnd = math.Random(1);
      for (var i = 0; i < 9000; i++) {
        canvas.drawRect(ui.Rect.fromLTWH(rnd.nextDouble() * 900, rnd.nextDouble() * 900, 9, 9), ui.Paint()..color = ui.Color(0xff000000 | rnd.nextInt(0xffffff)));
      }
      final img = await rec.endRecording().toImage(900, 900);
      final big = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      final (bytes, type) = await EditProfileController.fitPhoto(big);
      expect(type, 'image/png');
      expect(bytes.length, lessThanOrEqualTo(EditProfileController.maxPhotoBytes));
    });
  });

  testWidgets('56 edit profile: validation, save to the server, theme applied at once', (t) async {
    final e = await open(t, AppRoutes.editProfile, account: true, profile: const MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', isGuest: false));
    await t.enterText(find.byKey(const Key('profile-first')), '  ');
    await tapSave(t);
    await t.pump();
    expect(find.text('Please enter your first name'), findsOneWidget);
    await t.enterText(find.byKey(const Key('profile-first')), 'Anne-Marie');
    await tapSave(t);
    await settle(t);
    expect(e.me.profile.firstName, 'Anne-Marie');
    await t.tap(find.text('Light'));
    await settle(t);
    expect(e.me.profile.theme, 'light');
    expect(Get.find<ThemeController>().mode.value, ThemeMode.light);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('56 edit profile: last name, username once per 7 days, the e-mail is shown but locked, photo sheet', (t) async {
    final e = await open(t, AppRoutes.editProfile, profile: MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', email: 'm@example.com', isGuest: false, providers: const ['google'], usernameNextChangeAt: DateTime.now().add(const Duration(days: 3))), account: true);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    expect(find.text('m@example.com'), findsOneWidget);
    expect(find.textContaining('You can change your username again on'), findsOneWidget);
    expect((t.widget(find.byKey(const Key('profile-username'))) as TextFormField).enabled, isFalse);
    await t.enterText(find.byKey(const Key('profile-last')), 'Aurelius');
    await tapSave(t);
    await settle(t);
    expect(e.me.profile.lastName, 'Aurelius');
    expect(e.me.profile.username, 'marcus.sits'); // locked: unchanged
    await t.tap(find.byKey(const Key('profile-photo')));
    await settle(t);
    expect(find.text('Choose from library'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('56 edit profile: a free username can be changed; a taken one is refused', (t) async {
    final e = await open(t, AppRoutes.editProfile, profile: const MeProfile(id: 'u1', firstName: 'Marcus', username: 'marcus.sits', isGuest: false), account: true);
    expect(find.byWidgetPredicate((w) => w is ActionChip), findsNothing); // a saved username: no suggestion chips until it is edited
    final f = find.byKey(const Key('profile-username'));
    await t.enterText(f, 'raphael');
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    expect(find.text('That username is taken'), findsOneWidget);
    await tapSave(t);
    await settle(t);
    expect(e.me.profile.username, 'marcus.sits');
    await t.enterText(f, 'marcus_calm');
    await t.pump(const Duration(milliseconds: 600));
    await t.pump();
    await tapSave(t);
    await settle(t);
    expect(e.me.profile.username, 'marcus_calm');
    expect(e.me.profile.usernameNextChangeAt, isNotNull);
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
    await t.scrollUntilVisible(find.byKey(const Key('sw-presence')), 200, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.byKey(const Key('sw-presence')));
    await t.pump();
    await t.tap(find.byKey(const Key('sw-presence')));
    await settle(t);
    expect(e.me.profile.showCountry, false);
    await t.runAsync(() => Get.find<PrivacyController>().exportData());
    await settle(t);
    expect(Get.find<PrivacyController>().exportState.value, 'done');
    await t.scrollUntilVisible(find.byKey(const Key('export')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Your archive is ready'), findsOneWidget);
    expect(Get.find<PrivacyController>().exportUrl.value, 'https://example.com/e.zip');
    await t.scrollUntilVisible(find.byKey(const Key('anonymize')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Anonymise'));
    await settle(t);
    expect(e.community.anonymized, 1);
    expect(find.text('1 post anonymised'), findsOneWidget);

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
    expect(find.text('Transcendence & Connection'), findsOneWidget);
    await e.dispose();
  });
}
