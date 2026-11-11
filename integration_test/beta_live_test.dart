// Throwaway live check for beta access against a LOCAL backend: signs in as a free beta tester, then watches the app
// react while the admin API grants, removes and suspends access from outside. Prints "BETA <marker>" lines for a watcher.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/account_service.dart';
import 'package:meditation/core/services/auth_service.dart';

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> until(WidgetTester t, bool Function() cond, int seconds) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (cond()) return true;
    await t.pump(const Duration(milliseconds: 100));
  }
  return cond();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('beta access live', (t) async {
    app.bootstrap();
    await settle(t, 9000);
    final acc = Get.find<AccountService>();
    final access = Get.find<AccessService>();
    final auth = Get.find<AuthService>();
    void state(String m) => debugPrint('BETA $m member=${access.isMember} src=${access.entitlement.value.source} guest=${access.isGuest.value} me=${auth.me.value?.id} route=${Get.currentRoute}');

    final r = await acc.loginEmail(email: 'appqa004@testers.wehum.test', password: 'appqa004we');
    debugPrint('BETA login result=${r.runtimeType}');
    await settle(t, 5000);
    state('SIGNED-IN');
    debugPrint('BETA WAIT-GRANT');
    final on = await until(t, () => access.isMember, 600);
    await settle(t, 2500);
    state('AFTER-GRANT ok=$on');
    debugPrint('BETA WAIT-REMOVE');
    final off = await until(t, () => !access.isMember, 600);
    await settle(t, 2500);
    state('AFTER-REMOVE ok=$off');
    debugPrint('BETA WAIT-SUSPEND');
    final out = await until(t, () => auth.me.value?.id == null || access.isGuest.value, 600);
    await settle(t, 4000);
    state('AFTER-SUSPEND ok=$out');
    debugPrint('BETA DONE');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
