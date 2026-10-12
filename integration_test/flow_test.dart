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
    Get.toNamed('/account/email');
    await settle(t, 2500);
    await binding.takeScreenshot('f1_signup');
    final stamp = DateTime.now().millisecondsSinceEpoch % 1000000;
    await t.enterText(find.byKey(const Key('su-first')), 'Lena');
    await settle(t, 800);
    final user = (t.widget(find.byKey(const Key('username-field'))) as TextFormField).controller!.text;
    debugPrint('FLOW suggested username: $user');
    expect(user.length, greaterThan(2));
    await t.enterText(find.byKey(const Key('username-field')), 'lena.sim$stamp');
    await settle(t, 1800);
    expect(find.byKey(const Key('username-ok')), findsOneWidget);
    await t.enterText(find.byKey(const Key('su-email')), 'lena.sim$stamp@example.com');
    await t.enterText(find.byKey(const Key('su-password')), 'Correct-horse-42');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t, 600);
    await binding.takeScreenshot('f2_signup_filled');
    await t.tap(find.text('Create account'));
    await settle(t, 4000);
    debugPrint('FLOW after signup route: ${Get.currentRoute}');
    await binding.takeScreenshot('f3_after_signup');
    Get.offAllNamed('/you');
    await settle(t, 3000);
    await binding.takeScreenshot('f4_you');
    expect(find.text('@lena.sim$stamp'), findsOneWidget);
    Get.toNamed('/profile/edit');
    await settle(t, 2500);
    await binding.takeScreenshot('f5_edit');
    await t.enterText(find.byKey(const Key('profile-last')), 'Sim');
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
