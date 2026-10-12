import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/services/catalog_service.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route, {bool member = true}) async {
  phone(t);
  final e = await TestEnv.create(member: member, onboardingDone: true);
  await Get.find<CatalogService>().load();
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  testWidgets('30 s preview: shows the cut-off, the matrix and the unlock button that opens the paywall', (t) async {
    final e = await open(t, '/preview/s-sleep', member: false);
    expect(find.byKey(const Key('preview-state')), findsOneWidget);
    expect(find.textContaining('30-SECOND'), findsOneWidget);
    expect(find.text('0:00 / 0:30'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('preview-unlock')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('preview-unlock')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('challenge detail: trajectory, grace, schedule with today and locked days, begin day', (t) async {
    final e = await open(t, '/challenge/c7');
    expect(find.byKey(const Key('challenge-title')), findsOneWidget);
    expect(find.text('Day 3 of 7'), findsOneWidget);
    expect(find.text('43%'), findsOneWidget);
    expect(find.textContaining('1 grace day'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('day-4')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('day-4')), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('join-challenge')), 300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('join-challenge')));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('begin-day')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Begin day 4 (14 min)'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('crisis directory: region, lines with call and text actions, international list, grounding tip', (t) async {
    final e = await open(t, AppRoutes.crisisDirectory);
    expect(find.byKey(const Key('crisis-region')), findsOneWidget);
    expect(find.text('United States & Canada'), findsOneWidget);
    expect(find.text('Call 988'), findsOneWidget);
    expect(find.text('Text 988'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('crisis-tip')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('crisis-tip')), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('next sit: countdown, waiting by belt, intention is saved, reminder toggles', (t) async {
    final e = await open(t, AppRoutes.nextSit);
    expect(find.byKey(const Key('nextsit-kicker')), findsOneWidget);
    expect(find.textContaining('meditators waiting'), findsOneWidget);
    await t.tap(find.byKey(const Key('intent-Mindful stillness')));
    await settle(t);
    expect(e.today.intentions.values, contains('Mindful stillness'));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
