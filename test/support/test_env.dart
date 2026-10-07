import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'dart:io';
import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' show WidgetTester, addTearDown;
import 'package:get/get.dart';
import 'package:meditation/app/app_controller.dart';
import 'package:meditation/app/routes/app_pages.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/audio/engines.dart';
import 'package:meditation/core/audio/recipe_engine.dart';
import 'package:meditation/core/audio/download_engine.dart';
import 'package:meditation/core/audio/local_media.dart';
import 'package:meditation/core/services/download_service.dart';
import 'package:meditation/core/data/api/caching_media.dart';
import 'package:meditation/core/data/contracts/auth_repository.dart';
import 'package:meditation/core/data/contracts/bootstrap_repository.dart';
import 'package:meditation/core/data/contracts/repositories.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/network/session_store.dart';
import 'package:meditation/core/realtime/live_service.dart';
import 'package:meditation/core/realtime/lobby_service.dart';
import 'package:meditation/core/realtime/presence_service.dart';
import 'package:meditation/core/realtime/realtime_coordinator.dart';
import 'package:meditation/core/realtime/socket_service.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/account_service.dart';
import 'package:meditation/core/services/auth_service.dart';
import 'package:meditation/core/services/social_auth_service.dart';
import 'package:meditation/core/services/catalog_service.dart';
import 'package:meditation/core/services/config_service.dart';
import 'package:meditation/core/services/connectivity_service.dart';
import 'package:meditation/core/services/inbox_service.dart';
import 'package:meditation/core/services/crash_service.dart';
import 'package:meditation/core/services/notification_service.dart';
import 'package:meditation/core/services/onboarding_store.dart';
import 'package:meditation/core/services/purchase_service.dart';
import 'package:meditation/core/services/sync_service.dart';
import 'package:meditation/core/services/time_service.dart';
import 'package:meditation/core/theme/app_theme.dart';
import 'package:meditation/core/theme/theme_controller.dart';

import '../core/fake_adapter.dart';
import 'fonts.dart';
import '../core/purchase_service_test.dart' show FakeRc;
import '../player/fake_audio_engine.dart';
import '../realtime/fake_transport.dart';

/// Notification service without Firebase: records what the app asked for.
class FakeNotifications extends NotificationService {
  FakeNotifications(super.me, super.s, super.c) : super(onOpenLink: (_, {notificationId}) {});
  bool grant = true;
  final calls = <String>[];
  @override
  Future<void> init() async => calls.add('init');
  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    permission.value = grant ? PushPermission.granted : PushPermission.denied;
    return grant;
  }

  @override
  Future<void> registerDevice() async => calls.add('registerDevice');
  @override
  Future<void> onSignedOut() async => calls.add('signedOut');
  @override
  Future<void> scheduleDailyReminder(String hhmm, {String? name}) async => calls.add('daily:$hhmm:$name');
  @override
  Future<void> cancelDailyReminder() async => calls.add('cancelDaily');
  @override
  Future<void> scheduleGroupReminder(DateTime startsAtUtc, {int minutesBefore = 10}) async => calls.add('group');
  @override
  Future<void> cancelGroupReminder() async => calls.add('cancelGroup');
  @override
  Future<void> scheduleEndBell(DateTime atUtc) async => calls.add('bell');
  @override
  Future<void> cancelEndBell() async => calls.add('cancelBell');
}

/// Writes a tiny file instead of downloading.
class FakeDownloadEngine implements DownloadEngine {
  @override
  Future<int> download(String url, String path, {int resumeFrom = 0, void Function(int, int)? onProgress, CancelToken? cancel}) async {
    await File(path).writeAsBytes(List.filled(1000, 1));
    onProgress?.call(1000, 1000);
    return 1000;
  }
}

/// Connectivity without platform streams: always online unless a test says otherwise.
class TestConnectivity extends ConnectivityService {
  bool up = true;
  @override
  Future<bool> reachable() async => up;
  @override
  // ignore: must_call_super
  void onInit() {}
}

class FakeSocialAuth implements SocialAuth {
  String? googleToken = 'google-firebase-token', appleToken = 'apple-firebase-token';
  bool cancel = false;
  int signOuts = 0;
  @override
  Future<SocialCredential> google() async {
    if (cancel) throw SocialAuthCancelled();
    return SocialCredential(provider: 'google', idToken: googleToken!, firstName: 'Lena');
  }

  @override
  Future<SocialCredential> apple() async {
    if (cancel) throw SocialAuthCancelled();
    return SocialCredential(provider: 'apple', idToken: appleToken!, firstName: 'Lena');
  }

  @override
  Future<void> signOut() async => signOuts++;
}

/// Everything the screens need, backed by mocks, an in-memory database and a fake socket server.
class TestEnv {
  TestEnv._();
  late FakeTransport socketServer;
  late AppDatabase db;
  late MockTodayRepository today;
  late MockMeRepository me;
  late MockMeditationRepository meditations;
  late MockCommunityRepository community;
  late MockRecipeRepository recipes;
  late FakeRc rc;
  late FakeNotifications notifications;
  late MemoryBox prefs;
  late AccessService access;
  late SocketService socket;
  late FakeAudioEngine engine;
  late DownloadService downloads;
  late Directory dlDir;
  late MockAuthRepository authRepo;
  late FakeSocialAuth social;

  static Future<TestEnv> create({bool member = false, bool onboardingDone = false, Map<String, Object?> prefs = const {}}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    await loadAppFonts();
    Get.reset();
    final e = TestEnv._();
    e.socketServer = FakeTransport();
    e.db = AppDatabase.memory();
    e.prefs = MemoryBox()..map.addAll(prefs);
    if (onboardingDone) e.prefs.map['onboarding_done'] = true;
    final kv = MemoryKv();
    final store = SessionStore(kv);
    Get.put<SessionStore>(store);
    Get.put<SecureKv>(kv);
    Get.put<AppDatabase>(e.db);
    Get.put(ThemeController(load: () => null, save: (_) {}));
    Get.put(OnboardingStore(e.prefs));
    final crash = Get.put(CrashService());
    final time = Get.put(TimeService());
    final analytics = Get.put(AnalyticsService());
    Get.put<ConnectivityService>(TestConnectivity());
    e.today = MockTodayRepository(member: member);
    e.me = MockMeRepository()..profile = MeProfile(id: 'mock-user', firstName: 'Marcus', entitlement: Entitlement(active: member));
    e.meditations = MockMeditationRepository();
    e.community = MockCommunityRepository();
    e.recipes = MockRecipeRepository();
    e.authRepo = MockAuthRepository();
    Get.put<AuthRepository>(e.authRepo);
    Get.put<BootstrapRepository>(MockBootstrapRepository(member: member));
    Get.put<TodayRepository>(e.today);
    Get.put<CatalogRepository>(MockCatalogRepository());
    final cachingMedia = CachingMediaRepository(MockMediaRepository());
    Get.put<CachingMediaRepository>(cachingMedia);
    Get.put<MediaRepository>(cachingMedia);
    e.engine = FakeAudioEngine();
    Get.put<AudioEngineFactory>(() => e.engine);
    Get.put<RecipeEngineFactory>(() => e.engine);
    Get.put<VideoEngineFactory>(() => e.engine);
    Get.put<YoutubeEngineFactory>(() => e.engine);
    e.dlDir = Directory.systemTemp.createTempSync('wehum-test-dl'); // sync: real async IO never completes inside a widget test
    e.downloads = DownloadService(db: e.db, media: Get.find<MediaRepository>(), engine: FakeDownloadEngine(), root: e.dlDir, access: AccessService(), analytics: null);
    Get.put<DownloadService>(e.downloads);
    Get.put<LocalMedia>(e.downloads);
    Get.put<MeditationRepository>(e.meditations);
    Get.put<MeRepository>(e.me);
    Get.put<CommunityRepository>(e.community);
    Get.put<RecipeRepository>(e.recipes);
    Get.put<ProgramRepository>(MockProgramRepository());
    Get.put<AnalyticsRepository>(MockAnalyticsRepository());
    final auth = Get.put(AuthService(Get.find(), store, crash, device: (id) async => DeviceInfoDto(installId: id, platform: 'ios', appVersion: '1.0.0', timezone: 'UTC'), cache: kv));
    Get.put(ConfigService(Get.find(), time));
    e.access = Get.put(AccessService());
    e.access.entitlement.value = Entitlement(active: member);
    e.rc = FakeRc();
    final purchases = Get.put(PurchaseService(e.rc, e.access, analytics, syncEntitlement: () async {}));
    await purchases.configureForTest('mock-user');
    e.socket = Get.put(SocketService(transportFactory: () => e.socketServer, refreshAccess: () async => true, onTimeSync: time.setOffset));
    Get.put(LiveService(e.socket, restSnapshot: () => Get.find<TodayRepository>().live()));
    Get.put(PresenceService(e.socket));
    Get.put(LobbyService(e.socket, time));
    Get.put(CatalogService(Get.find(), e.db));
    Get.put(SyncService(Get.find(), e.db));
    Get.put(InboxService(e.me, e.db));
    e.notifications = Get.put<NotificationService>(FakeNotifications(e.me, store, crash)) as FakeNotifications;
    Get.put(AppController(auth: auth, config: Get.find(), access: e.access, catalog: Get.find(), socket: e.socket, sync: Get.find(), notifications: e.notifications, me: e.me, crash: crash, session: store, purchases: purchases));
    e.social = FakeSocialAuth();
    Get.put<SocialAuth>(e.social);
    Get.put(AccountService(auth: auth, repo: e.authRepo, social: e.social, access: e.access, purchases: purchases, config: Get.find(), me: e.me, socket: e.socket, notifications: e.notifications, analytics: analytics));
    Get.put(RealtimeCoordinator(e.socket, refreshBootstrap: () async {}, refreshCatalog: () async {}, onInbox: (i) => Get.find<InboxService>().onSocket(i), onEntitlement: e.access.onSocket));
    return e;
  }

  Widget app({String initial = AppRoutes.splash}) => GetMaterialApp(
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        initialRoute: initial,
        getPages: AppPages.pages,
      );

  Future<void> dispose() async {
    await db.close();
    if (dlDir.existsSync()) dlDir.deleteSync(recursive: true);
  }
}

/// iPhone-sized window (390×844 at 3×) so buttons are on screen like on a real phone.
void phone(WidgetTester t, {double scale = 1}) {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
