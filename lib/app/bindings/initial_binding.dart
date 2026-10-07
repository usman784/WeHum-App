import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/config/env.dart';
import '../../core/data/api/api_repositories.dart';
import '../../core/data/api/auth_api.dart';
import '../../core/data/api/bootstrap_api.dart';
import '../../core/data/api/caching_media.dart';
import '../../core/audio/audio_engine.dart';
import '../../core/audio/engines.dart';
import '../../core/audio/recipe_engine.dart';
import '../../core/audio/local_media.dart';
import '../../core/data/contracts/auth_repository.dart';
import '../../core/data/contracts/bootstrap_repository.dart';
import '../../core/data/contracts/repositories.dart';
import 'dart:io';
import '../../core/audio/download_engine.dart';
import '../../core/data/local/app_database.dart';
import '../../core/services/download_service.dart';
import '../../core/data/mock/mock_repositories.dart';
import '../../core/network/api_client.dart';
import '../../core/network/session_store.dart';
import '../../core/realtime/live_service.dart';
import '../../core/realtime/lobby_service.dart';
import '../../core/realtime/presence_service.dart';
import '../../core/realtime/realtime_coordinator.dart';
import '../../core/realtime/socket_service.dart';
import '../../core/realtime/socket_transport.dart';
import '../../core/services/access_service.dart';
import '../../core/services/account_service.dart';
import '../../core/services/social_auth_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/inbox_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/crash_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/onboarding_store.dart';
import '../../core/services/purchase_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/services/time_service.dart';
import '../../core/theme/theme_controller.dart';
import '../app_controller.dart';
import '../routes/app_routes.dart';

/// Services are permanent; repositories are the API ones, or the mocks with USE_MOCKS=true (spec §6.1).
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final mocks = Env.useMocks;

    // ── infrastructure
    Get.put(ThemeController(), permanent: true);
    Get.put(OnboardingStore(), permanent: true);
    final crash = Get.put(CrashService(), permanent: true);
    final time = Get.put(TimeService(), permanent: true);
    Get.put(AnalyticsService(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);
    final kv = const KeychainKv();
    final store = SessionStore(kv);
    Get.put<SessionStore>(store, permanent: true);
    late final AuthService auth;
    final api = ApiClient(
      store,
      onSignedOut: () => Get.find<AppController>().onForceLogout('token_invalid'),
      onUpdateRequired: () => Get.offAllNamed(AppRoutes.updateRequired),
      onMaintenance: () => Get.offAllNamed(AppRoutes.maintenance),
    );
    Get.put<ApiClient>(api, permanent: true);
    Get.put<SecureKv>(kv, permanent: true);

    // ── repositories
    Get.put<AuthRepository>(mocks ? MockAuthRepository() : AuthApi(api, store), permanent: true);
    Get.put<BootstrapRepository>(mocks ? MockBootstrapRepository() : BootstrapApi(api), permanent: true);
    Get.put<TodayRepository>(mocks ? MockTodayRepository() : TodayApi(api), permanent: true);
    Get.put<CatalogRepository>(mocks ? MockCatalogRepository() : CatalogApi(api), permanent: true);
    final media = CachingMediaRepository(mocks ? MockMediaRepository() : MediaApi(api));
    Get.put<CachingMediaRepository>(media, permanent: true);
    Get.put<MediaRepository>(media, permanent: true);
    Get.put<AudioEngineFactory>(() => JustAudioEngine(), permanent: true);
    Get.put<RecipeEngineFactory>(() => RecipeEngine(clipFactory: () => JustClipPlayer()), permanent: true);
    Get.put<VideoEngineFactory>(() => VideoEngine(), permanent: true);
    Get.put<YoutubeEngineFactory>(() => YoutubeEngine(), permanent: true);
    Get.put<MeditationRepository>(mocks ? MockMeditationRepository() : MeditationApi(api), permanent: true);
    Get.put<MeRepository>(mocks ? MockMeRepository() : MeApi(api), permanent: true);
    Get.put<CommunityRepository>(mocks ? MockCommunityRepository() : CommunityApi(api), permanent: true);
    Get.put<RecipeRepository>(mocks ? MockRecipeRepository() : RecipeApi(api), permanent: true);
    Get.put<ComingSoonRepository>(mocks ? MockComingSoonRepository() : ComingSoonApi(api), permanent: true);
    Get.put<ProgramRepository>(mocks ? MockProgramRepository() : ProgramApi(api), permanent: true);
    Get.put<AnalyticsRepository>(mocks ? MockAnalyticsRepository() : AnalyticsApi(api), permanent: true);

    // ── services
    auth = Get.put(AuthService(Get.find(), store, crash, refreshToken: api.refreshAccessToken, cache: kv), permanent: true);
    Get.put(ConfigService(Get.find(), time), permanent: true);
    final access = Get.put(AccessService(), permanent: true);
    final downloads = Get.put(
      DownloadService(db: Get.find<AppDatabase>(), media: media, engine: DioDownloadEngine(), root: Get.find<Directory>(tag: 'downloads'), access: access, analytics: Get.find<AnalyticsService>()),
      permanent: true,
    );
    Get.put<LocalMedia>(downloads, permanent: true); // the player prefers a downloaded file

    Get.put(PurchaseService(PurchasesRc(), access, Get.find<AnalyticsService>(), syncEntitlement: () => Get.find<MeRepository>().syncEntitlement()), permanent: true);

    // ── realtime (spec §6.3)
    final socket = Get.put(
      SocketService(
        transportFactory: () => IoTransport(Env.socketUrl, () async {
          final info = await PackageInfo.fromPlatform();
          return {'token': store.accessToken, 'installId': await store.installId(), 'appVersion': info.version, 'platform': Env.platformName};
        }),
        refreshAccess: api.refreshAccessToken,
        onForceLogout: (r) => Get.find<AppController>().onForceLogout(r),
        onTimeSync: time.setOffset,
      )..attachTokenSource(() async => store.accessToken),
      permanent: true,
    );
    Get.put(LiveService(socket, restSnapshot: () => Get.find<TodayRepository>().live()), permanent: true);
    Get.put(PresenceService(socket), permanent: true);
    Get.put(LobbyService(socket, time), permanent: true);

    // the DB opens asynchronously; services that need it are created lazily on first use
    Get.lazyPut<CatalogService>(() => CatalogService(Get.find(), Get.find<AppDatabase>()), fenix: true);
    Get.lazyPut<InboxService>(() => InboxService(Get.find(), Get.find<AppDatabase>()), fenix: true);
    Get.lazyPut<SyncService>(() => SyncService(Get.find(), Get.find<AppDatabase>()), fenix: true);
    Get.lazyPut<NotificationService>(
      () => NotificationService(Get.find(), store, crash, onOpenLink: (l, {notificationId}) => Get.find<AppController>().openLink(l, notificationId: notificationId)),
      fenix: true,
    );
    Get.put<SocialAuth>(FirebaseSocialAuth(), permanent: true);
    Get.lazyPut<AccountService>(
      () => AccountService(
        auth: auth, repo: Get.find(), social: Get.find(), access: access, purchases: Get.find(), config: Get.find(), me: Get.find(), socket: socket,
        notifications: Get.find(), analytics: Get.find(),
      ),
      fenix: true,
    );
    Get.lazyPut<AppController>(
      () => AppController(
        auth: auth, config: Get.find(), access: access, catalog: Get.find(), socket: socket, sync: Get.find(), notifications: Get.find(),
        me: Get.find(), crash: crash, session: store, purchases: Get.find(),
      ),
      fenix: true,
    );
    Get.lazyPut<RealtimeCoordinator>(
      () => RealtimeCoordinator(
        socket,
        refreshBootstrap: () async {
          await Get.find<ConfigService>().refresh();
          final p = await Get.find<MeRepository>().me();
          access.setFromProfile(p);
        },
        refreshCatalog: () => Get.find<CatalogService>().refresh(),
        onInbox: (item) => Get.find<InboxService>().onSocket(item),
        onEntitlement: (e) {
          access.onSocket(e);
          downloads.purgeIfNotMember(); // downloads belong to the membership
        },
      ),
      fenix: true,
    );
  }
}
