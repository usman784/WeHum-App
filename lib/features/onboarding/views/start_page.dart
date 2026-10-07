import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/config/app_links.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../controllers/onboarding_controllers.dart';
import 'onboarding_widgets.dart';

/// 09 How do you want to start. Prices come from RevenueCat, the spots counter from `bootstrap.founding` (live).
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(StartController());
    final c = context.colors;
    return OnboardingFrame(
      showBack: true, dots: 4, topRight: TextLink('Log in', onPressed: () => Get.toNamed(AppRoutes.logIn), color: c.textSecondary),
      footer: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
          TextLink('Restore purchase', onPressed: () => Get.toNamed(AppRoutes.restorePurchase), color: c.textSecondary),
          TextLink('Terms of Use', onPressed: () => launchUrl(Uri.parse(AppLinks.terms)), color: c.textSecondary),
          TextLink('Privacy', onPressed: () => launchUrl(Uri.parse(AppLinks.privacy)), color: c.textSecondary),
        ]),
      ),
      child: SingleChildScrollView(
        child: Obx(() {
          final offer = ctrl.offer;
          final f = ctrl.founding;
          final a = offer?.annual, m = offer?.monthly;
          final online = Get.find<ConnectivityService>().online.value; // no purchase without a connection (spec §10)
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('How do you want to start?', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: c.emberDeep.withValues(alpha: .35), borderRadius: BorderRadius.circular(Radii.cardLarge), border: Border.all(color: c.ember)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (f.open && (a?.isFounding ?? true))
                  Container(
                    key: const Key('founding-banner'), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: c.emberTint, borderRadius: BorderRadius.circular(Radii.pill)),
                    child: Text('FOUNDING 1,000 · ${a?.priceString ?? ''}/YEAR · ${f.left} SPOTS LEFT'.replaceAll(' · /YEAR', ''), style: AppText.overline.copyWith(color: c.emberText, fontSize: 11)),
                  ),
                const SizedBox(height: 14),
                Text('Everything in WeHum: the extended meditation library, Meditation of the Day, group meditations, a daily message from Raphael, customizable meditations, SoS sessions for hard times and the Silence Room.', style: AppText.body.copyWith(color: c.textBody)),
                const SizedBox(height: 14),
                if (a != null) ...[
                  Text('${a.trialDays} days free, then ${a.priceString}/year.', key: const Key('annual-line'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 20)),
                  Text('Renews automatically. Cancel anytime before the trial ends.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 16),
                  PrimaryButton('Start ${a.trialDays}-day free trial', loading: ctrl.busy.value, onPressed: online ? () => ctrl.startTrial(a) : null),
                  if (!online) Padding(padding: const EdgeInsets.only(top: 8), child: Text('You’re offline. Connect to the internet to start your trial.', key: const Key('buy-offline'), style: AppText.bodySmall.copyWith(color: c.textSecondary))),
                ] else
                  _Unavailable(loading: ctrl.purchases.loading.value, onRetry: ctrl.purchases.loadOffer),
              ]),
            ),
            if (m != null) ...[
              const SizedBox(height: 12),
              OutlineButton('Monthly · ${m.trialDays} days free, then ${m.priceString}/month', onPressed: ctrl.busy.value || !online ? null : () => ctrl.startTrial(m)),
              const SizedBox(height: 8),
              Center(child: Text('Full access. Renews monthly, cancel anytime before the trial ends.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textSecondary))),
            ],
            if (ctrl.message.value != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText))),
            const SizedBox(height: 20),
            Center(child: TextButton(key: const Key('continue-free'), onPressed: ctrl.continueFree, child: Text('Continue for free', style: AppText.navTitle.copyWith(color: c.textPrimary, decoration: TextDecoration.underline)))),
            Center(child: Text('Access Raphael’s existing online library of guided meditations.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary))),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.check_rounded, size: 18, color: c.tealText),
              const SizedBox(width: 8),
              Flexible(child: Text('No account needed. Save your progress later.', style: AppText.bodySmall.copyWith(color: c.tealText))),
            ]),
            const SizedBox(height: 16),
          ]);
        }),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.loading, required this.onRetry});
  final bool loading;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (loading) return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("Plans aren't available right now.", style: AppText.navTitle.copyWith(color: c.textPrimary)),
      const SizedBox(height: 4),
      Text('Check your connection and try again. You can still continue for free.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
      const SizedBox(height: 12),
      OutlineButton('Try again', onPressed: onRetry),
    ]);
  }
}

