import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/surfaces.dart';
import '../../account/views/account_widgets.dart';
import '../controllers/membership_controllers.dart';

Future<void> _open(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
String get storeSubscriptionsUrl => Platform.isIOS ? AppLinks.appStoreSubscriptions : AppLinks.playSubscriptions;

/// 14 Membership paywall.
class PaywallPage extends StatelessWidget {
  const PaywallPage({super.key});

  static const perks = [
    'Extended meditation library',
    'Meditation of the Day in 10, 30 or 45 min',
    'Group meditations, together with everyone',
    'A daily message from Raphael',
    'Build your own meditations',
    'SoS sessions for hard times',
    'Silence Room',
    'Downloads, listen offline',
    'Post dedications',
  ];

  @override
  Widget build(BuildContext context) {
    final source = ((Get.arguments as Map?)?['source'] ?? 'settings') as String;
    final ctrl = Get.put(PaywallController(source));
    final c = context.colors;
    return AppScaffold(
      title: 'Membership plans',
      body: Obx(() {
        final offer = ctrl.offer;
        final a = offer?.annual, m = offer?.monthly;
        final f = ctrl.founding;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('WeHum membership', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 12),
            for (final p in perks) Benefit(p),
            const SizedBox(height: 16),
            if (offer == null || offer.isEmpty)
              ctrl.purchases.loading.value
                  ? const Center(child: CircularProgressIndicator())
                  : AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Plans aren't available right now.", style: AppText.navTitle.copyWith(color: c.textPrimary)),
                      const SizedBox(height: 4),
                      Text('Check your connection and try again.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                      const SizedBox(height: 12),
                      OutlineButton('Try again', onPressed: ctrl.purchases.loadOffer),
                    ]))
            else ...[
              if (a != null) _PlanTile(key: const Key('plan-annual'), selected: ctrl.selected.value == 'annual', onTap: () => ctrl.selected.value = 'annual', title: 'Annual', price: a.priceString, per: '/year',
                  banner: f.open && a.isFounding ? 'FOUNDING 1,000 · ${a.priceString}/YEAR · ${f.left} SPOTS LEFT' : null, note: '${a.trialDays} days free, then ${a.priceString}/year. Cancel anytime.'),
              const SizedBox(height: 12),
              if (m != null) _PlanTile(key: const Key('plan-monthly'), selected: ctrl.selected.value == 'monthly', onTap: () => ctrl.selected.value = 'monthly', title: 'Monthly', price: m.priceString, per: '/month', note: '${m.trialDays} days free, then ${m.priceString}/month. Cancel anytime.'),
              const SizedBox(height: 20),
              PrimaryButton('Start ${ctrl.plan?.trialDays ?? 7}-day free trial', loading: ctrl.busy.value, onPressed: ctrl.start),
              if (ctrl.message.value != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText))),
              const SizedBox(height: 10),
              Text('Payment is charged to your ${Platform.isIOS ? 'Apple ID' : 'Google Play account'} after the free trial. The subscription renews automatically unless cancelled at least 24 hours before the period ends. Manage or cancel in your store settings.',
                  style: AppText.caption.copyWith(color: c.textSecondary)),
            ],
            const SizedBox(height: 16),
            Wrap(alignment: WrapAlignment.center, children: [
              TextLink('Restore purchase', onPressed: () => Get.toNamed(AppRoutes.restorePurchase), color: c.textSecondary),
              const SizedBox(width: 12),
              TextLink('Terms of Use (EULA)', onPressed: () => _open(AppLinks.terms), color: c.textSecondary),
              const SizedBox(width: 12),
              TextLink('Privacy', onPressed: () => _open(AppLinks.privacy), color: c.textSecondary),
            ]),
          ]),
        );
      }),
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({super.key, required this.selected, required this.onTap, required this.title, required this.price, required this.per, required this.note, this.banner});
  final bool selected;
  final VoidCallback onTap;
  final String title, price, per, note;
  final String? banner;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true, selected: selected, label: '$title $price$per',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.state, padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: selected ? c.emberDeep.withValues(alpha: .35) : c.surface, borderRadius: BorderRadius.circular(Radii.card), border: Border.all(color: selected ? c.ember : c.border, width: selected ? 1.5 : 1)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (banner != null) Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: c.emberTint, borderRadius: BorderRadius.circular(Radii.pill)), child: Text(banner!, style: AppText.overline.copyWith(color: c.emberText, fontSize: 10))),
            Row(children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? c.ember : c.textTertiary),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary))),
              Flexible(child: Text(price, textAlign: TextAlign.end, style: AppText.title.copyWith(color: c.textPrimary))),
              Text(per, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            ]),
            const SizedBox(height: 6),
            Text(note, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// 11 Purchase states.
class PurchaseStatusPage extends StatelessWidget {
  const PurchaseStatusPage({super.key});
  @override
  Widget build(BuildContext context) {
    final state = ((Get.arguments as Map?)?['state'] ?? 'failed') as String;
    final ctrl = Get.put(PurchaseStatusController(state), tag: state);
    final c = context.colors;
    final (icon, title, body, cta, ctaAction, secondary) = switch (state) {
      'loading' => (Icons.hourglass_top_rounded, 'Starting your membership…', 'This takes a few seconds. Please keep the app open.', null, null, null),
      'pending' => (Icons.family_restroom_rounded, 'Waiting for approval', 'A family organiser needs to approve this purchase (Ask to Buy). Membership opens as soon as it’s approved.', null, null, 'Continue free while you wait'),
      'already' => (Icons.verified_outlined, 'You’re already a member', 'This store account already has WeHum. Restore your purchase to unlock everything on this phone.', 'Restore purchase', () => Get.offNamed(AppRoutes.restorePurchase), 'Continue free'),
      'cancelled' => (Icons.favorite_border_rounded, 'No problem', 'Nothing was charged. Your Founding price is still here when you’re ready.', 'See the options again', () => Get.back<void>(), 'Continue free'),
      _ => (Icons.error_outline_rounded, 'Payment didn’t go through', 'You weren’t charged. Check your payment method in the ${Platform.isIOS ? 'App Store' : 'Play Store'} and try again.', 'Try again', ctrl.retry, 'Continue free for now'),
    };
    return Scaffold(
      body: SafeArea(
        child: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: state == 'loading' ? const CircularProgressIndicator() : Icon(icon, size: 64, color: c.ember)),
            const SizedBox(height: 20),
            Text(title, textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(height: 28),
            if (cta != null) Obx(() => PrimaryButton(cta, loading: ctrl.busy.value, onPressed: ctaAction)),
            if (secondary != null) Center(child: TextLink(secondary, onPressed: ctrl.continueFree, color: c.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// 12 Trial started.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(WelcomeController());
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Spacer(),
                Icon(Icons.celebration_outlined, size: 56, color: c.ember),
                const SizedBox(height: 20),
                Text(ctrl.title, key: const Key('welcome-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 10),
                Text('Your 7-day free trial has started. We’ll remind you on day 5, before it ends.${ctrl.trialEnds == null ? '' : ' It ends on ${formatDate(ctrl.trialEnds)}.'}', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 20),
                const Benefit('Today’s Meditation of the Day is open'),
                const Benefit('The extended meditation library'),
                const Benefit('Group meditations, together with everyone'),
                const Spacer(),
                PrimaryButton('Continue', onPressed: () => Get.offAllNamed(AppRoutes.saveYourProgressOptional)),
                const SizedBox(height: 12),
              ])),
        ),
      ),
    );
  }
}

/// 15 Restore purchase.
class RestorePage extends StatelessWidget {
  const RestorePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(RestoreController());
    final c = context.colors;
    return AppScaffold(
      title: 'Restore purchase',
      body: Padding(
        padding: const EdgeInsets.all(Gap.gutterOnboarding),
        child: Obx(() {
          final s = ctrl.state.value;
          final (icon, title, body) = switch (s) {
            'restored' => (Icons.check_circle_outline_rounded, 'Membership restored', 'Everything is unlocked again.'),
            'notFound' => (Icons.search_off_rounded, 'No membership found', 'We couldn’t find a WeHum purchase on this ${Platform.isIOS ? 'Apple ID' : 'Google account'}. If you subscribed on another account, sign in to that store account and try again.'),
            'failed' => (Icons.error_outline_rounded, 'Couldn’t check right now', 'Check your connection and try again.'),
            _ => (Icons.hourglass_top_rounded, 'Checking your purchases…', 'Looking for a WeHum membership on this store account.'),
          };
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 32),
            Center(child: s == 'checking' || s == 'idle' ? const CircularProgressIndicator() : Icon(icon, size: 64, color: s == 'restored' ? c.success : c.textTertiary)),
            const SizedBox(height: 20),
            Text(title, key: const Key('restore-title'), textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const Spacer(),
            if (s == 'restored') PrimaryButton('Go to Today', onPressed: () => Get.offAllNamed(AppRoutes.todayMember)),
            if (s == 'notFound') ...[
              PrimaryButton('See membership options', onPressed: () => Get.offNamed(AppRoutes.membershipPaywall, arguments: {'source': 'settings'})),
              const SizedBox(height: 8),
              OutlineButton('Log in to your WeHum account', onPressed: () => Get.offNamed(AppRoutes.logIn)),
            ],
            if (s == 'failed') PrimaryButton('Try again', onPressed: ctrl.run),
            if (s != 'checking' && s != 'idle') Center(child: TextLink('Close', onPressed: () => Get.back<void>(), color: c.textSecondary)),
          ]);
        }),
      ),
    );
  }
}

/// 61 Manage membership (with the trial-ending, billing and ended states of 62–64 inline).
class ManageMembershipPage extends StatelessWidget {
  const ManageMembershipPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ManageMembershipController());
    final c = context.colors;
    return AppScaffold(
      title: 'Membership',
      body: Obx(() {
        final s = ctrl.state;
        final offer = Get.find<PurchaseService>().offer.value;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Gap.gutter),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (s == MembershipState.billingIssue) _Banner(key: const Key('banner-billing'), icon: Icons.credit_card_off_outlined, text: 'Payment problem. Update by ${formatDate(ctrl.ent.expiresAt)}.', color: c.dangerTint, fg: c.dangerText, onTap: () => Get.toNamed(AppRoutes.billingIssue)),
            if (s == MembershipState.trialEnding) _Banner(key: const Key('banner-trial'), icon: Icons.hourglass_bottom_rounded, text: 'Your trial ends soon.', color: c.emberTint, fg: c.emberText, onTap: () => Get.toNamed(AppRoutes.trialEnding)),
            if (s == MembershipState.ended || s == MembershipState.none)
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s == MembershipState.ended ? 'Your membership has ended' : 'You’re on the free plan', style: AppText.title.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                Text('Free meditations from Raphael’s online library stay available.', style: AppText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: 16),
                PrimaryButton(s == MembershipState.ended ? 'Rejoin WeHum' : 'See membership options', onPressed: () => Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'settings'})),
              ]))
            else
              AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(ctrl.ent.isTrial ? 'ACTIVE · FREE TRIAL' : 'ACTIVE', style: AppText.overline.copyWith(color: c.success)),
                const SizedBox(height: 8),
                Text(ctrl.plan, key: const Key('plan-name'), style: AppText.title.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text(ctrl.describe(offer), style: AppText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: 6),
                Text('Billed by the ${Platform.isIOS ? 'App Store' : 'Play Store'}', style: AppText.caption.copyWith(color: c.textTertiary)),
              ])),
            const SizedBox(height: 16),
            if (s != MembershipState.ended && s != MembershipState.none) ...[
              OutlineButton('Change plan', onPressed: () => Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'settings'})),
              const SizedBox(height: 8),
              OutlineButton('Manage in ${Platform.isIOS ? 'App Store' : 'Google Play'}', onPressed: () => _open(storeSubscriptionsUrl)),
              const SizedBox(height: 8),
            ],
            OutlineButton('Restore purchase', onPressed: () => Get.toNamed(AppRoutes.restorePurchase)),
            const SizedBox(height: 24),
            Text('How to cancel', style: AppText.navTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 6),
            Text('Cancel in your ${Platform.isIOS ? 'App Store' : 'Google Play'} subscriptions. You keep access until the end of the paid period. Deleting your WeHum account does not cancel the subscription.', style: AppText.body.copyWith(color: c.textSecondary)),
          ]),
        );
      }),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, required this.color, required this.fg, required this.onTap});
  final IconData icon;
  final String text;
  final Color color, fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(Radii.tile)),
            child: Row(children: [Icon(icon, color: fg), const SizedBox(width: 10), Expanded(child: Text(text, style: AppText.bodySmall.copyWith(color: fg, fontWeight: FontWeight.w600))), Icon(Icons.chevron_right_rounded, color: fg)]),
          ),
        ),
      );
}

/// 62 Trial ends in 2 days (push on day 5 + in-app).
class TrialEndingPage extends StatelessWidget {
  const TrialEndingPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ManageMembershipController());
    final c = context.colors;
    final offer = Get.find<PurchaseService>().offer.value;
    final price = (ctrl.ent.productId ?? '').contains('monthly') ? offer?.monthly?.priceString : offer?.annual?.priceString;
    return AppScaffold(
      title: 'Your trial',
      body: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          Text('Your free trial ends in 2 days', key: const Key('trial-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 12),
          Text('On ${formatDate(ctrl.ent.expiresAt)} your ${(ctrl.ent.productId ?? '').contains('monthly') ? 'monthly' : 'annual'} plan starts${price == null ? '' : ' at $price'}. Do nothing to keep it. To stop, cancel in your ${Platform.isIOS ? 'App Store' : 'Google Play'} subscriptions before then.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const Spacer(),
          PrimaryButton('Keep my membership', onPressed: () => Get.offAllNamed(AppRoutes.todayMember)),
          const SizedBox(height: 8),
          OutlineButton('Manage membership', onPressed: () => Get.offNamed(AppRoutes.manageMembership)),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

/// 63 Payment problem.
class BillingIssuePage extends StatelessWidget {
  const BillingIssuePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ManageMembershipController());
    final c = context.colors;
    return AppScaffold(
      title: 'Billing issue',
      body: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          Icon(Icons.credit_card_off_outlined, size: 56, color: c.dangerText),
          const SizedBox(height: 16),
          Text('We couldn’t renew your membership', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 12),
          Text('The ${Platform.isIOS ? 'App Store' : 'Play Store'} couldn’t charge your payment method. You still have full access until ${formatDate(ctrl.ent.expiresAt)} while the store tries again.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          Text('Update your payment method in the ${Platform.isIOS ? 'App Store' : 'Play Store'} to keep everything unlocked.', style: AppText.body.copyWith(color: c.textSecondary)),
          const Spacer(),
          PrimaryButton('Update payment in ${Platform.isIOS ? 'App Store' : 'Play Store'}', onPressed: () => _open(storeSubscriptionsUrl)),
          const SizedBox(height: 8),
          Center(child: TextLink('Remind me later', onPressed: () => Get.back<void>(), color: c.textSecondary)),
        ]),
      ),
    );
  }
}

/// 64 Membership ended.
class MembershipEndedPage extends StatelessWidget {
  const MembershipEndedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppScaffold(
      title: 'Membership ended',
      body: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 16),
          Text('Your membership has ended', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Text('Thank you for meditating with us. Your progress, minutes and saved meditations are kept.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          Text('STILL FREE FOR YOU', style: AppText.overline.copyWith(color: c.tealText)),
          const SizedBox(height: 6),
          Text('Free meditations from Raphael’s online library', style: AppText.bodyLarge.copyWith(color: c.textBody)),
          const SizedBox(height: 16),
          Text('NOW LOCKED', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 6),
          Text('Meditation of the Day, extended library, group meditations, the Silence Room, daily message, downloads', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const Spacer(),
          PrimaryButton('Rejoin WeHum', onPressed: () => Get.offNamed(AppRoutes.membershipPaywall, arguments: {'source': 'settings'})),
          const SizedBox(height: 8),
          Center(child: TextLink('Continue free', onPressed: () => Get.offAllNamed(AppRoutes.todayFree), color: c.textSecondary)),
        ]),
      ),
    );
  }
}
