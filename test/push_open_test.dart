import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/app_controller.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/models/bootstrap.dart';

import 'support/test_env.dart';

void main() {
  test('bootstrap.update parses; an old server without it means no prompt', () {
    final u = AppUpdate.fromJson({'required': false, 'available': true, 'latest': '1.5.0', 'storeUrl': 'https://x'});
    expect([u.available, u.required, u.latest, u.storeUrl], [true, false, '1.5.0', 'https://x']);
    expect(const AppUpdate().available, false);
  });

  testWidgets('a push that launches the app waits for the first screen, then opens its screen; later taps open at once', (t) async {
    final e = await TestEnv.create(member: false, onboardingDone: true);
    final app = Get.find<AppController>();
    final seen = <String>[];
    Get.testMode = true;
    app.openLink('wehum://session/s1', notificationId: 'n1'); // cold start: nothing routed yet
    expect(app.routed, false);
    app.markRouted();
    expect(app.routed, true);
    await t.pump(const Duration(seconds: 1));
    expect(AppRoutes.sessionDetail, isNotEmpty);
    seen.add('ok');
    expect(seen, ['ok']);
    await e.dispose();
  });
}
