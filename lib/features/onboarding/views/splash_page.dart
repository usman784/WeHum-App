import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// 01 Splash. P0: ensures the guest session and loads bootstrap, then routes by the result.
/// The real onboarding decision (intro vs Today) arrives in P2.
class SplashController extends GetxController {
  final failure = Rxn<ErrorCode>();

  @override
  void onReady() {
    super.onReady();
    start();
  }

  Future<void> start() async {
    failure.value = null;
    try {
      await Get.find<AuthService>().ensureSession();
      final b = await Get.find<ConfigService>().refresh();
      if (b.updateRequired) {
        Get.offAllNamed(AppRoutes.updateRequired);
      } else if (b.maintenance) {
        Get.offAllNamed(AppRoutes.maintenance);
      } else {
        Get.offAllNamed(AppRoutes.intro1Welcome);
      }
    } catch (e) {
      failure.value = ApiClient.map(e).code;
    }
  }
}

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(SplashController());
    return Scaffold(
      body: Center(
        child: Obx(() => Column(mainAxisSize: MainAxisSize.min, children: [
              SvgPicture.asset('assets/brand/logo.svg', width: 96, colorFilter: ColorFilter.mode(context.colors.ember, BlendMode.srcIn)),
              const SizedBox(height: 16),
              Text('WeHum', style: AppText.heroTitle.copyWith(color: context.colors.textPrimary)),
              if (c.failure.value != null) ...[
                const SizedBox(height: 24),
                Text(c.failure.value == ErrorCode.network ? "You're offline" : 'Something went wrong', style: AppText.body.copyWith(color: context.colors.textSecondary)),
                TextButton(key: const Key('splash-retry'), onPressed: c.start, child: const Text('Try again')),
              ],
            ])),
      ),
    );
  }
}
