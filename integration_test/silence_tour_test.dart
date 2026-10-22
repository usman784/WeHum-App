// Silence Room on a simulator, against a running backend: the live map + "where people are meditating" (socket
// `silence:live`), then a meditation with the opening bell, the 3-second gap and the timer. Screenshots go to SHOTS_DIR.
//   flutter drive --flavor prod --driver=test_driver/integration_test.dart --target=integration_test/silence_tour_test.dart \
//     -d <sim id> --dart-define-from-file=<env with API_BASE_URL/SOCKET_URL>
// The signed-in account must be a member (the Silence Room is a member feature).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('silence room tour', (t) async {
    app.bootstrap();
    await settle(t, 6000);
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name, [int wait = 1200]) async {
      await settle(t, wait);
      await binding.takeScreenshot(name);
    }

    Get.toNamed(AppRoutes.silenceRoomSetup);
    await shot('s01_setup_top', 3000);
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const Key('silence-where')), 300, scrollable: list);
    await t.drag(list, const Offset(0, -200));
    await shot('s02_where_people_are_meditating');
    await shot('s03_where_live_update', 9000); // the socket moves the map and the list (no reload)
    await t.scrollUntilVisible(find.byKey(const Key('silence-enter')), 300, scrollable: list);
    await shot('s04_begin_meditation');

    await t.tap(find.byKey(const Key('silence-enter')));
    await settle(t, 500);
    await binding.takeScreenshot('s05_bell_then_begins_in');
    await settle(t, 1000);
    await binding.takeScreenshot('s06_begins_in_countdown');
    await settle(t, 2600);
    await t.tapAt(const Offset(200, 300)); // wake the controls
    await shot('s07_meditation_started', 800);
    await settle(t, 6000);
    await t.tapAt(const Offset(200, 300));
    await shot('s08_running_live_countries', 800);
    await t.tap(find.byKey(const Key('silence-end')));
    await settle(t, 2000);
  });
}
