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

  /// Built and kept in the code, but shown as "Coming soon" in v1 whatever the CMS flag says (client decision).
  /// Remove a key to ship it; tests clear this set to keep covering the real screens.
  static final Set<String> comingSoonInV1 = {'challenges', 'programs'};

  /// False for anything still coming soon in this version (programs have no server flag, only this switch).
  static bool shipped(String key) => !comingSoonInV1.contains(key);

  bool feature(String key) => shipped(key) && (current.value?.feature(key) ?? false);

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
