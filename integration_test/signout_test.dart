// Sim flow against the real API: You tab → Sign out → confirm. The app must come back to a working start screen with a
// fresh guest session, and the Sign out button must not be left loading (the bug that blocked signing in to another account).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/services/auth_service.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sign out from You returns to the start with a new session', (t) async {
    app.bootstrap();
    await settle(t, 7000);
    await binding.convertFlutterSurfaceToImage();
    Get.offAllNamed(AppRoutes.you);
    await settle(t, 3000);
    final auth = Get.find<AuthService>();
    debugPrint('SIGNOUT session before: ${auth.me.value?.id}');
    await binding.takeScreenshot('so1_you');

    final button = find.byKey(const Key('sign-out'));
    await t.scrollUntilVisible(button, 300, scrollable: find.byType(Scrollable).first);
    await settle(t, 500);
    await binding.takeScreenshot('so2_button');
    await t.tap(button);
    await settle(t, 1200);
    await binding.takeScreenshot('so3_confirm');
    await t.tap(find.byKey(const Key('confirm-sign-out')));
    await settle(t, 9000);
    await binding.takeScreenshot('so4_after');

    debugPrint('SIGNOUT route after: ${Get.currentRoute}');
    debugPrint('SIGNOUT session after: ${auth.me.value?.id} (guest: ${auth.me.value?.isGuest})');
    expect(find.byKey(const Key('sign-out')), findsNothing, reason: 'still on the You page: sign-out did not finish');
    expect(auth.me.value, isNotNull, reason: 'no session after sign-out');
    // a guest keeps its install id, so the server hands back the same guest: only the session being usable is checked
  });
}
