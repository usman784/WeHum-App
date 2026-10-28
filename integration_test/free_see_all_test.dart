// Sim flow against the real API: Today (free) → "Free for you" → See all opens the Library with the Free filter on.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/features/library/controllers/library_controllers.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Free for you → See all lands on the Library filtered to free', (t) async {
    app.bootstrap();
    await settle(t, 7000);
    Get.offAllNamed(AppRoutes.todayFree);
    await settle(t, 6000);
    await t.scrollUntilVisible(find.byKey(const Key('free-see-all')), 300, scrollable: find.byType(Scrollable).first);
    await settle(t, 6000); // screenshot window: Today with "Free for you · See all"
    await t.tap(find.byKey(const Key('free-see-all')));
    await settle(t, 8000); // Library, filtered
    expect(Get.currentRoute, AppRoutes.library);
    final lib = Get.find<LibraryController>();
    expect(lib.filters.value.type, 'free');
    expect(lib.filtered.every((s) => !s.isPremium), true);
    debugPrint('SEEALL filtered: ${lib.filtered.length} of ${lib.c?.sessions.length}');
  });
}
