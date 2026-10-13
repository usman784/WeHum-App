import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/onboarding_store.dart';
import '../services/config_service.dart';
import 'painters.dart';

/// The app logo: the one uploaded in the CMS (Settings → Branding) when there is one, else the bundled ring.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<ConfigService>()) return BrandLogo(size: size);
    return Obx(() {
      final url = Get.find<ConfigService>().current.value?.branding.logoUrl ?? (Get.isRegistered<OnboardingStore>() ? Get.find<OnboardingStore>().brandLogo : null);
      if (url == null || url.isEmpty) return BrandLogo(size: size);
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CachedNetworkImage(imageUrl: url, width: size, height: size, fit: BoxFit.cover, fadeInDuration: const Duration(milliseconds: 250), errorWidget: (_, __, ___) => BrandLogo(size: size), placeholder: (_, __) => BrandLogo(size: size)),
      );
    });
  }
}

/// The app name from the CMS ("WeHum" by default).
String brandName() {
  final live = Get.isRegistered<ConfigService>() ? Get.find<ConfigService>().current.value?.branding.appName : null;
  if (live != null) return live;
  return Get.isRegistered<OnboardingStore>() ? Get.find<OnboardingStore>().brandName : 'WeHum';
}
