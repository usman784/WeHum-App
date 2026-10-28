import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/services/launch_screen.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/buttons.dart';
import '../controllers/onboarding_controllers.dart';

/// Same colour as the native launch screen (`flutter_native_splash` in pubspec), so the hand-over is invisible.
const splashBg = Color(0xFF0B0D0E);

/// Logo size on the native launch screen (128 pt, centred), so the first Flutter frame matches it exactly.
const splashLogo = 128.0;

/// The launch logo with a transparent background, so no square shows around it.
const splashLogoAsset = 'assets/brand/logo_splash.png';

/// 01 Splash: starts as the native launch screen (the bundled logo, never one from the network), then the logo
/// rises gently and "WeHum by Raphael Reiter" fades in; it stays at least [SplashController.minShow] and fades out
/// before the first screen. Failure → retry (the cached app still opens when a session exists).
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final SplashController ctrl = Get.put(SplashController());
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // the native launch screen stays until the logo is decoded, so the first Flutter frame already shows it
    precacheImage(const AssetImage(splashLogoAsset), context).whenComplete(() {
      LaunchScreen.release();
      if (mounted) _intro.forward();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rise = CurvedAnimation(parent: _intro, curve: const Interval(.15, .75, curve: Curves.easeInOutCubic));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(.45, 1, curve: Curves.easeOut));
    return Scaffold(
      backgroundColor: splashBg,
      body: Obx(() => AnimatedOpacity(
            opacity: ctrl.leaving.value ? 0 : 1, duration: SplashController.fadeOut, curve: Curves.easeIn,
            child: Center(
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  final failed = ctrl.failure.value;
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    // the logo starts exactly where the native splash drew it, then moves up to make room for the name
                    Transform.translate(
                      offset: Offset(0, 74 * (1 - rise.value)),
                      child: Transform.scale(scale: 1 - .25 * rise.value, child: Image.asset(splashLogoAsset, width: splashLogo, height: splashLogo, gaplessPlayback: true)),
                    ),
                    Opacity(
                      opacity: text.value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - text.value)),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const SizedBox(height: 8),
                          Text(brandName(), style: AppText.display.copyWith(color: Colors.white)),
                          const SizedBox(height: 4),
                          Text('by Raphael Reiter', style: AppText.bodyLarge.copyWith(color: const Color(0xFFA1A1AA))),
                          const SizedBox(height: 32),
                          SizedBox(
                            height: 96,
                            child: failed == null
                                ? null
                                : Column(children: [
                                    Text(failed == ErrorCode.network || failed == ErrorCode.timeout ? "You're offline" : 'Something went wrong', style: AppText.body.copyWith(color: const Color(0xFFA1A1AA))),
                                    const SizedBox(height: 12),
                                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: OutlineButton('Try again', key: const Key('splash-retry'), onPressed: ctrl.start)),
                                  ]),
                          ),
                        ]),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          )),
    );
  }
}
