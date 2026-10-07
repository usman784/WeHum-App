import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/bootstrap.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/config_service.dart';

import 'support/test_env.dart';

/// Every screen at 200 % text, dark and light: nothing overflows, nothing throws (spec §15 "works at 200 % text").
const sid = '11111111-1111-4111-8111-111111111111';

class Screen {
  const Screen(this.route, [this.args, this.name]);
  final String route;
  final Object? args;
  final String? name;
}

final screens = <Screen>[
  const Screen(AppRoutes.intro1Welcome), const Screen(AppRoutes.intro2NeverAlone), const Screen(AppRoutes.intro3EveryDay), const Screen(AppRoutes.intro4TrainingNotTherapy),
  const Screen(AppRoutes.setup1YourName), const Screen(AppRoutes.setup2MeditationReminder), const Screen(AppRoutes.setup3Reminder), const Screen(AppRoutes.howDoYouWantToStart),
  const Screen(AppRoutes.purchaseStates, {'state': 'failed'}), const Screen(AppRoutes.trialStarted), const Screen(AppRoutes.saveYourProgressOptional), const Screen(AppRoutes.membershipPaywall),
  const Screen(AppRoutes.restorePurchase), const Screen(AppRoutes.saveYourProgressFreeUser), const Screen(AppRoutes.signUpWithEmail), const Screen(AppRoutes.logIn), const Screen(AppRoutes.forgotPassword),
  const Screen(AppRoutes.checkYourEmail, {'email': 'marcus.vance@example.com', 'purpose': 'reset'}),
  const Screen(AppRoutes.todayMember), const Screen(AppRoutes.motdRoom), const Screen(AppRoutes.todayFree), const Screen(AppRoutes.worldMapWorldVibration), const Screen('/message/2026-10-05', {'date': '2026-10-05'}),
  const Screen(AppRoutes.exploreArchive), const Screen(AppRoutes.notifications), const Screen(AppRoutes.sosHowCanIHelp), const Screen(AppRoutes.library), const Screen('/theme/t-anx', {'id': 't-anx'}),
  const Screen(AppRoutes.search), const Screen(AppRoutes.allPrograms), const Screen('/program/p-7', {'id': 'p-7'}), const Screen('/teacher/tc-raphael', {'id': 'tc-raphael'}), const Screen(AppRoutes.myMeditations),
  const Screen(AppRoutes.buildYourOwn), const Screen(AppRoutes.buildYourOwnAdvanced), const Screen('/session/s-sleep', {'id': 's-sleep'}), const Screen('/dedications/$sid', {'sessionId': sid}),
  const Screen(AppRoutes.silenceRoomSetup), const Screen(AppRoutes.together), const Screen(AppRoutes.groupMeditationLobby), const Screen(AppRoutes.you), const Screen(AppRoutes.yourProgress),
  const Screen(AppRoutes.editProfile), const Screen(AppRoutes.reminders), const Screen(AppRoutes.downloads), const Screen(AppRoutes.privacyData), const Screen(AppRoutes.helpAbout),
  const Screen(AppRoutes.manageMembership), const Screen(AppRoutes.trialEnding), const Screen(AppRoutes.billingIssue), const Screen(AppRoutes.membershipEnded), const Screen(AppRoutes.offline),
  const Screen(AppRoutes.updateRequired), const Screen(AppRoutes.maintenance), const Screen(AppRoutes.notFound), const Screen(AppRoutes.challenges), const Screen(AppRoutes.gratitude),
  const Screen(AppRoutes.breathwork), const Screen(AppRoutes.breathPattern), const Screen(AppRoutes.milestones), const Screen(AppRoutes.intent), const Screen(AppRoutes.pushPreview),
  const Screen(AppRoutes.resetPassword, {'token': 'x'}),
];

void main() {
  for (final dark in [true, false]) {
    testWidgets('all ${screens.length} screens at 200% text (${dark ? 'dark' : 'light'}): no overflow, no exception', (t) async {
      phone(t, scale: 2.0);
      final e = await TestEnv.create(member: true, onboardingDone: true, prefs: const {'first_name': 'Marcus Vance'});
      await Get.find<CatalogService>().load();
      Get.find<ConfigService>().current.value = Bootstrap.fromJson({'serverTime': DateTime.now().millisecondsSinceEpoch, 'features': {'challenges': true, 'gratitude': true, 'breathwork': true, 'milestones': true, 'intent': true}, 'catalogVersion': 1});
      await t.pumpWidget(Builder(builder: (_) => e.app()));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      final failures = <String>[];
      final caught = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = caught.add; // collect every error (a screen can overflow in several places)
      for (final s in screens) {
        caught.clear();
        Get.toNamed(s.route, arguments: s.args);
        await t.pump();
        await t.pump(const Duration(milliseconds: 700));
        await t.pump(const Duration(milliseconds: 700));
        t.takeException();
        for (final d in caught) {
          final text = d.toString();
          final what = RegExp(r'overflowed by [\d.]+ pixels on the \w+').firstMatch(text)?.group(0) ?? text.split('\n').first;
          final where = RegExp(r'lib/([^\s]+\.dart:\d+:\d+)').firstMatch(text)?.group(1) ?? '?';
          failures.add('${s.route}: $what @ $where');
        }
        Get.until((r) => r.settings.name == AppRoutes.todayMember || r.isFirst);
        await t.pump(const Duration(milliseconds: 400));
        caught.clear();
        t.takeException();
      }
      FlutterError.onError = previous;
      expect(failures, isEmpty, reason: failures.join('\n'));
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  }

  testWidgets('tap targets are labelled and at least 44 pt on the core screens', (t) async {
    final handle = t.ensureSemantics();
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await Get.find<CatalogService>().load();
    await t.pumpWidget(e.app());
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    for (final r in [AppRoutes.todayMember, AppRoutes.library, AppRoutes.together, AppRoutes.you, AppRoutes.sosHowCanIHelp, AppRoutes.membershipPaywall]) {
      Get.offAllNamed(r);
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline), reason: 'labels on $r');
      await expectLater(t, meetsGuideline(androidTapTargetGuideline), reason: 'size on $r');
    }
    handle.dispose();
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
