// Sim flow against the real API: the top-right gear opens Settings directly (not the You tab).
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('the gear on a tab opens Settings, the You tab is still its own page', (t) async {
    app.bootstrap();
    await settle(t, 7000);
    Get.offAllNamed(AppRoutes.library);
    await settle(t, 6000); // screenshot window: a tab with the gear in the header
    expect(find.byKey(const Key('open-settings')), findsOneWidget);
    expect(find.bySemanticsLabel('Profile'), findsNothing);
    await t.tap(find.byKey(const Key('open-settings')));
    await settle(t, 6000); // Settings
    expect(Get.currentRoute, AppRoutes.settings);
    expect(find.byKey(const Key('r-reminders')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('sign-out')), 300, scrollable: find.byType(Scrollable).first);
    await settle(t, 6000); // Settings, scrolled to Sign out
    Get.offAllNamed(AppRoutes.you);
    await settle(t, 6000); // the You tab is unchanged
    expect(Get.currentRoute, AppRoutes.you);
  });
}
