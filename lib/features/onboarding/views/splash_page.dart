import 'package:flutter/material.dart';
import '../../../core/widgets/painters.dart';
import 'package:get/get.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../controllers/onboarding_controllers.dart';

/// 01 Splash: ring logo + "WeHum by Raphael Reiter". Failure → retry (the cached app still opens when a session exists).
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(SplashController());
    return Scaffold(
      body: Center(
        child: Obx(() {
          final failed = ctrl.failure.value;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const BrandLogo(size: 88),
            const SizedBox(height: 20),
            Text('WeHum', style: AppText.display.copyWith(color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('by Raphael Reiter', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(height: 40),
            if (failed == null)
              SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: c.textTertiary))
            else ...[
              Text(failed == ErrorCode.network || failed == ErrorCode.timeout ? "You're offline" : 'Something went wrong', style: AppText.body.copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: OutlineButton('Try again', key: const Key('splash-retry'), onPressed: ctrl.start)),
            ],
          ]);
        }),
      ),
    );
  }
}
