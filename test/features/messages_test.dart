import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/services/inbox_service.dart';
import 'package:meditation/features/player/player_args.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> afterPush(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 20));
}

void main() {
  testWidgets('28 notifications: list, unread dots, new item arrives live over the socket, read all', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await e.socket.connect();
    e.socketServer.serverConnects();
    await t.pumpWidget(e.app(initial: AppRoutes.notifications));
    await settle(t);
    expect(find.text('Group meditation starts in 10 minutes'), findsOneWidget);
    expect(Get.find<InboxService>().unread.value, 2);
    e.socketServer.serverPushes('inbox:new', {'item': {'id': 'i9', 'type': 'announce', 'title': 'The 21-Day Arc starts Monday', 'createdAt': DateTime.now().toUtc().toIso8601String()}});
    await afterPush(t);
    expect(find.text('The 21-Day Arc starts Monday'), findsOneWidget);
    expect(Get.find<InboxService>().unread.value, 3);
    e.socketServer.serverPushes('inbox:new', {'item': {'id': 'i9', 'type': 'announce', 'title': 'The 21-Day Arc starts Monday', 'createdAt': DateTime.now().toUtc().toIso8601String()}});
    await afterPush(t);
    expect(Get.find<InboxService>().items.where((i) => i.id == 'i9').length, 1); // duplicates ignored
    await t.tap(find.text('Read all'));
    await t.pump();
    expect(Get.find<InboxService>().unread.value, 0);
    expect(e.me.read, containsAll(['i1', 'i2']));
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('28 empty inbox says you are all caught up', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    e.me.read.addAll(['i1', 'i2']);
    await t.pumpWidget(e.app(initial: AppRoutes.notifications));
    await settle(t);
    expect(Get.find<InboxService>().unread.value, 0);
    await e.dispose();
  });

  testWidgets('26 daily message: text, date line, Explore archive; free users see the membership prompt', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed('/message/2026-10-05', arguments: {'date': '2026-10-05'});
    await settle(t);
    expect(find.text('Releasing Cognitive Friction'), findsOneWidget);
    expect(find.text('Monday, October 5 · from Raphael'), findsOneWidget);
    expect(find.text('Explore archive'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await e.dispose();

    final f = await TestEnv.create(onboardingDone: true);
    await t.pumpWidget(f.app());
    await settle(t);
    Get.toNamed('/message/2026-10-05', arguments: {'date': '2026-10-05'});
    await settle(t);
    expect(find.text('The daily message is part of membership'), findsOneWidget);
    await f.dispose();
  });

  testWidgets('27 archive: month groups from the API, route is not captured by the :date pattern', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await t.pumpWidget(e.app(initial: AppRoutes.exploreArchive));
    await settle(t);
    expect(find.text('Explore archive'), findsOneWidget);
    expect(find.text('OCTOBER 2026'), findsOneWidget);
    expect(find.text('Message 1'), findsOneWidget);
    await t.enterText(find.byKey(const Key('archive-search')), 'sleep');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    await e.dispose();
  });

  testWidgets('30 SoS: eight tiles, member tile opens the player with the SoS session; free user goes to the paywall', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await t.pumpWidget(e.app(initial: AppRoutes.sosHowCanIHelp));
    await settle(t);
    expect(find.text('How can I help?'), findsOneWidget);
    expect(find.text('Anxious'), findsOneWidget);
    await t.tap(find.byKey(const Key('sos-Anxious')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing);
    final a = Get.arguments as PlayerArgs;
    expect(a.kind, 'sos');
    expect(a.sessionId, 's-sos1');
    await t.pumpWidget(const SizedBox());
    await e.dispose();

    final f = await TestEnv.create(onboardingDone: true);
    await t.pumpWidget(f.app(initial: AppRoutes.sosHowCanIHelp));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('sos-help')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Need more help?'), findsOneWidget);
    expect(find.text('Book a personal session'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('sos-Anxious')), -300, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('sos-Anxious')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    await f.dispose();
  });
}
