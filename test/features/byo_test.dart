import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/data/mock/mock_data.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/data/models/content.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/features/byo/byo_controller.dart';
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/player/player_args.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<TestEnv> open(WidgetTester t, String route) async {
  phone(t);
  final e = await TestEnv.create(member: true, onboardingDone: true);
  await Get.find<CatalogService>().load();
  await t.pumpWidget(e.app(initial: route));
  await settle(t);
  return e;
}

void main() {
  testWidgets('39 build: choices change the summary; Build it opens the player with a custom recipe (no skip buttons)', (t) async {
    final e = await open(t, AppRoutes.buildYourOwn);
    expect(find.text('15 min · bells'), findsOneWidget);
    await t.tap(find.text('30 min'));
    await t.pump();
    await t.tap(find.text('Gentle opening'));
    await t.pump();
    await t.tap(find.text('Soft rain'));
    await t.pump();
    expect(find.text('30 min · Gentle opening · Soft rain · bells'), findsOneWidget);
    expect(find.byKey(const Key('level')), findsOneWidget);
    await t.tap(find.byKey(const Key('byo-build')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing);
    final a = Get.arguments as PlayerArgs;
    expect(a.kind, 'custom');
    expect(a.recipe!.lengthMin, 30);
    expect(a.recipe!.openingId, 'b-open');
    expect(a.recipe!.soundId, 'b-rain');
    expect(a.durationSec, 1800);
    expect(find.byKey(const Key('fwd15')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('39 options whose sounds are missing are disabled with a message', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await Get.find<CatalogService>().seed(Catalog(version: 5, themes: MockData.themes, sessions: MockData.catalog.sessions));
    await t.pumpWidget(e.app(initial: AppRoutes.buildYourOwn));
    await settle(t);
    expect(find.text('Openings are not available yet.'), findsOneWidget);
    expect(find.text('Background sounds are not available yet.'), findsOneWidget);
    await e.dispose();
  });

  testWidgets('39 Save asks for a name and stores the recipe; it then shows in My Meditations (38), plays on one tap, deletes with confirmation', (t) async {
    final e = await open(t, AppRoutes.buildYourOwn);
    await t.tap(find.byKey(const Key('byo-save')));
    await settle(t);
    await t.enterText(find.byKey(const Key('byo-name')), 'Sunday morning');
    await t.tap(find.byKey(const Key('byo-name-ok')));
    await settle(t);
    expect(e.recipes.items.single.name, 'Sunday morning');
    expect(e.recipes.items.single.lengthMin, 15);
    Get.delete<ByoController>(force: true);
    Get.offNamed(AppRoutes.myMeditations);
    await settle(t);
    expect(find.text('Sunday morning'), findsOneWidget);
    await t.tap(find.byKey(Key('recipe-${e.recipes.items.single.id}')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing);
    expect((Get.arguments as PlayerArgs).recipe!.name, 'Sunday morning');
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('38 My Meditations empty state offers Build a new one', (t) async {
    final e = await open(t, AppRoutes.myMeditations);
    expect(find.text('Nothing saved yet'), findsOneWidget);
    expect(find.text('Build a new one'), findsOneWidget);
    await e.dispose();
  });

  testWidgets('40 advanced: add blocks, counts clamp 1–21, silence entry, summary, share creates the link', (t) async {
    final e = await open(t, AppRoutes.buildYourOwnAdvanced);
    final ctrl = Get.find<ByoController>();
    await t.tap(find.byKey(const Key('add-block')));
    await settle(t);
    await t.tap(find.byKey(const Key('add-b-om')));
    await settle(t);
    expect(find.text('OM'), findsWidgets);
    for (var i = 0; i < 25; i++) {
      ctrl.setCount(0, (ctrl.blocks[0]['count'] as int) + 1);
    }
    expect(ctrl.blocks[0]['count'], 21);
    ctrl.setCount(0, 0);
    expect(ctrl.blocks[0]['count'], 1);
    ctrl.addSilence();
    ctrl.addBlock('b-open');
    ctrl.reorder(2, 0);
    expect(ctrl.blocks.map((b) => b['type'] == 'silence' ? 's' : b['blockId']).toList(), ['b-open', 'b-om', 's']);
    expect(ctrl.plan!.totalSec, 900);
    await t.runAsync(() => ctrl.save('Sunday OM'));
    expect(e.recipes.items.single.blocks.length, 3);
    await t.pumpWidget(const SizedBox());
    Get.delete<ByoController>(force: true);
    await e.dispose();
  });

  test('a shared link prefills the builder as a copy', () async {
    final e = await TestEnv.create(member: true);
    await Get.find<CatalogService>().load();
    e.recipes.items.add(const Recipe(id: 'shared1', name: 'Shared one', lengthMin: 20, soundId: 'b-rain', soundLevel: 30));
    final c = ByoController();
    await c.loadShared('abc23');
    expect(c.name.value, 'Shared one');
    expect(c.length.value, 20);
    expect(c.soundLevel.value, 30);
    expect(c.editingId, isNull); // saving creates the person's own copy
    await e.dispose();
  });

  group('custom meditation in the player', () {
    test('block URLs are fetched, the engine opens a RecipeSource with the exact length, no seeking', () async {
      final e = await TestEnv.create(member: true);
      await Get.find<CatalogService>().load();
      const recipe = Recipe(id: '', name: 'Mine', lengthMin: 10, openingId: 'b-open', soundId: 'b-rain', bells: RecipeBells());
      final ctrl = PlayerController(
        const PlayerArgs(kind: 'custom', title: 'Mine', recipe: recipe, durationSec: 600, lengthMin: 10),
        engine: e.engine, media: Get.find(), presence: Get.find(), sync: Get.find(), analytics: Get.find(), catalog: () => Get.find<CatalogService>().catalog.value);
      ctrl.onInit();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final src = e.engine.opened.single.src as RecipeSource;
      expect(src.plan.totalSec, 600);
      expect(src.urls.keys, {'b-open', 'b-rain'});
      expect(src.bellUrl, startsWith('asset:'));
      expect(ctrl.recorder.kind, 'custom');
      ctrl.onClose();
      await e.dispose();
    });
  });
}
