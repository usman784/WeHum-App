import 'package:get/get.dart';
import '../../core/config/env.dart';
import '../../core/data/api/auth_api.dart';
import '../../core/data/api/bootstrap_api.dart';
import '../../core/data/contracts/auth_repository.dart';
import '../../core/data/contracts/bootstrap_repository.dart';
import '../../core/data/mock/mock_repositories.dart';
import '../../core/network/api_client.dart';
import '../../core/network/session_store.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/crash_service.dart';
import '../../core/services/time_service.dart';
import '../../core/theme/theme_controller.dart';
import '../routes/app_routes.dart';

/// Services are permanent; repositories are the API ones, or the mocks with USE_MOCKS=true (spec §6.1).
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ThemeController(), permanent: true);
    Get.put(CrashService(), permanent: true);
    Get.put(AnalyticsService(), permanent: true);
    Get.put(TimeService(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);

    final store = SessionStore(const KeychainKv());
    Get.put<SessionStore>(store, permanent: true);
    final api = ApiClient(
      store,
      onSignedOut: () => Get.find<AuthService>().ensureSession(),
      onUpdateRequired: () => Get.offAllNamed(AppRoutes.updateRequired),
      onMaintenance: () => Get.offAllNamed(AppRoutes.maintenance),
    );
    Get.put<ApiClient>(api, permanent: true);

    Get.put<AuthRepository>(Env.useMocks ? MockAuthRepository() : AuthApi(api, store), permanent: true);
    Get.put<BootstrapRepository>(Env.useMocks ? MockBootstrapRepository() : BootstrapApi(api), permanent: true);

    Get.put(AuthService(Get.find(), store, Get.find()), permanent: true);
    Get.put(ConfigService(Get.find(), Get.find()), permanent: true);
  }
}
