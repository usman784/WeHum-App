// Throwaway live check of the location flow on the simulator (prod flavor). PHASE=onboard|synced|settings.
// The OS permission state is set from outside with `xcrun simctl privacy`; prints "LOC <marker>" lines.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/data/contracts/repositories.dart';
import 'package:meditation/core/services/location_service.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('PHASE', defaultValue: 'onboard');
  testWidgets('location $phase', (t) async {
    app.bootstrap();
    await settle(t, 9000);
    Future<void> country(String m) async => debugPrint('LOC $m country=${(await Get.find<MeRepository>().me()).country} perm=${await Get.find<LocationService>().status()}');
    await country('START');
    if (phase == 'onboard') {
      Get.toNamed(AppRoutes.setup4Location);
      await settle(t, 2000);
      debugPrint('LOC ON-PAGE title=${find.byKey(const Key('location-title')).evaluate().isNotEmpty}');
      await t.tap(find.text('Allow location and continue'));
      await settle(t, 15000); // the OS dialog is on screen now
      debugPrint('LOC AFTER-TAP route=${Get.currentRoute}');
    } else if (phase == 'synced') {
      await settle(t, 12000); // the shell grants location + sets the position meanwhile
      await Get.find<LocationService>().sync(force: true);
      await settle(t, 3000);
    } else {
      Get.find<LocationService>().promptIfNeeded(force: true);
      await settle(t, 12000); // our Settings dialog is on screen now
      debugPrint('LOC DIALOG-OPEN=${Get.isDialogOpen}');
    }
    await country('END');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
