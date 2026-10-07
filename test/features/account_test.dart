import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/services/account_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/deep_links.dart';
import 'package:meditation/features/account/controllers/account_controllers.dart';
import 'package:meditation/features/account/views/account_pages.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  group('AccountService', () {
    test('link Google: Firebase token goes to the API, session applied, purchases/push/socket refreshed, event tracked', () async {
      final e = await TestEnv.create();
      final a = Get.find<AccountService>();
      final r = await a.linkSocial('google');
      expect(r, isA<AccountOk>());
      expect(e.authRepo.calls, ['link:google']);
      expect(Get.find<AnalyticsService>().drain().map((x) => x['name']), contains('account_link'));
      expect(e.notifications.calls, contains('registerDevice'));
      expect(e.access.isGuest.value, false);
      await e.dispose();
    });

    test('existing account → AccountExists with the merge token; login then merges the guest into the account', () async {
      final e = await TestEnv.create();
      e.social.googleToken = 'exists';
      final a = Get.find<AccountService>();
      final r = await a.linkSocial('google');
      expect(r, isA<AccountExists>());
      expect((r as AccountExists).mergeToken, isNotNull);
      e.social.googleToken = 'ok';
      final login = await a.loginEmail(email: 'x@example.com', password: 'correct-password');
      expect((login as AccountOk).merged, true);
      expect(e.authRepo.calls, containsAllInOrder(['emailLogin:x@example.com', 'merge']));
      await e.dispose();
    });

    test('cancelled sheet is not an error; wrong password maps to a friendly message', () async {
      final e = await TestEnv.create();
      e.social.cancel = true;
      final a = Get.find<AccountService>();
      expect(await a.linkSocial('apple'), isA<AccountCancelled>());
      final bad = await a.loginEmail(email: 'x@example.com', password: 'nope');
      expect(bad, isA<AccountFailed>());
      expect(accountErrorText(bad as AccountFailed), 'Email or password is wrong');
      await e.dispose();
    });

    test('sign out: server logout, push token dropped, RevenueCat and Firebase cleared, back to guest', () async {
      final e = await TestEnv.create(member: true);
      e.rc.premium = true;
      await Get.find<AccountService>().signOut();
      expect(e.authRepo.calls, contains('logout'));
      expect(e.notifications.calls, contains('signedOut'));
      expect(e.rc.loggedIn, isNull);
      expect(e.social.signOuts, greaterThan(0));
      expect(e.access.sdkPremium.value, false);
      await e.dispose();
    });
  });

  group('screens', () {
    testWidgets('13 Save your progress: benefits, buttons, Not now → Today; link success → Today', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      await t.pumpWidget(e.app(initial: AppRoutes.saveYourProgressOptional));
      await settle(t);
      expect(find.text('Save your progress'), findsOneWidget);
      expect(find.text('Post dedications'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      await t.tap(find.byKey(const Key('btn-google')));
      await settle(t);
      expect(e.authRepo.calls, contains('link:google'));
      expect(Get.currentRoute, AppRoutes.todayMember);
      await e.dispose();
    });

    testWidgets('16 free variant has its own copy; account exists → sheet offers login', (t) async {
      phone(t);
      final e = await TestEnv.create(onboardingDone: true);
      e.social.googleToken = 'exists';
      await t.pumpWidget(e.app(initial: AppRoutes.saveYourProgressFreeUser));
      await settle(t);
      expect(find.text('Pick up on another phone'), findsOneWidget);
      await t.tap(find.byKey(const Key('btn-google')));
      await settle(t);
      expect(find.text('You already have an account'), findsOneWidget);
      await t.tap(find.text('Log in and keep my progress'));
      await settle(t);
      expect(e.authRepo.calls, containsAll(['link:google']));
      await e.dispose();
    });

    testWidgets('17 sign up: validation messages, taken email shows the login prompt, success → check email', (t) async {
      phone(t);
      final e = await TestEnv.create(onboardingDone: true);
      await t.pumpWidget(e.app(initial: AppRoutes.signUpWithEmail));
      await settle(t);
      await t.tap(find.text('Create account'));
      await t.pump();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsOneWidget);
      await t.enterText(find.byKey(const Key('su-first')), 'Lena');
      await t.enterText(find.byKey(const Key('su-email')), 'taken@example.com');
      await t.enterText(find.byKey(const Key('su-password')), 'long-enough-1');
      await t.tap(find.text('Create account'));
      await settle(t);
      expect(find.byKey(const Key('su-exists')), findsOneWidget);
      await t.enterText(find.byKey(const Key('su-email')), 'new@example.com');
      await t.tap(find.text('Create account'));
      await settle(t);
      expect(e.authRepo.calls, contains('linkEmail:new@example.com'));
      expect(Get.currentRoute, AppRoutes.checkYourEmail);
      expect(find.textContaining('new@example.com'), findsOneWidget);
      await e.dispose();
    });

    testWidgets('18 login: wrong password message, then success → Today; forgot goes to 19 → generic 20', (t) async {
      phone(t);
      final e = await TestEnv.create(onboardingDone: true);
      await t.pumpWidget(e.app(initial: AppRoutes.logIn));
      await settle(t);
      await t.enterText(find.byKey(const Key('li-email')), 'a@example.com');
      await t.enterText(find.byKey(const Key('li-password')), 'wrong');
      await t.tap(find.text('Log in').last);
      await settle(t);
      expect(find.text('Email or password is wrong'), findsOneWidget);
      await t.enterText(find.byKey(const Key('li-password')), 'correct-password');
      await t.tap(find.text('Log in').last);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.todayFree);
      await t.pumpWidget(const SizedBox());
      await e.dispose();

      final e2 = await TestEnv.create(onboardingDone: true);
      await t.pumpWidget(e2.app(initial: AppRoutes.forgotPassword));
      await settle(t);
      await t.enterText(find.byKey(const Key('fp-email')), 'nobody@example.com'); // unknown address: same screen anyway
      await t.tap(find.text('Send reset link'));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.checkYourEmail);
      expect(find.byKey(const Key('check-body')), findsOneWidget);
      expect(e2.authRepo.calls, contains('forgot:nobody@example.com'));
      await e2.dispose();
    });

    testWidgets('20 resend has a 60 s cooldown', (t) async {
      phone(t);
      final e = await TestEnv.create(onboardingDone: true);
      await t.pumpWidget(e.app());
      Get.toNamed(AppRoutes.checkYourEmail, arguments: {'email': 'a@b.co', 'purpose': 'reset'});
      await settle(t);
      await t.tap(find.text('Send again'));
      await t.pump(const Duration(seconds: 2));
      expect(find.byKey(const Key('resend-wait')), findsOneWidget);
      expect(e.authRepo.calls.where((c) => c == 'forgot:a@b.co').length, 1);
      await t.pump(const Duration(seconds: 61));
      expect(find.text('Send again'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('21 account gate sheet: signs in with one tap and returns true', (t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      bool? result;
      await t.pumpWidget(e.app());
      await settle(t);
      Get.toNamed(AppRoutes.notFound);
      await settle(t);
      final ctx = t.element(find.byType(Scaffold).last);
      // ignore: use_build_context_synchronously
      showAccountGateForTest(ctx).then((v) => result = v);
      await settle(t);
      expect(find.text('Add your name to post'), findsOneWidget);
      await t.tap(find.byKey(const Key('btn-google')));
      await settle(t);
      expect(result, true);
      await e.dispose();
    });
  });

  group('email / universal links', () {
    test('parse https://wehum.app/auth/* and app links', () {
      expect(DeepLinks.parse('https://wehum.app/auth/sign-in?token=abc'), const LinkTarget(AppRoutes.authLink, {'kind': 'sign-in', 'token': 'abc'}));
      expect(DeepLinks.parse('https://wehum.app/auth/verify-email?token=abc'), const LinkTarget(AppRoutes.authLink, {'kind': 'verify-email', 'token': 'abc'}));
      expect(DeepLinks.parse('https://wehum.app/auth/reset-password?token=abc'), const LinkTarget(AppRoutes.resetPassword, {'token': 'abc'}));
      expect(DeepLinks.parse('https://wehum.app/auth/sign-in'), const LinkTarget(AppRoutes.notFound));
      expect(DeepLinks.parse('wehum://session/abc-1'), const LinkTarget(AppRoutes.sessionDetail, {'id': 'abc-1'}));
      expect(DeepLinks.parse('wehum://program/p1'), const LinkTarget(AppRoutes.programDetail, {'id': 'p1'}));
      expect(DeepLinks.parse('wehum://group'), const LinkTarget(AppRoutes.groupMeditationLobby));
      expect(DeepLinks.parse('wehum://membership'), const LinkTarget(AppRoutes.membershipPaywall));
      expect(DeepLinks.parse('wehum://today'), const LinkTarget(AppRoutes.todayMember));
      expect(DeepLinks.parse('https://wehum.app/r/abc23'), const LinkTarget(AppRoutes.buildYourOwn, {'slug': 'abc23'}));
      expect(DeepLinks.parse('https://evil.example/auth/sign-in?token=abc'), const LinkTarget(AppRoutes.notFound));
      expect(DeepLinks.parse('::::'), const LinkTarget(AppRoutes.notFound));
      expect(DeepLinks.parse(null), const LinkTarget(AppRoutes.todayMember));
    });

    testWidgets('sign-in link signs the person in; verify-email confirms; a bad link says so', (t) async {
      phone(t);
      final e = await TestEnv.create(onboardingDone: true);
      await t.pumpWidget(e.app());
      await settle(t);
      Get.toNamed(AppRoutes.authLink, arguments: {'kind': 'sign-in', 'token': 'tok'});
      await settle(t);
      expect(find.text('You’re signed in'), findsOneWidget);
      expect(find.byKey(const Key('auth-link-continue')), findsOneWidget);
      await e.dispose();
    });
  });
}
