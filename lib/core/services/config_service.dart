import 'package:get/get.dart';
import 'onboarding_store.dart';
import '../data/contracts/bootstrap_repository.dart';
import '../data/models/bootstrap.dart';
import 'time_service.dart';

/// Remote config and feature flags from `/v1/bootstrap`; refreshed on socket `config:changed` (P4).
class ConfigService extends GetxService {
  ConfigService(this._repo, this._time);
  final BootstrapRepository _repo;
  final TimeService _time;

  final current = Rxn<Bootstrap>();

  bool feature(String key) => current.value?.feature(key) ?? false;

  Future<Bootstrap> refresh() async {
    final b = await _repo.bootstrap();
    current.value = b;
    if (Get.isRegistered<OnboardingStore>()) {
      Get.find<OnboardingStore>().brandName = b.branding.appName;
      Get.find<OnboardingStore>().brandLogo = b.branding.logoUrl;
    }
    _time.sync(b.serverTime);
    return b;
  }
}
