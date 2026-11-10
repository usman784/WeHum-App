// Sim flow against the local API as a fresh guest: the log-in card is on Home only, the You tab no longer repeats it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final b = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('guest: log-in card on Home, nothing on You, buttons lead to the right screens', (t) async {
    app.bootstrap();
    await settle(t, 7000);
    Get.offAllNamed(AppRoutes.todayFree);
    await settle(t, 6000);
    if (find.byKey(const Key('location-not-now')).evaluate().isNotEmpty) { // first open on a fresh install asks about location first
      await b.takeScreenshot('0_first_open_location_prompt');
      await t.tap(find.byKey(const Key('location-not-now')));
      await settle(t, 3000);
    }
    expect(find.byKey(const Key('signin-promo')), findsOneWidget);
    await b.takeScreenshot('1_home_guest_top');
    await settle(t, 2500);
    await b.takeScreenshot('1b_home_guest_animation_later_frame');
    await t.scrollUntilVisible(find.byKey(const Key('free-see-all')), 300, scrollable: find.byType(Scrollable).first);
    await settle(t, 800);
    await b.takeScreenshot('2_home_guest_scrolled');
    await t.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await settle(t, 800);

    await t.tap(find.byKey(const Key('signin-promo-login')));
    await settle(t, 3000);
    expect(Get.currentRoute, AppRoutes.logIn);
    await b.takeScreenshot('3_login_screen_from_home');
    Get.back<void>();
    await settle(t, 1500);

    Get.offAllNamed(AppRoutes.you);
    await settle(t, 5000);
    expect(find.byKey(const Key('signin-promo')), findsNothing);
    expect(find.byKey(const Key('guest-card')), findsNothing);
    await b.takeScreenshot('5_you_guest');

    Get.offAllNamed(AppRoutes.todayFree);
    await settle(t, 4000);
    expect(find.byKey(const Key('signin-promo')), findsOneWidget);
    await b.takeScreenshot('6_home_guest_back');
  });
}
