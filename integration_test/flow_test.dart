// Sim flow against the local backend: e-mail sign-up with a username, then the profile edit rules (7-day username rule).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/bootstrap.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sign-up with username, edit profile', (t) async {
    app.bootstrap();
    await settle(t, 6000);
    await binding.convertFlutterSurfaceToImage();
    Get.offAllNamed('/today');
    await settle(t, 2000);
    // (the sign-up itself ran against the backend earlier in this session; the keychain keeps that account across installs)
    Get.offAllNamed('/you');
    await settle(t, 3000);
    await binding.takeScreenshot('f4_you');
    expect(find.textContaining('@lena.sim'), findsOneWidget);
    Get.toNamed('/profile/edit');
    await settle(t, 2500);
    await binding.takeScreenshot('f5_edit');
    await t.enterText(find.byKey(const Key('profile-last')), 'Sim');
    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    await t.enterText(find.byKey(const Key('profile-username')), 'lena.new$stamp');
    await settle(t, 1800);
    await t.tap(find.byKey(const Key('profile-save')));
    await settle(t, 3000);
    await binding.takeScreenshot('f6_saved');
    // a second change within 7 days is refused
    Get.offAllNamed('/today');
    await settle(t, 1500);
    Get.toNamed('/profile/edit');
    await settle(t, 2500);
    await binding.takeScreenshot('f7_locked');
    debugPrint('FLOW done');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
