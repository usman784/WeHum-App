import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import '../core/services/onboarding_store.dart';
import '../core/realtime/realtime_coordinator.dart';
import '../core/config/env.dart';
import '../core/theme/theme_controller.dart';
import '../core/data/contracts/repositories.dart';
import '../core/data/models/activity.dart';
import '../core/data/models/bootstrap.dart';
import '../core/network/session_store.dart';
import '../core/realtime/socket_service.dart';
import '../core/services/access_service.dart';
import '../core/services/analytics_service.dart';
import '../core/services/auth_service.dart';
import '../core/services/catalog_service.dart';
import '../core/services/config_service.dart';
import '../core/services/crash_service.dart';
import '../core/services/download_service.dart';
import '../core/services/deep_links.dart';
import '../core/services/notification_service.dart';
import '../core/services/purchase_service.dart';
import '../core/services/sync_service.dart';
import 'routes/app_routes.dart';

/// Owns startup order and app lifecycle (spec §6.2, §6.3, §10):
/// session → bootstrap (+ catalog) in parallel → socket → device registration → outbox flush.
class AppController extends GetxService with WidgetsBindingObserver {
  AppController({
    required this.auth, required this.config, required this.access, required this.catalog, required this.socket, required this.sync,
    required this.notifications, required this.me, required this.crash, required this.session, required this.purchases,
  });
  final PurchaseService purchases;
  final AuthService auth;
  final ConfigService config;
  final AccessService access;
  final CatalogService catalog;
  final SocketService socket;
  final SyncService sync;
  final NotificationService notifications;
  final MeRepository me;
  final CrashService crash;
  final SessionStore session;

  final unread = 0.obs;
  String? _lastTz;
  bool started = false;
  StreamSubscription<Uri>? _links;
  Worker? _reconnected, _person;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // the socket coming (back) up is the best "we're online" signal: send whatever was queued offline
    _person = ever(auth.me, (m) {
      if (m != null && Get.isRegistered<OnboardingStore>()) Get.find<OnboardingStore>().adoptName(userId: m.id, serverName: m.firstName);
    });
    _reconnected = ever(socket.state, (s) {
      if (s == SocketState.connected) unawaited(sync.flush());
    });
  }

  /// Runs once per launch (splash). Returns true when the app may continue to its first screen.
  Future<void> startup() async {
    await Get.find<DownloadService>().init(); // index of downloaded media: playable offline from the first frame
    final me0 = await auth.ensureSession();
    if (me0.id.isNotEmpty) unawaited(purchases.configure(me0.id)); // after ensureSession, appUserID = backend user id (spec §9)
    final cat = catalog.load(); // stored copy first, so the library is there offline
    Bootstrap? b;
    try {
      b = await config.refresh();
    } catch (_) {
      // offline / backend down: the cached session and catalog still work (spec §10)
      offline.value = true;
    }
    await cat;
    access.setFromProfile(await _profileOrNull() ?? auth.profileFallback());
    crash.tag('plan', access.plan);
    if (b != null && !b.updateRequired && !b.maintenance) {
      unawaited(connectRealtime());
      unawaited(notifications.init().then((_) => notifications.registerDevice()));
      if (b.catalogVersion != catalog.version) unawaited(catalog.refresh());
    }
    unawaited(sync.flush());
    final analytics = Get.find<AnalyticsService>();
    await analytics.start();
    analytics.userProps(plan: access.plan, isGuest: access.isGuest.value, country: null, theme: Get.find<ThemeController>().mode.value.name, flavor: Env.flavor);
    started = true;
    lastBootstrap = b;
    _listenForLinks();
  }

  /// Universal links / custom scheme while the app runs, and the one that launched it.
  void _listenForLinks() {
    if (_links != null) return;
    try {
      final al = AppLinks();
      _links = al.uriLinkStream.listen((u) => openLink(u.toString()));
      al.getInitialLink().then((u) {
        if (u != null) openLink(u.toString());
      });
    } catch (_) {/* platform without link support (tests) */}
  }

  /// True when the last start could not reach the backend (cached content, banner "You're offline").
  final offline = false.obs;
  Bootstrap? lastBootstrap;

  Future<MeProfile?> _profileOrNull() async {
    try {
      return await me.me();
    } catch (_) {
      return null;
    }
  }

  /// The coordinator holds the listeners for `entitlement:changed`, `config:changed`, `catalog:changed`, `inbox:new`
  /// and `force:logout`. It is registered lazily, so it must be created here, before the socket can deliver anything:
  /// nothing else ever asks for it, and without this line those events arrive and nobody hears them.
  Future<void> connectRealtime() {
    if (Get.isRegistered<RealtimeCoordinator>()) Get.find<RealtimeCoordinator>();
    return socket.connect();
  }

  // ───────────── lifecycle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_onResume());
      case AppLifecycleState.paused:
        socket.onBackground();
        unawaited(Get.find<AnalyticsService>().onBackground());
      default:
        break;
    }
  }

  Future<void> _onResume() async {
    await socket.onForeground();
    unawaited(sync.flush());
    // time zone / DST change while away: tell the server so reminders and pushes are scheduled in the right zone (spec §10)
    try {
      final tz = (await FlutterTimezone.getLocalTimezone()).identifier;
      if (_lastTz != null && _lastTz != tz) await me.patch({'timezone': tz});
      _lastTz = tz;
    } catch (_) {}
  }

  // ───────────── server-driven
  /// Socket `force:logout` or an unrecoverable refresh failure: back to a fresh guest, downloads stay (spec §10).
  Future<void> onForceLogout(String reason) async {
    await notifications.onSignedOut();
    await auth.resetToGuest(keepAccountHint: reason != 'account_deleted');
    access.sdkPremium.value = false;
    Get.offAllNamed(AppRoutes.splash);
  }

  void openLink(String? link, {String? notificationId}) {
    final t = DeepLinks.parse(link);
    Get.toNamed(t.route, arguments: t.args);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _reconnected?.dispose();
    _person?.dispose();
    super.onClose();
  }
}
