import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/access_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/purchase_service.dart';

class FakeRc implements RcClient {
  PurchaseOutcome next = PurchaseOutcome.success;
  RestoreOutcome restoreNext = RestoreOutcome.restored;
  bool premium = false;
  Offer current = const Offer(
      offeringId: 'default',
      annual: PlanOption(packageId: r'$rc_annual', productId: 'wehum_annual_founding', priceString: r'$59.00', isAnnual: true, isFounding: true),
      monthly: PlanOption(packageId: r'$rc_monthly', productId: 'wehum_monthly', priceString: r'$9.99', isAnnual: false, period: 'month'));
  String? loggedIn;
  void Function(bool)? listener;
  int offers = 0;
  @override
  Future<void> configure(String apiKey, String appUserId) async => loggedIn = appUserId;
  @override
  Future<void> logIn(String id) async => loggedIn = id;
  @override
  Future<void> logOut() async => loggedIn = null;
  @override
  Future<Offer> offer() async {
    offers++;
    return current;
  }

  @override
  Future<PurchaseOutcome> purchase(String packageId) async => next;
  @override
  Future<RestoreOutcome> restore() async => restoreNext;
  @override
  Future<bool> isPremium() async => premium;
  @override
  void onChange(void Function(bool) cb) => listener = cb;
}

/// Stands for the real SDK before `configure`: every call is fatal.
class _ThrowingRc implements RcClient {
  final calls = <String>[];
  Never _die(String what) {
    calls.add(what);
    throw StateError('Purchases has not been configured ($what)');
  }

  @override
  Future<void> configure(String apiKey, String appUserId) async => _die('configure');
  @override
  Future<void> logIn(String id) async => _die('logIn');
  @override
  Future<void> logOut() async => _die('logOut');
  @override
  Future<Offer> offer() async => _die('offer');
  @override
  Future<PurchaseOutcome> purchase(String packageId) async => _die('purchase');
  @override
  Future<RestoreOutcome> restore() async => _die('restore');
  @override
  Future<bool> isPremium() async => _die('isPremium');
  @override
  void onChange(void Function(bool) cb) => _die('onChange');
}

void main() {
  late FakeRc rc;
  late AccessService access;
  late AnalyticsService analytics;
  late int syncs;
  late PurchaseService svc;

  Future<void> setUpSvc() async {
    rc = FakeRc();
    access = AccessService();
    analytics = AnalyticsService();
    syncs = 0;
    svc = PurchaseService(rc, access, analytics, syncEntitlement: () async => syncs++);
    // RevenueCat keys are empty in tests: configure by hand through the public path
    await svc.configureForTest('user-1');
  }

  setUp(setUpSvc);

  test('configures with the backend user id; offer shows store price strings and founding flag', () async {
    expect(rc.loggedIn, 'user-1');
    final o = await svc.loadOffer();
    expect(o!.annual!.priceString, r'$59.00');
    expect(o.founding, true);
    expect(o.monthly!.priceString, r'$9.99');
  });

  test('success unlocks the UI from the SDK at once, then asks the server to confirm; events tracked', () async {
    final out = await svc.buy(rc.current.annual!);
    expect(out, PurchaseOutcome.success);
    expect(access.sdkPremium.value, true);
    expect(access.serverMember, false); // the server has not confirmed yet
    expect(syncs, 1);
    expect(analytics.drain().map((e) => e['name']), ['purchase_start', 'purchase_success', 'trial_start']);
  });

  test('cancelled: no error, nothing unlocked; pending (Ask to Buy): not unlocked; failed: tracked', () async {
    rc.next = PurchaseOutcome.cancelled;
    expect(await svc.buy(rc.current.annual!), PurchaseOutcome.cancelled);
    rc.next = PurchaseOutcome.pending;
    expect(await svc.buy(rc.current.annual!), PurchaseOutcome.pending);
    rc.next = PurchaseOutcome.failed;
    expect(await svc.buy(rc.current.annual!), PurchaseOutcome.failed);
    expect(access.sdkPremium.value, false);
    expect(syncs, 0);
    final names = analytics.drain().map((e) => e['name']).toList();
    expect(names, containsAll(['purchase_cancel', 'purchase_fail']));
  });

  test('product unavailable (Founding cap reached during checkout) reloads the offer', () async {
    await svc.loadOffer();
    final before = rc.offers;
    rc.next = PurchaseOutcome.unavailable;
    rc.current = const Offer(offeringId: 'regular', annual: PlanOption(packageId: r'$rc_annual', productId: 'wehum_annual', priceString: r'$79.00', isAnnual: true));
    await svc.buy(svc.offer.value!.annual!);
    expect(rc.offers, before + 1);
    expect(svc.offer.value!.annual!.priceString, r'$79.00');
    expect(svc.offer.value!.founding, false);
  });

  test('server confirmation failing does not undo the unlock (webhook + socket confirm later)', () async {
    final s = PurchaseService(rc, access, analytics, syncEntitlement: () async => throw Exception('offline'));
    await s.configureForTest('user-1');
    expect(await s.buy(rc.current.annual!), PurchaseOutcome.success);
    expect(access.sdkPremium.value, true);
  });

  test('no SDK key (not configured): buy and restore never touch the store SDK (it would abort the app); restore asks the server', () async {
    final strict = _ThrowingRc();
    var synced = 0;
    final bare = PurchaseService(strict, access, analytics, syncEntitlement: () async => synced++);
    expect(bare.available, false);
    expect(await bare.buy(rc.current.annual!), PurchaseOutcome.unavailable);
    expect(await bare.restore(), RestoreOutcome.notFound);
    expect(synced, 1);
    access.entitlement.value = const Entitlement(active: true); // the server knows a membership for this account
    expect(await bare.restore(), RestoreOutcome.restored);
    expect(await bare.loadOffer(), isNull);
    await bare.signedOut();
    expect(strict.calls, isEmpty);
    final offline = PurchaseService(strict, AccessService(), analytics, syncEntitlement: () async => throw StateError('offline'));
    expect(await offline.restore(), RestoreOutcome.failed);
  });

  test('restore: found / not found; SDK listener keeps the flag in sync (renewal, expiry, refund)', () async {
    expect(await svc.restore(), RestoreOutcome.restored);
    expect(access.sdkPremium.value, true);
    rc.listener!(false); // expired or refunded
    expect(access.sdkPremium.value, false);
    rc.restoreNext = RestoreOutcome.notFound;
    expect(await svc.restore(), RestoreOutcome.notFound);
    expect(access.sdkPremium.value, false);
  });

  test('login/merge keeps purchases on the new id; sign-out clears the flag', () async {
    rc.premium = true;
    await svc.logIn('user-2');
    expect(rc.loggedIn, 'user-2');
    expect(access.sdkPremium.value, true);
    await svc.signedOut();
    expect(access.sdkPremium.value, false);
  });
}
