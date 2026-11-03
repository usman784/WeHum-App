import 'dart:async';
import 'package:get/get.dart';
import '../data/models/activity.dart';
import '../realtime/socket_events.dart';

/// Who the user is: guest/account × free/member (spec §1.1). The UI unlocks from the RevenueCat SDK **or** the server,
/// signed media URLs and dedications always wait for the server (spec §9).
///
/// Beta access (free premium for test accounts) lives only on the server. Three rules keep it honest:
///  * every server answer carries a revision (`rev`): a read or event older than what we hold is dropped;
///  * after the server says "not a member", a store (SDK) "yes" is not believed until the SDK is read fresh, so a stale
///    SDK cache can never keep a revoked account unlocked (a genuine store subscription still shows up in that read);
///  * work that started for one account is thrown away when another account takes over (`_epoch`).
class AccessService extends GetxService {
  final entitlement = const Entitlement().obs;

  /// From the RevenueCat SDK `CustomerInfo` (P3).
  final sdkPremium = false.obs;

  /// True from a server revocation until the SDK has been read fresh: the SDK's answer is not trusted in between.
  final sdkStale = false.obs;
  final isGuest = true.obs;
  final hasAccount = false.obs;

  /// The user id from the last profile (null before the first one), so per-user caches can tell a new user apart.
  String? userId;

  /// Set by the purchase service: drops the SDK's cache and reads the store entitlement again.
  Future<bool> Function()? refreshSdk;

  /// Set by the app: reads `/me` again (used when a beta end date passes, even without a socket event).
  Future<void> Function()? reconcileServer;

  /// Called when membership was just lost (revocation or expiry): downloads that belong to the membership are removed.
  void Function()? onMembershipLost;

  int _epoch = 0;
  Timer? _expiry;

  /// Replaced in tests.
  DateTime Function() clock = DateTime.now;

  /// Identity generation, for async work that must not land on another account.
  int get epoch => _epoch;

  /// The server's answer, with a beta end date honoured on the device even when it is offline and no event came.
  bool get serverMember {
    final e = entitlement.value;
    if (!e.active) return false;
    if (e.source == 'beta' && e.expiresAt != null && !clock().isBefore(e.expiresAt!)) {
      return false;
    }
    return true;
  }

  bool get isMember => serverMember || (sdkPremium.value && !sdkStale.value);
  bool get isTrial => entitlement.value.isTrial && isMember;
  bool get billingIssue => entitlement.value.billingIssue;

  /// Sentry tag `plan`.
  String get plan => isGuest.value
      ? (isMember ? 'guest_member' : 'guest_free')
      : (isTrial ? 'trial' : (isMember ? 'member' : 'free'));

  void setFromProfile(MeProfile p) {
    if (userId != null && userId != p.id) _newIdentity();
    userId = p.id;
    isGuest.value = p.isGuest;
    hasAccount.value = !p.isGuest;
    // a read that started before a newer event arrived must not roll the state back
    if (p.entitlement.rev < entitlement.value.rev) return;
    final lost = serverMember && !_active(p.entitlement);
    entitlement.value = p.entitlement;
    _armExpiry();
    // launch, resume, reconnect and the poll all learn a revocation here, so a cached store "yes" is re-read like on the live event
    if (!_active(p.entitlement) && sdkPremium.value) unawaited(reconcileSdk());
    if (lost) _lost();
  }

  void onSocket(EntitlementChanged e) {
    if (e.userId != null && userId != null && e.userId != userId) {
      return; // meant for the account we just left
    }
    final cur = entitlement.value;
    final rev = e.rev;
    if (rev != null && (rev < cur.rev || (rev == cur.rev && rev > 0))) {
      return; // older, or the same one again
    }
    final lost = serverMember && !e.active;
    entitlement.value = Entitlement(
      active: e.active,
      productId: e.productId,
      periodType: e.periodType,
      expiresAt: e.expiresAt,
      billingIssue: e.billingIssue,
      willRenew: e.willRenew ?? cur.willRenew,
      isFounding: e.isFounding ?? cur.isFounding,
      source: e.source ?? (e.active ? 'paid' : 'none'),
      betaExpiresAt: e.betaExpiresAt,
      rev: rev ?? cur.rev,
    );
    _armExpiry();
    if (!e.active) unawaited(reconcileSdk());
    if (lost) _lost();
  }

  /// The SDK reported a change. While the server's "no" has not been checked against a fresh SDK read, a "yes" is ignored.
  void onSdk(bool premium) {
    if (premium && sdkStale.value) return;
    sdkPremium.value = premium;
  }

  /// After a server revocation: read the store entitlement fresh. Still premium there = a real subscription, stays unlocked.
  Future<void> reconcileSdk() async {
    final read = refreshSdk;
    if (read == null) return;
    final epoch = _epoch;
    sdkStale.value = true;
    var fresh = false;
    try {
      fresh = await read();
    } catch (_) {
      fresh =
          false; // cannot prove it: the server said no, so stay locked until the SDK reports a change
    }
    if (epoch != _epoch) return; // another account took over meanwhile
    sdkPremium.value = fresh;
    sdkStale.value = false;
  }

  /// Sign-out or switch to another account: nothing of the old account's access may survive.
  void reset() {
    _newIdentity();
    userId = null;
    isGuest.value = true;
    hasAccount.value = false;
  }

  void _newIdentity() {
    _epoch++;
    _expiry?.cancel();
    sdkPremium.value = false;
    sdkStale.value = false;
    entitlement.value = const Entitlement();
  }

  bool _active(Entitlement e) =>
      e.active &&
      !(e.source == 'beta' &&
          e.expiresAt != null &&
          !clock().isBefore(e.expiresAt!));

  void _lost() {
    final f = onMembershipLost;
    if (f != null) f();
  }

  /// At the next end date (beta or paid) read the server again, and meanwhile let the screens drop premium on their own.
  void _armExpiry() {
    _expiry?.cancel();
    final e = entitlement.value;
    if (!e.active || e.source == 'none') return;
    final now = clock();
    final next = [e.betaExpiresAt, e.expiresAt]
        .whereType<DateTime>()
        .where((d) => d.isAfter(now))
        .toList()
      ..sort();
    if (next.isEmpty) return;
    final wait = next.first.difference(now) + const Duration(seconds: 1);
    if (wait > const Duration(days: 20)) {
      return; // re-armed on every profile read and on resume
    }
    final epoch = _epoch;
    _expiry = Timer(wait, () {
      if (epoch != _epoch) return;
      entitlement
          .refresh(); // `serverMember` now says no: rebuild what shows premium
      if (!serverMember) _lost();
      final f = reconcileServer;
      if (f != null) unawaited(f());
    });
  }

  @override
  void onClose() {
    _expiry?.cancel();
    super.onClose();
  }
}
