import '../services/logger.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'socket_events.dart';
import 'socket_service.dart';

/// Routes the always-on server pushes (spec §6.3 "Always (auto)": `entitlement:changed`, `inbox:new`,
/// `config:changed`, `catalog:changed`, `force:logout`) to the services that own the data.
class RealtimeCoordinator extends GetxService {
  RealtimeCoordinator(this._socket, {
    required this.refreshBootstrap,
    required this.refreshCatalog,
    required this.onInbox,
    required this.onEntitlement,
    this.catalogDebounce = const Duration(seconds: 10),
  });
  final SocketService _socket;
  final Future<void> Function() refreshBootstrap;
  final Future<void> Function() refreshCatalog;
  final void Function(Map<String, dynamic> item) onInbox;
  final void Function(EntitlementChanged e) onEntitlement;
  final Duration catalogDebounce;

  final entitlement = Rxn<EntitlementChanged>();
  final subs = <StreamSubscription<dynamic>>[];
  Timer? _catalogTimer;
  int refreshes = 0, catalogRefreshes = 0; // visible to tests

  @override
  void onInit() {
    super.onInit();
    subs.add(_socket.on(SocketEvents.entitlementChanged, EntitlementChanged.fromJson).listen((e) {
      entitlement.value = e;
      onEntitlement(e);
      refreshes++;
      refreshBootstrap(); // entitlement and founding numbers live in bootstrap
    }));
    subs.add(_socket.on(SocketEvents.configChanged, (j) => j).listen((_) {
      refreshes++;
      refreshBootstrap();
    }));
    subs.add(_socket.on(SocketEvents.catalogChanged, (j) => j).listen((j) {
      logd('socket', 'catalog:changed $j → refresh in ${catalogDebounce.inSeconds}s');
      _catalogTimer?.cancel(); // debounced: a CMS bulk edit sends many events
      _catalogTimer = Timer(catalogDebounce, () {
        catalogRefreshes++;
        refreshCatalog();
      });
    }));
    subs.add(_socket.on(SocketEvents.inboxNew, (j) => j).listen((j) {
      final item = j['item'];
      if (item is Map) onInbox(item.cast<String, dynamic>());
    }));
  }

  @override
  void onClose() {
    for (final s in subs) {
      s.cancel();
    }
    _catalogTimer?.cancel();
    super.onClose();
  }
}
