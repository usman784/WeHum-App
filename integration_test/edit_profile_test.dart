// Sim flow against a local API: Edit profile is for accounts only; an account changes photo, names, bio and username.
// Photos come from files on the Mac (the simulator can read them) and go through the real resize + upload path; only
// the system photo picker is skipped. Run with PHOTO_JPEG and PHOTO_PNG dart-defines pointing at those files.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/data/contracts/repositories.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/network/api_client.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/account_service.dart';
import 'package:meditation/features/you/controllers/you_controllers.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> typeInto(WidgetTester t, Key key, String text) async {
  await t.scrollUntilVisible(find.byKey(key), 200, scrollable: find.byType(Scrollable).first);
  await t.enterText(find.byKey(key), text);
  await settle(t, 800);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('edit profile: guests are kept out; an account changes photo, names, bio and username', (t) async {
    final jpeg = await File(const String.fromEnvironment('PHOTO_JPEG')).readAsBytes();
    final png = await File(const String.fromEnvironment('PHOTO_PNG')).readAsBytes();
    debugPrint('PROFILE photos: jpeg ${jpeg.length} B, png ${png.length} B');
    app.bootstrap();
    await settle(t, 9000);
    final access = Get.find<AccessService>();
    final me = Get.find<MeRepository>();
    expect(access.isGuest.value, isTrue);

    // ── guest: no Edit link, the screen asks for an account, and the server refuses a photo
    Get.offAllNamed(AppRoutes.you);
    await settle(t, 5000); // shot 1: guest You tab
    expect(find.byKey(const Key('you-edit')), findsNothing);
    Get.toNamed(AppRoutes.editProfile);
    await settle(t, 5000); // shot 2: account-only
    expect(find.byKey(const Key('account-only')), findsOneWidget);
    Object? refused;
    try {
      await me.setAvatar(jpeg, 'image/jpeg');
    } catch (e) {
      refused = e;
    }
    expect(refused, isNotNull);
    expect(ApiClient.map(refused!).code, ErrorCode.accountRequired);
    debugPrint('PROFILE guest photo refused: ${ApiClient.map(refused).code}');

    // ── sign up: the same screen opens by itself
    final stamp = DateTime.now().millisecondsSinceEpoch % 100000000;
    final r = await Get.find<AccountService>().linkEmail(email: 'sim$stamp@wehum.test', password: 'Sim-test-pw-2026', firstName: 'Sim', username: 'sim$stamp');
    debugPrint('PROFILE sign-up: $r');
    await settle(t, 4000);
    expect(access.isGuest.value, isFalse);
    expect(find.byKey(const Key('profile-save')), findsOneWidget);
    final ctrl = Get.find<EditProfileController>();
    await settle(t, 3000); // shot 3: edit profile for the new account

    // ── photo: a real 512 px phone photo, then a large PNG that has to be shrunk first
    for (final (name, bytes) in [('jpeg', jpeg), ('png', png)]) {
      final (fit, type) = await EditProfileController.fitPhoto(bytes);
      final p = await me.setAvatar(fit, type);
      ctrl.avatarUrl.value = p.avatarUrl;
      debugPrint('PROFILE photo $name: sent ${fit.length} B as $type → ${p.avatarUrl}');
      expect(p.avatarUrl, contains('avatars/'));
    }
    await settle(t, 4000); // shot 4: photo shown

    // ── names, bio, username (a reserved name is refused live, a free one gets the tick)
    await typeInto(t, const Key('profile-first'), 'Simone');
    await typeInto(t, const Key('profile-last'), 'Tester');
    await typeInto(t, const Key('profile-bio'), 'I sit every morning before work.');
    await typeInto(t, const Key('profile-username'), 'raphael');
    await settle(t, 2500);
    expect(find.byKey(const Key('username-bad')), findsOneWidget);
    await settle(t, 3000); // shot 5: reserved username refused
    await typeInto(t, const Key('profile-username'), 'simone.$stamp');
    await settle(t, 2500);
    expect(find.byKey(const Key('username-ok')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('profile-save')), 200, scrollable: find.byType(Scrollable).first);
    await settle(t, 500);
    await t.tap(find.byKey(const Key('profile-save')));
    await settle(t, 4000); // shot 6: Saved
    expect(ctrl.error.value, isNull);
    final saved = await me.me();
    debugPrint('PROFILE saved: ${saved.firstName} ${saved.lastName} @${saved.username} bio="${saved.bio}" next=${saved.usernameNextChangeAt}');
    expect(saved.firstName, 'Simone');
    expect(saved.lastName, 'Tester');
    expect(saved.bio, 'I sit every morning before work.');
    expect(saved.username, 'simone.$stamp');
    expect(saved.usernameNextChangeAt, isNotNull); // the 7-day wait starts now

    // ── the You tab shows the result
    Get.offAllNamed(AppRoutes.you);
    await settle(t, 6000); // shot 7: You tab with photo, name and @username
    expect(find.byKey(const Key('you-edit')), findsOneWidget);
    expect(find.text('@simone.$stamp'), findsOneWidget);
    Get.toNamed(AppRoutes.editProfile);
    await settle(t, 6000); // shot 8: username now locked for 7 days
    expect(find.textContaining('You can change your username again on'), findsOneWidget);
  });
}
