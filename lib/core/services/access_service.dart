import 'package:get/get.dart';
import '../data/models/activity.dart';
import '../realtime/socket_events.dart';

/// Who the user is: guest/account × free/member (spec §1.1). The UI unlocks from the RevenueCat SDK **or** the server,
/// signed media URLs and dedications always wait for the server (spec §9).
class AccessService extends GetxService {
  final entitlement = const Entitlement().obs;
  /// From the RevenueCat SDK `CustomerInfo` (P3).
  final sdkPremium = false.obs;
  final isGuest = true.obs;
  final hasAccount = false.obs;

  bool get isMember => entitlement.value.active || sdkPremium.value;
  bool get serverMember => entitlement.value.active;
  bool get isTrial => entitlement.value.isTrial && isMember;
  bool get billingIssue => entitlement.value.billingIssue;

  /// Sentry tag `plan`.
  String get plan => isGuest.value ? (isMember ? 'guest_member' : 'guest_free') : (isTrial ? 'trial' : (isMember ? 'member' : 'free'));

  void setFromProfile(MeProfile p) {
    entitlement.value = p.entitlement;
    isGuest.value = p.isGuest;
    hasAccount.value = !p.isGuest;
  }

  void onSocket(EntitlementChanged e) {
    final cur = entitlement.value;
    entitlement.value = Entitlement(
        active: e.active, productId: e.productId, periodType: e.periodType, expiresAt: e.expiresAt, billingIssue: e.billingIssue, willRenew: cur.willRenew, isFounding: cur.isFounding);
  }
}
