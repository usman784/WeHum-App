import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../config/env.dart';
import 'access_service.dart';
import 'analytics_service.dart';
import 'logger.dart';

enum PurchaseOutcome { success, cancelled, pending, failed, alreadySubscribed, unavailable }
enum RestoreOutcome { restored, notFound, failed }

/// One plan row for the paywall. Prices are always the store's own strings (spec §9), never constants.
class PlanOption {
  const PlanOption({required this.packageId, required this.productId, required this.priceString, required this.isAnnual, this.trialDays = 7, this.isFounding = false, this.period = 'year'});
  final String packageId, productId, priceString, period;
  final bool isAnnual, isFounding;
  final int trialDays;
}

class Offer {
  const Offer({required this.offeringId, this.annual, this.monthly});
  final String offeringId; // `default` (founding) or `regular`
  final PlanOption? annual, monthly;
  bool get isEmpty => annual == null && monthly == null;
  bool get founding => annual?.isFounding ?? false;
}

/// Thin port over the SDK so the logic is testable and the SDK is never called from controllers.
abstract class RcClient {
  Future<void> configure(String apiKey, String appUserId);
  Future<void> logIn(String appUserId);
  Future<void> logOut();
  Future<Offer> offer();
  Future<PurchaseOutcome> purchase(String packageId);
  Future<RestoreOutcome> restore();
  /// `premium` entitlement active?
  Future<bool> isPremium();
  void onChange(void Function(bool premium) cb);
}

class PurchasesRc implements RcClient {
  Offerings? _cache;

  @override
  Future<void> configure(String apiKey, String appUserId) => Purchases.configure(PurchasesConfiguration(apiKey)..appUserID = appUserId);
  @override
  Future<void> logIn(String id) async {
    await Purchases.logIn(id);
  }

  @override
  Future<void> logOut() async {
    try {
      await Purchases.logOut();
    } catch (_) {/* anonymous already */}
  }

  @override
  Future<Offer> offer() async {
    final o = _cache = await Purchases.getOfferings();
    final cur = o.current;
    if (cur == null) return const Offer(offeringId: '');
    PlanOption? map(Package? p, bool annual) {
      if (p == null) return null;
      final intro = p.storeProduct.introductoryPrice;
      final days = intro == null ? 7 : (intro.periodUnit == PeriodUnit.day ? intro.periodNumberOfUnits : intro.periodUnit == PeriodUnit.week ? intro.periodNumberOfUnits * 7 : 7);
      return PlanOption(
          packageId: p.identifier, productId: p.storeProduct.identifier, priceString: p.storeProduct.priceString, isAnnual: annual, trialDays: days,
          isFounding: p.storeProduct.identifier.contains('founding'), period: annual ? 'year' : 'month');
    }

    return Offer(offeringId: cur.identifier, annual: map(cur.annual, true), monthly: map(cur.monthly, false));
  }

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    final pkg = _cache?.current?.availablePackages.where((p) => p.identifier == packageId).firstOrNull;
    if (pkg == null) return PurchaseOutcome.unavailable;
    try {
      final r = await Purchases.purchase(PurchaseParams.package(pkg));
      return r.customerInfo.entitlements.active.containsKey('premium') ? PurchaseOutcome.success : PurchaseOutcome.pending;
    } on PlatformException catch (e) {
      return switch (PurchasesErrorHelper.getErrorCode(e)) {
        PurchasesErrorCode.purchaseCancelledError => PurchaseOutcome.cancelled,
        PurchasesErrorCode.paymentPendingError => PurchaseOutcome.pending,
        PurchasesErrorCode.productAlreadyPurchasedError => PurchaseOutcome.alreadySubscribed,
        PurchasesErrorCode.productNotAvailableForPurchaseError => PurchaseOutcome.unavailable,
        _ => PurchaseOutcome.failed,
      };
    }
  }

  @override
  Future<RestoreOutcome> restore() async {
    try {
      final i = await Purchases.restorePurchases();
      return i.entitlements.active.containsKey('premium') ? RestoreOutcome.restored : RestoreOutcome.notFound;
    } catch (_) {
      return RestoreOutcome.failed;
    }
  }

  @override
  Future<bool> isPremium() async => (await Purchases.getCustomerInfo()).entitlements.active.containsKey('premium');
  @override
  void onChange(void Function(bool premium) cb) => Purchases.addCustomerInfoUpdateListener((i) => cb(i.entitlements.active.containsKey('premium')));
}

/// RevenueCat with `appUserID` = backend user id (spec §9). Never unlocks from client receipt parsing: the SDK result
/// unlocks the UI, the server confirms through `/me/entitlement/sync` and the `entitlement:changed` socket event.
class PurchaseService extends GetxService {
  PurchaseService(this._rc, this._access, this._analytics, {required this.syncEntitlement});
  final RcClient _rc;
  final AccessService _access;
  final AnalyticsService _analytics;
  final Future<void> Function() syncEntitlement;

  final offer = Rxn<Offer>();
  final loading = false.obs;
  final lastError = RxnString();
  bool _configured = false;

  /// After `ensureSession()`: configure with the backend user id.
  Future<void> configure(String userId) async {
    if (_configured) return logIn(userId);
    final key = Env.platformName == 'ios' ? Env.rcAppleKey : Env.rcGoogleKey;
    if (key.isEmpty) {
      logd('purchases', 'no RevenueCat key for this flavor: purchases disabled');
      return;
    }
    await _rc.configure(key, userId);
    _configured = true;
    _rc.onChange((p) => _access.sdkPremium.value = p);
    _access.sdkPremium.value = await _rc.isPremium();
  }

  /// After merge or login: the same id keeps purchases attached; RevenueCat transfers per project settings.
  Future<void> logIn(String userId) async {
    if (!_configured) return;
    await _rc.logIn(userId);
    _access.sdkPremium.value = await _rc.isPremium();
  }

  Future<void> signedOut() async {
    if (_configured) await _rc.logOut();
    _access.sdkPremium.value = false;
  }

  bool get available => _configured;

  /// Tests: configure without a real SDK key.
  @visibleForTesting
  Future<void> configureForTest(String userId) async {
    await _rc.configure('test', userId);
    _configured = true;
    _rc.onChange((p) => _access.sdkPremium.value = p);
    _access.sdkPremium.value = await _rc.isPremium();
  }

  Future<Offer?> loadOffer() async {
    if (!_configured) return null;
    loading.value = true;
    try {
      offer.value = await _rc.offer();
      lastError.value = null;
      return offer.value;
    } catch (e) {
      lastError.value = '$e';
      return null;
    } finally {
      loading.value = false;
    }
  }

  Future<PurchaseOutcome> buy(PlanOption plan) async {
    _analytics.track('purchase_start', {'product_id': plan.productId});
    final out = await _rc.purchase(plan.packageId);
    switch (out) {
      case PurchaseOutcome.success:
        _access.sdkPremium.value = true;
        _analytics.track('purchase_success', {'product_id': plan.productId});
        _analytics.track('trial_start');
        try {
          await syncEntitlement(); // the server confirms through the RevenueCat REST API
        } catch (_) {/* the webhook + socket event also arrive; the SDK already unlocked the UI */}
      case PurchaseOutcome.cancelled:
        _analytics.track('purchase_cancel', {'product_id': plan.productId});
      case PurchaseOutcome.unavailable:
        await loadOffer(); // the Founding cap was reached during checkout: show the refreshed paywall
        _analytics.track('purchase_fail', {'product_id': plan.productId, 'error_code': 'unavailable'});
      case PurchaseOutcome.failed:
        _analytics.track('purchase_fail', {'product_id': plan.productId, 'error_code': 'failed'});
      case PurchaseOutcome.pending || PurchaseOutcome.alreadySubscribed:
        break;
    }
    return out;
  }

  Future<RestoreOutcome> restore() async {
    final r = await _rc.restore();
    if (r == RestoreOutcome.restored) {
      _access.sdkPremium.value = true;
      _analytics.track('restore_success');
      try {
        await syncEntitlement();
      } catch (_) {}
    } else {
      _analytics.track('restore_fail');
    }
    return r;
  }
}
