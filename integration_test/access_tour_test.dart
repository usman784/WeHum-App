// Throwaway tour for the access ticket: opens every screen that differs between a guest and an account and prints
// "SHOT <name>" while each is on screen, so a watcher on the Mac takes a simulator screenshot. Does not sign in or out.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/catalog_service.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('access tour', (t) async {
    app.bootstrap();
    await settle(t, 12000);
    final a = Get.find<AccessService>();
    final who = a.isGuest.value ? 'guest' : 'account';
    debugPrint('TOUR state=$who plan=${a.plan}');

    Future<void> shot(String name, [int wait = 4000]) async {
      await settle(t, wait);
      debugPrint('SHOT $who-$name');
      await settle(t, 2500);
    }

    Future<void> scroll(String name, [double dy = -550]) async {
      final s = find.byType(Scrollable);
      if (s.evaluate().isEmpty) return;
      await t.drag(s.first, Offset(0, dy), warnIfMissed: false);
      await shot(name, 1500);
    }

    Get.offAllNamed(a.isMember ? AppRoutes.todayMember : AppRoutes.todayFree);
    await shot('01-today');
    await scroll('02-today-scrolled');

    Get.offAllNamed(AppRoutes.you);
    await shot('03-you');
    await scroll('04-you-scrolled');
    await scroll('05-you-scrolled-more');
    await scroll('06-you-bottom', -900);

    Get.toNamed(AppRoutes.editProfile);
    await shot('07-edit-profile');
    Get.back();
    Get.toNamed(AppRoutes.yourProgress);
    await shot('08-your-progress');
    Get.back();
    Get.toNamed(AppRoutes.milestones);
    await shot('09-milestones');
    Get.back();
    Get.toNamed(AppRoutes.settings);
    await shot('10-settings');
    await scroll('11-settings-bottom', -900);
    Get.back();

    Get.offAllNamed(AppRoutes.library);
    await shot('12-library');

    final sessions = Get.find<CatalogService>().catalog.value?.sessions ?? const [];
    final free = sessions.where((s) => !s.isPremium).firstOrNull;
    final premium = sessions.where((s) => s.isPremium).firstOrNull;
    if (free != null) {
      Get.toNamed(AppRoutes.sessionDetail.replaceFirst(':id', free.id), arguments: {'id': free.id});
      await shot('13-free-session');
      Get.back();
    }
    if (premium != null) {
      Get.toNamed(AppRoutes.sessionDetail.replaceFirst(':id', premium.id), arguments: {'id': premium.id});
      await shot('14-premium-session');
      Get.back();
    }
    Get.toNamed(AppRoutes.myMeditations);
    await shot('15-my-meditations');
    Get.back();
    Get.toNamed(AppRoutes.buildYourOwn);
    await shot('16-build-your-own');
    Get.back();

    Get.offAllNamed(AppRoutes.together);
    await shot('17-together');
    Get.toNamed(AppRoutes.membershipPaywall);
    await shot('18-paywall');
    Get.back();
    debugPrint('TOUR done');
  });
}
