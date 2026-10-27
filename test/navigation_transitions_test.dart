import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/features/account/views/account_pages.dart';

import 'support/test_env.dart';

/// Moving forward slides the new screen in from the right; going back slides the current one out to the right.
/// "Back to log in" is a way back, so it must not slide in from the right like a new screen.
Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('"Back to log in" from the check-your-email screen slides back, not forward', (t) async {
    phone(t);
    final e = await TestEnv.create(onboardingDone: true);
    await t.pumpWidget(e.app(initial: AppRoutes.logIn));
    await settle(t);
    await t.tap(find.text('Forgot password?'));
    await settle(t);
    await t.enterText(find.byKey(const Key('fp-email')), 'nobody@example.com');
    await t.tap(find.text('Send reset link'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.checkYourEmail);

    await t.tap(find.text('Back to log in'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 120));
    expect(t.getTopLeft(find.byType(CheckEmailPage)).dx, greaterThan(0), reason: 'the current screen slides out to the right');
    expect(t.getTopLeft(find.byType(LoginPage)).dx, lessThanOrEqualTo(0), reason: 'the log in screen was already there: it does not come in from the right');
    await settle(t);
    expect(Get.currentRoute, AppRoutes.logIn);

    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
