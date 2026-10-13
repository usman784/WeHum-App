import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/network/api_client.dart';
import 'package:meditation/core/services/account_service.dart';
import 'package:meditation/core/services/deep_links.dart';
import 'package:meditation/core/services/inbox_service.dart';
import 'package:meditation/core/theme/app_theme.dart';
import 'package:meditation/core/widgets/video_description.dart';
import 'package:meditation/features/account/controllers/account_controllers.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route, {bool member = true, bool onboardingDone = true}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: onboardingDone, prefs: const {'first_name': 'Marcus'});
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  group('onboarding: back', () {
    testWidgets('intro slides 2 to 4 have a back button that returns to the previous slide', (t) async {
      final e = await open(t, AppRoutes.intro2NeverAlone, onboardingDone: false);
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      await t.tap(find.bySemanticsLabel('Back'));
      await settle(t);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('Help → "Watch the intro again" is only the four slides and ends back in Help: no name, time or reminder steps', (t) async {
      final e = await open(t, AppRoutes.helpAbout);
      await t.tap(find.text('Watch the intro again'));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.intro1Welcome);
      expect(find.text('Close'), findsOneWidget); // not "Skip"
      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.text('Next'));
        await settle(t);
      }
      expect(find.text('Done'), findsOneWidget);
      await t.tap(find.text('Done'));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.helpAbout);
      expect(find.text('What should we call you?'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('closing the replay at any slide returns to Help', (t) async {
      final e = await open(t, AppRoutes.helpAbout);
      await t.tap(find.text('Watch the intro again'));
      await settle(t);
      await t.tap(find.text('Close'));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.helpAbout);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('intro carousel', () {
    testWidgets('a slide moves on by itself after a few seconds; touching the screen stops that; the last slide waits', (t) async {
      final e = await open(t, AppRoutes.intro1Welcome, onboardingDone: false);
      await t.pump(const Duration(seconds: 7));
      await settle(t);
      expect(Get.currentRoute, '/intro/2');
      await t.tapAt(const Offset(200, 300)); // a touch: this slide stays
      await t.pump(const Duration(seconds: 9));
      await settle(t);
      expect(Get.currentRoute, '/intro/2');
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('the last slide never advances on its own', (t) async {
      final e = await open(t, AppRoutes.intro4TrainingNotTherapy, onboardingDone: false);
      await t.pump(const Duration(seconds: 20));
      expect(Get.currentRoute, AppRoutes.intro4TrainingNotTherapy);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('notifications', () {
    test('a link to the meditation of the day opens it; the daily message link opens that day', () {
      expect(DeepLinks.parse('wehum://motd').route, AppRoutes.motdRoom);
      expect(DeepLinks.parse('wehum://message/2026-10-12'), LinkTarget(AppRoutes.dailyMessage, const {'date': '2026-10-12'}));
      expect(DeepLinks.parse(null).route, AppRoutes.todayMember);
    });

    testWidgets('the inbox is emptied on sign-out, so the bell never shows what the previous person had', (t) async {
      final e = await open(t, AppRoutes.todayMember);
      final inbox = Get.find<InboxService>();
      await inbox.load();
      expect(inbox.items, isNotEmpty);
      expect(inbox.unread.value, greaterThan(0));
      await t.runAsync(() => inbox.reset());
      expect(inbox.items, isEmpty);
      expect(inbox.unread.value, 0);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('screens', () {
    testWidgets('the Meditation of the Day room has no SoS button', (t) async {
      final e = await open(t, AppRoutes.motdRoom);
      expect(find.text('Meditation of the Day'), findsWidgets);
      expect(find.text('SoS'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('the footer line under the version reads Transcendence & Connection', (t) async {
      final e = await open(t, AppRoutes.helpAbout);
      expect(find.text('Transcendence & Connection'), findsOneWidget);
      expect(find.textContaining('not therapy'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('Your progress: Together is called Group sits and says what it counts', (t) async {
      final e = await open(t, AppRoutes.yourProgress);
      expect(find.text('GROUP SITS'), findsOneWidget);
      expect(find.text('Sat live with others'), findsOneWidget);
      expect(find.text('TOGETHER'), findsNothing);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('Library: a Teachers heading above the list of teachers', (t) async {
      final e = await open(t, AppRoutes.library);
      await t.scrollUntilVisible(find.byKey(const Key('teachers-heading')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('TEACHERS'), findsOneWidget);
      expect(find.byKey(const Key('teacher-card')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });

    testWidgets('Together: Love Projection sits next to the Gratitude feed, both coming soon', (t) async {
      final e = await open(t, AppRoutes.together);
      await t.scrollUntilVisible(find.byKey(const Key('love-projection-feed')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text('Gratitude feed'), findsOneWidget);
      expect(find.text('Love Projection'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('profile', () {
    testWidgets('edit profile: a short bio is saved, limited to 200 characters, and can be cleared', (t) async {
      final e = await open(t, AppRoutes.editProfile);
      final bio = find.byKey(const Key('profile-bio'));
      await t.ensureVisible(bio);
      expect(t.widget<TextField>(find.descendant(of: bio, matching: find.byType(TextField))).maxLength, 200);
      await t.enterText(bio, 'I sit every morning.');
      await t.ensureVisible(find.byKey(const Key('profile-save')));
      await t.tap(find.byKey(const Key('profile-save')));
      await settle(t);
      expect(e.me.profile.bio, 'I sit every morning.');
      await t.enterText(bio, '');
      await t.tap(find.byKey(const Key('profile-save')));
      await settle(t);
      expect(e.me.profile.bio, isNull);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  group('sign-in conflicts', () {
    test('an e-mail that belongs to another sign-in method shows the server\'s sentence', () {
      final f = AccountFailed(ApiException(ErrorCode.emailRegistered, status: 409, message: 'This email is already registered with Google. Log in with Google.'));
      expect(accountErrorText(f), 'This email is already registered with Google. Log in with Google.');
      expect(ErrorCode.parse('EMAIL_REGISTERED'), ErrorCode.emailRegistered);
    });
  });

  group('video description', () {
    Widget host(String text) => MaterialApp(theme: buildTheme(Brightness.dark), home: Scaffold(body: SingleChildScrollView(child: VideoDescription(text))));

    testWidgets('is collapsed to a few lines, expands and collapses, and its links are tappable', (t) async {
      phone(t);
      final long = '${List.generate(30, (i) => 'Line $i of the description.').join('\n')}\nMore at https://www.raphaelreiter.com/free.';
      await t.pumpWidget(host(long));
      expect(find.text('Video description'), findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);
      final collapsed = t.getSize(find.byKey(const Key('video-description-text'))).height;
      await t.tap(find.byKey(const Key('video-description-toggle')));
      await t.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(t.getSize(find.byKey(const Key('video-description-text'))).height, greaterThan(collapsed * 3));
      await t.tap(find.text('Show less'));
      await t.pumpAndSettle();
      expect(find.text('Show more'), findsOneWidget);
    });

    testWidgets('a link is a tappable span and sentence punctuation is not part of it', (t) async {
      phone(t);
      await t.pumpWidget(host('Free daily message: https://www.raphaelreiter.com, thanks.'));
      final rich = t.widget<RichText>(find.descendant(of: find.byKey(const Key('video-description-text')), matching: find.byType(RichText)).first);
      final spans = <TextSpan>[];
      rich.text.visitChildren((s) {
        if (s is TextSpan && s.recognizer != null) spans.add(s);
        return true;
      });
      expect(spans, hasLength(1));
      expect(spans.single.text, 'https://www.raphaelreiter.com');
    });
  });
}
