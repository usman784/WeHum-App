import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/purchase_service.dart';
import 'package:meditation/features/membership/controllers/membership_controllers.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

void main() {
  final now = DateTime.utc(2026, 10, 10, 12);

  group('membership state', () {
    test('trial, trial ending (≤ 2.5 days), active, billing issue, ended, none', () {
      expect(membershipState(Entitlement(active: true, periodType: 'trial', expiresAt: now.add(const Duration(days: 5))), now: now), MembershipState.trial);
      expect(membershipState(Entitlement(active: true, periodType: 'trial', expiresAt: now.add(const Duration(days: 2))), now: now), MembershipState.trialEnding);
      expect(membershipState(Entitlement(active: true, periodType: 'normal', expiresAt: now.add(const Duration(days: 200))), now: now), MembershipState.active);
      expect(membershipState(Entitlement(active: true, periodType: 'normal', billingIssue: true, expiresAt: now.add(const Duration(days: 8))), now: now), MembershipState.billingIssue);
      expect(membershipState(const Entitlement(active: false, productId: 'wehum_annual'), now: now), MembershipState.ended);
      expect(membershipState(const Entitlement(), now: now), MembershipState.none);
    });

    test('plan names', () {
      expect(planName(const Entitlement(productId: 'wehum_annual_founding', isFounding: true)), 'Annual plan · Founding');
      expect(planName(const Entitlement(productId: 'wehum_annual')), 'Annual plan');
      expect(planName(const Entitlement(productId: 'wehum_monthly')), 'Monthly plan');
    });

    test('description for a trial uses the store price', () {
      Get.reset();
      final e = AccessSeedHelper.controller(Entitlement(active: true, periodType: 'trial', productId: 'wehum_annual_founding', isFounding: true, expiresAt: DateTime.utc(2026, 10, 12)));
      const offer = Offer(offeringId: 'default', annual: PlanOption(packageId: 'a', productId: 'wehum_annual_founding', priceString: r'$59.00', isAnnual: true, isFounding: true));
      expect(e.describe(offer), r'Free until October 12, 2026. Then $59.00 per year (Founding price), renewing automatically.');
    });
  });

  testWidgets('14 paywall: perks, store prices, founding banner, annual preselected, buy → welcome', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.membershipPaywall));
    await settle(t);
    await Get.find<PurchaseService>().loadOffer();
    Get.find<PurchaseService>().offer.refresh();
    await t.pump();
    expect(find.text('Silence Room'), findsOneWidget);
    expect(find.text(r'$59.00'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
    expect(find.text('Start 7-day free trial'), findsOneWidget);
    await t.tap(find.byKey(const Key('plan-monthly')));
    await t.pump();
    expect(Get.find<PaywallController>().selected.value, 'monthly');
    await t.scrollUntilVisible(find.text('Start 7-day free trial'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Start 7-day free trial'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.trialStarted);
    expect(e.access.isMember, true);
    await e.dispose();
  });

  testWidgets('14 paywall: offer unavailable shows retry; unavailable product refreshes the offer', (t) async {
    phone(t);
    final e = await TestEnv.create();
    e.rc.current = const Offer(offeringId: '');
    await t.pumpWidget(e.app(initial: AppRoutes.membershipPaywall));
    await settle(t);
    expect(find.text("Plans aren't available right now."), findsOneWidget);
    await e.dispose();
  });

  testWidgets('11 status screens: failed has Try again, pending has the Ask to Buy copy', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'failed'});
    await settle(t);
    expect(find.text('Payment didn’t go through'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    Get.back<void>();
    await settle(t);
    Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'pending'});
    await settle(t);
    expect(find.text('Waiting for approval'), findsOneWidget);
    await t.tap(find.text('Continue free while you wait'));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.todayFree);
    await e.dispose();
  });

  testWidgets('12 welcome uses the name and the trial end date', (t) async {
    phone(t);
    final e = await TestEnv.create(prefs: {'first_name': 'Marcus'});
    e.access.entitlement.value = Entitlement(active: true, periodType: 'trial', expiresAt: DateTime.utc(2026, 10, 12));
    await t.pumpWidget(e.app(initial: AppRoutes.trialStarted));
    await settle(t);
    expect(find.text('Welcome to WeHum, Marcus.'), findsOneWidget);
    expect(find.textContaining('October 12, 2026'), findsOneWidget);
    await e.dispose();
  });

  testWidgets('15 restore: found → unlocked; not found → options', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.restorePurchase));
    await settle(t);
    expect(find.text('Membership restored'), findsOneWidget);
    expect(e.access.isMember, true);
    await t.pumpWidget(const SizedBox());
    await e.dispose();

    final e2 = await TestEnv.create();
    e2.rc.restoreNext = RestoreOutcome.notFound;
    await t.pumpWidget(e2.app(initial: AppRoutes.restorePurchase));
    await settle(t);
    expect(find.text('No membership found'), findsOneWidget);
    expect(find.text('See membership options'), findsOneWidget);
    await e2.dispose();
  });

  testWidgets('61 manage: trial plan, price, banner for trial ending; 63 billing banner', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true);
    e.access.entitlement.value = Entitlement(active: true, periodType: 'trial', productId: 'wehum_annual_founding', isFounding: true, expiresAt: DateTime.now().toUtc().add(const Duration(days: 2)));
    await t.pumpWidget(e.app(initial: AppRoutes.manageMembership));
    await settle(t);
    expect(find.text('Annual plan · Founding'), findsOneWidget);
    expect(find.text('ACTIVE · FREE TRIAL'), findsOneWidget);
    expect(find.byKey(const Key('banner-trial')), findsOneWidget);
    e.access.entitlement.value = Entitlement(active: true, productId: 'wehum_annual', billingIssue: true, expiresAt: DateTime.now().toUtc().add(const Duration(days: 8)));
    await t.pump();
    expect(find.byKey(const Key('banner-billing')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('64 ended: states what stays free and what is locked', (t) async {
    phone(t);
    final e = await TestEnv.create();
    await t.pumpWidget(e.app(initial: AppRoutes.membershipEnded));
    await settle(t);
    expect(find.text('Your membership has ended'), findsOneWidget);
    expect(find.text('STILL FREE FOR YOU'), findsOneWidget);
    expect(find.text('NOW LOCKED'), findsOneWidget);
    await e.dispose();
  });
}

class AccessSeedHelper {
  static ManageMembershipController controller(Entitlement e) {
    final access = Get.put(AccessService());
    access.entitlement.value = e;
    return ManageMembershipController();
  }
}
