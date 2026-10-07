import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/services/purchase_service.dart';
import '../../../core/data/models/bootstrap.dart';

String formatDate(DateTime? d) => d == null ? '' : DateFormat('MMMM d, y').format(d.toLocal());

/// "Annual plan · Founding", "Monthly plan", "Annual plan".
String planName(Entitlement e) {
  final id = e.productId ?? '';
  final base = id.contains('monthly') ? 'Monthly plan' : 'Annual plan';
  return (e.isFounding || id.contains('founding')) && !id.contains('monthly') ? '$base · Founding' : base;
}

/// Which membership state the user is in (screens 61–64).
enum MembershipState { none, trial, active, trialEnding, billingIssue, ended }

MembershipState membershipState(Entitlement e, {DateTime? now, bool hadMembership = false}) {
  final n = now ?? DateTime.now().toUtc();
  if (e.billingIssue && e.active) return MembershipState.billingIssue;
  if (e.active && e.isTrial) {
    final left = e.expiresAt?.difference(n);
    return (left != null && left <= const Duration(days: 2, hours: 12)) ? MembershipState.trialEnding : MembershipState.trial;
  }
  if (e.active) return MembershipState.active;
  return hadMembership || e.productId != null ? MembershipState.ended : MembershipState.none;
}

/// 14 Membership paywall.
class PaywallController extends GetxController {
  PaywallController(this.source);
  final String source; // start | today_free | lock | settings
  late final PurchaseService purchases = Get.find<PurchaseService>();
  final selected = 'annual'.obs;
  final busy = false.obs;
  final message = RxnString();

  Offer? get offer => purchases.offer.value;
  Founding get founding => Get.find<ConfigService>().current.value?.founding ?? const Founding();
  PlanOption? get plan => selected.value == 'annual' ? (offer?.annual ?? offer?.monthly) : (offer?.monthly ?? offer?.annual);

  @override
  void onReady() {
    super.onReady();
    Get.find<AnalyticsService>().track('paywall_view', {'source': source, 'offering': offer?.offeringId ?? ''});
    purchases.loadOffer();
  }

  Future<void> start() async {
    final p = plan;
    if (p == null || busy.value) return;
    busy.value = true;
    message.value = null;
    Get.find<AnalyticsService>().track('plan_selected', {'product_id': p.productId});
    final out = await purchases.buy(p);
    busy.value = false;
    switch (out) {
      case PurchaseOutcome.success:
        Get.offAllNamed(AppRoutes.trialStarted);
      case PurchaseOutcome.cancelled:
        break;
      case PurchaseOutcome.pending:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'pending'});
      case PurchaseOutcome.alreadySubscribed:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'already'});
      case PurchaseOutcome.failed:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'failed'});
      case PurchaseOutcome.unavailable:
        message.value = 'That plan changed. Please check the updated options.';
    }
  }
}

/// 11 Purchase states: failed (retry), pending (Ask to Buy), already subscribed, cancelled.
class PurchaseStatusController extends GetxController {
  PurchaseStatusController(this.state);
  final String state; // loading | failed | pending | already | cancelled
  final busy = false.obs;

  Future<void> retry() async {
    final p = Get.find<PurchaseService>();
    final plan = p.offer.value?.annual ?? p.offer.value?.monthly;
    if (plan == null) {
      Get.back<void>();
      return;
    }
    busy.value = true;
    final out = await p.buy(plan);
    busy.value = false;
    if (out == PurchaseOutcome.success) Get.offAllNamed(AppRoutes.trialStarted);
  }

  void continueFree() {
    Get.find<OnboardingStore>().done = true;
    Get.offAllNamed(AppRoutes.todayFree);
  }
}

/// 12 Trial started.
class WelcomeController extends GetxController {
  AccessService get access => Get.find<AccessService>();
  String get name => Get.find<OnboardingStore>().name;
  String get title => name.isEmpty ? 'Welcome to WeHum.' : 'Welcome to WeHum, $name.';
  DateTime? get trialEnds => access.entitlement.value.expiresAt;
}

/// 15 Restore purchase.
class RestoreController extends GetxController {
  final state = 'idle'.obs; // idle | checking | restored | notFound | failed

  Future<void> run() async {
    state.value = 'checking';
    final r = await Get.find<PurchaseService>().restore();
    state.value = switch (r) { RestoreOutcome.restored => 'restored', RestoreOutcome.notFound => 'notFound', RestoreOutcome.failed => 'failed' };
  }

  @override
  void onReady() {
    super.onReady();
    run();
  }
}

/// 61 Manage membership + 62/63/64 states.
class ManageMembershipController extends GetxController {
  AccessService get access => Get.find<AccessService>();
  Entitlement get ent => access.entitlement.value;
  MembershipState get state => membershipState(ent);
  String get plan => planName(ent);

  /// "Free until October 12, 2026. Then $59 per year (Founding price), renewing automatically."
  String describe(Offer? offer) {
    final price = ent.productId != null && ent.productId!.contains('monthly') ? offer?.monthly?.priceString : offer?.annual?.priceString;
    final per = (ent.productId ?? '').contains('monthly') ? 'month' : 'year';
    final founding = ent.isFounding ? ' (Founding price)' : '';
    if (ent.isTrial) return 'Free until ${formatDate(ent.expiresAt)}. Then ${price ?? 'the plan price'} per $per$founding, renewing automatically.';
    return ent.willRenew ? 'Renews on ${formatDate(ent.expiresAt)}${price == null ? '' : ' at $price per $per'}$founding.' : 'Ends on ${formatDate(ent.expiresAt)}. It will not renew.';
  }
}
