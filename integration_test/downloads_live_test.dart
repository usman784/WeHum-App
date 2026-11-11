// Throwaway: opens Downloads on the simulator for a screenshot. Prints "DL <marker>".
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
  testWidgets('downloads', (t) async {
    app.bootstrap();
    await settle(t, 10000);
    Get.toNamed(AppRoutes.downloads);
    await settle(t, 4000);
    debugPrint('DL shot storageCard=${find.byKey(const Key('storage-card')).evaluate().isNotEmpty} localStorageText=${find.text('Local storage').evaluate().isNotEmpty} membersOnly=${find.byKey(const Key('members-only')).evaluate().isNotEmpty}');
    await settle(t, 5000);
    debugPrint('DL DONE');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
