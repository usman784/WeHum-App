import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/favorites_service.dart';

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

/// The heart on the session page (the page has other hearts, e.g. "Write a dedication").
Finder heart(IconData i) => find.descendant(of: find.byKey(const Key('session-favorite')), matching: find.byIcon(i));

Future<void> close(WidgetTester t, TestEnv e) async {
  await t.pumpWidget(const SizedBox());
  await e.dispose();
}

void main() {
  testWidgets('member: the heart on a meditation favourites and un-favourites it', (t) async {
    final e = await open(t, '/session/s-sleep');
    final favorites = Get.find<FavoritesService>();
    expect(heart(Icons.favorite_border_rounded), findsOneWidget);
    expect(favorites.isFavorite('s-sleep'), isFalse);

    await t.tap(find.byKey(const Key('session-favorite')));
    await settle(t);
    expect(heart(Icons.favorite_rounded), findsOneWidget);
    expect(favorites.isFavorite('s-sleep'), isTrue);
    expect((await e.favoritesRepo.list()).map((s) => s.id), ['s-sleep']); // saved on the server side too

    await t.tap(find.byKey(const Key('session-favorite')));
    await settle(t);
    expect(heart(Icons.favorite_border_rounded), findsOneWidget);
    expect(favorites.isFavorite('s-sleep'), isFalse);
    expect(await e.favoritesRepo.list(), isEmpty);
    await close(t, e);
  });

  testWidgets('free user: the heart opens the membership screen and saves nothing', (t) async {
    final e = await open(t, '/session/s-sleep', member: false);
    await t.tap(find.byKey(const Key('session-favorite')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    expect(Get.find<FavoritesService>().items, isEmpty);
    expect(await e.favoritesRepo.list(), isEmpty);
    await close(t, e);
  });

  testWidgets('Favourites screen (member): empty state, then the list newest first, and the heart removes one', (t) async {
    final e = await open(t, AppRoutes.favorites);
    expect(find.byKey(const Key('favorites-empty')), findsOneWidget);
    expect(find.text('No favourites yet'), findsOneWidget);

    await e.favoritesRepo.set('s-sleep', on: true);
    await e.favoritesRepo.set('s-deep', on: true); // newest
    await Get.find<FavoritesService>().load();
    await settle(t);
    expect(find.byKey(const Key('favorites-list')), findsOneWidget);
    expect(t.getTopLeft(find.byKey(const Key('fav-s-deep'))).dy, lessThan(t.getTopLeft(find.byKey(const Key('fav-s-sleep'))).dy));
    expect(find.text('PREMIUM'), findsNothing); // a member sees no lock

    await t.tap(find.byKey(const Key('fav-remove-s-deep')));
    await settle(t);
    expect(find.byKey(const Key('fav-s-deep')), findsNothing);
    expect(find.byKey(const Key('fav-s-sleep')), findsOneWidget);
    expect((await e.favoritesRepo.list()).map((s) => s.id), ['s-sleep']);
    await close(t, e);
  });

  testWidgets('Favourites screen (free): the membership screen, never the list', (t) async {
    final e = await open(t, AppRoutes.favorites, member: false);
    expect(find.byKey(const Key('members-only')), findsOneWidget);
    expect(find.byKey(const Key('favorites-list')), findsNothing);
    await close(t, e);
  });

  testWidgets('You: a Favourites row for everyone, PREMIUM only for free users, opens the right place', (t) async {
    var e = await open(t, AppRoutes.you);
    await t.scrollUntilVisible(find.byKey(const Key('r-favorites')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Favourites'), findsOneWidget);
    await t.tap(find.byKey(const Key('r-favorites')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.favorites);
    await close(t, e);

    e = await open(t, AppRoutes.you, member: false);
    await t.scrollUntilVisible(find.byKey(const Key('r-favorites')), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('r-favorites')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.membershipPaywall);
    await close(t, e);
  });

  testWidgets('a failed read shows a retry, not a spinner forever; a failed toggle puts back only that heart', (t) async {
    final e = await open(t, AppRoutes.favorites);
    final favorites = Get.find<FavoritesService>();
    e.favoritesRepo.failing = true;
    await favorites.load();
    await settle(t);
    expect(find.byKey(const Key('favorites-error')), findsOneWidget);
    e.favoritesRepo.failing = false;
    await t.tap(find.text('Try again'));
    await settle(t);
    expect(find.byKey(const Key('favorites-empty')), findsOneWidget);

    final s = (await e.favoritesRepo.list()).isEmpty ? Get.find<CatalogService>().catalog.value!.session('s-sleep')! : throw StateError('unexpected');
    e.favoritesRepo.failing = true;
    expect(await favorites.toggle(s), FavoriteOutcome.failed);
    expect(favorites.isFavorite('s-sleep'), isFalse); // rolled back
    await close(t, e);
  });
}
