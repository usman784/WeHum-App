import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/app_controller.dart';
import 'package:meditation/core/realtime/realtime_coordinator.dart';
import 'package:meditation/core/realtime/socket_events.dart';

import '../support/test_env.dart';

void main() {
  testWidgets('connecting creates the lazily registered socket listeners: catalog, config, entitlement and inbox events are heard', (t) async {
    final e = await TestEnv.create(member: false, onboardingDone: true);
    // exactly like the app's binding: registered lazily, and nothing else ever asks for it
    await Get.delete<RealtimeCoordinator>(force: true);
    var built = 0, catalog = 0, bootstrap = 0;
    final inbox = <Map<String, dynamic>>[];
    EntitlementChanged? ent;
    Get.lazyPut<RealtimeCoordinator>(() {
      built++;
      return RealtimeCoordinator(e.socket,
          refreshBootstrap: () async => bootstrap++, refreshCatalog: () async => catalog++, onInbox: inbox.add, onEntitlement: (x) => ent = x, catalogDebounce: const Duration(milliseconds: 50));
    }, fenix: true);
    expect(built, 0);

    await Get.find<AppController>().connectRealtime();
    e.socketServer.serverConnects();
    await t.pump();
    expect(built, 1, reason: 'without the coordinator the events below arrive and nobody handles them');

    e.socketServer.serverPushes('catalog:changed', {'version': 6});
    await t.pump(const Duration(milliseconds: 80));
    expect(catalog, 1);
    e.socketServer.serverPushes('config:changed', {'key': 'features', 'version': 3});
    await t.pump();
    expect(bootstrap, 1);
    e.socketServer.serverPushes('entitlement:changed', {'active': true, 'productId': 'wehum_annual', 'periodType': 'trial', 'expiresAt': '2026-11-06T20:32:13.157Z', 'billingIssue': false});
    await t.pump();
    expect(ent?.active, true);
    e.socketServer.serverPushes('inbox:new', {'item': {'id': 'n1', 'title': 'Hello', 'body': 'From Raphael', 'createdAt': '2026-10-08T06:00:00Z'}}); // the server's shape
    await t.pump();
    expect(inbox.single['id'], 'n1');
    await e.dispose();
  });
}
