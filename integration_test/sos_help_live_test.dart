// Throwaway live check of the SoS "Need more help?" card on the simulator. Prints "SOS <marker>" lines; a shell watcher takes the screenshots.
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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('sos help', (t) async {
    app.bootstrap();
    await settle(t, 9000);
    Get.toNamed(AppRoutes.sosHowCanIHelp);
    await settle(t, 5000);
    debugPrint('SOS A-top crisisLink=${find.text('Crisis directory').evaluate().isNotEmpty} crisisCard=${find.byKey(const Key('sos-crisis')).evaluate().isNotEmpty}');
    await settle(t, 3000);
    for (var i = 0; i < 4; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -700)); // ensureVisible would wait for animations that never settle
      await settle(t, 600);
    }
    await settle(t, 2000);
    debugPrint('SOS B-help-card');
    await settle(t, 3000);
    await t.tap(find.text('Book a personal session'));
    await settle(t, 1200);
    debugPrint('SOS C-book-tapped');
    await settle(t, 3500);
    await settle(t, 5000); // snackbar gone
    await t.tap(find.byKey(const Key('sos-contact')));
    await settle(t, 600);
    debugPrint('SOS D-contact-tapped');
    await settle(t, 8000);
    debugPrint('SOS DONE');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
