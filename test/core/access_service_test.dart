import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/realtime/socket_events.dart';
import 'package:meditation/core/services/access_service.dart';

MeProfile profile(String id, {Entitlement e = const Entitlement()}) => MeProfile(id: id, isGuest: false, entitlement: e);
EntitlementChanged ev({required bool active, String source = 'beta', int? rev, String? userId, DateTime? expires}) =>
    EntitlementChanged(active: active, source: source, rev: rev, userId: userId, expiresAt: expires, betaExpiresAt: source.contains('beta') ? expires : null);

void main() {
  late AccessService access;
  setUp(() => access = AccessService());

  group('beta access arriving live', () {
    test('a grant unlocks the app without a new login, a removal locks it again', () {
      access.setFromProfile(profile('u1'));
      expect(access.isMember, isFalse);
      access.onSocket(ev(active: true, rev: 1, userId: 'u1', expires: DateTime.now().add(const Duration(days: 3))));
      expect(access.isMember, isTrue);
      expect(access.entitlement.value.source, 'beta');
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'u1'));
      expect(access.isMember, isFalse);
    });

    test('an older or repeated event never overwrites a newer one', () {
      access.setFromProfile(profile('u1'));
      access.onSocket(ev(active: false, source: 'none', rev: 5, userId: 'u1'));
      access.onSocket(ev(active: true, rev: 4, userId: 'u1')); // the grant arrives late
      expect(access.isMember, isFalse);
      access.onSocket(ev(active: true, rev: 5, userId: 'u1')); // same revision again
      expect(access.isMember, isFalse);
      access.onSocket(ev(active: true, rev: 6, userId: 'u1'));
      expect(access.isMember, isTrue);
    });

    test('a profile read that started before a newer event cannot roll the state back', () {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 3)));
      access.onSocket(ev(active: false, source: 'none', rev: 4, userId: 'u1'));
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 3))); // the slow, older answer
      expect(access.isMember, isFalse);
      expect(access.entitlement.value.rev, 4);
    });
  });

  group('stale store (SDK) state', () {
    test('after a revocation a cached SDK "yes" does not keep the app unlocked', () async {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 1)));
      access.sdkPremium.value = true; // an old cache
      access.refreshSdk = () async => false; // the fresh read: nothing in the store
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'u1'));
      expect(access.isMember, isFalse); // locked straight away, while the SDK is being read
      await pumpEventQueue();
      expect(access.sdkPremium.value, isFalse);
      expect(access.isMember, isFalse);
    });

    test('a revocation learned from a profile read (launch, resume, reconnect) also drops a cached SDK "yes"', () async {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 1)));
      access.sdkPremium.value = true; // an old cache
      access.refreshSdk = () async => false;
      access.setFromProfile(profile('u1', e: const Entitlement(rev: 2))); // the app was closed when the beta ended
      expect(access.isMember, isFalse);
      await pumpEventQueue();
      expect(access.sdkPremium.value, isFalse);
      expect(access.isMember, isFalse);
    });

    test('a callback from the SDK in that window is ignored', () async {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 1)));
      access.refreshSdk = () async => false;
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'u1'));
      access.onSdk(true); // delayed callback with the old cache
      expect(access.isMember, isFalse);
      await pumpEventQueue();
      expect(access.isMember, isFalse);
    });

    test('a genuine store subscription survives: the fresh SDK read still says yes', () async {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'paid+beta', rev: 1)));
      access.sdkPremium.value = true;
      access.refreshSdk = () async => true;
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'u1'));
      expect(access.isMember, isFalse); // not trusted until it has been read fresh
      await pumpEventQueue();
      expect(access.isMember, isTrue); // a real subscription the server has not caught up with yet
    });

    test('a paid member whose beta ends keeps access from the server', () {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'paid+beta', rev: 1, productId: 'wehum_annual')));
      access.onSocket(const EntitlementChanged(active: true, source: 'paid', rev: 2, userId: 'u1', productId: 'wehum_annual'));
      expect(access.isMember, isTrue);
      expect(access.entitlement.value.source, 'paid');
    });
  });

  group('account switching', () {
    test('an event meant for the previous account is dropped', () {
      access.setFromProfile(profile('old'));
      access.setFromProfile(profile('new'));
      access.onSocket(ev(active: true, rev: 9, userId: 'old'));
      expect(access.isMember, isFalse);
    });

    test("a switch clears the old account's access and store state", () {
      access.setFromProfile(profile('old', e: const Entitlement(active: true, source: 'beta', rev: 4)));
      access.sdkPremium.value = true;
      access.setFromProfile(profile('new'));
      expect(access.isMember, isFalse);
      expect(access.sdkPremium.value, isFalse);
      expect(access.entitlement.value.rev, 0);
    });

    test('an SDK read that finishes after the switch does not unlock the new account', () async {
      access.setFromProfile(profile('old', e: const Entitlement(active: true, source: 'beta', rev: 1)));
      access.refreshSdk = () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return true;
      };
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'old')); // starts the slow read for "old"
      access.setFromProfile(profile('new'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(access.sdkPremium.value, isFalse);
      expect(access.isMember, isFalse);
    });

    test('sign-out leaves nothing behind', () {
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 3)));
      access.sdkPremium.value = true;
      access.reset();
      expect(access.isMember, isFalse);
      expect(access.userId, isNull);
      expect(access.isGuest.value, isTrue);
    });
  });

  group('expiry on the device', () {
    test('a beta end date that passes while offline locks premium without any event', () {
      var now = DateTime(2026, 11, 3, 12);
      access.clock = () => now;
      access.setFromProfile(profile('u1', e: Entitlement(active: true, source: 'beta', rev: 1, expiresAt: DateTime(2026, 11, 3, 13), betaExpiresAt: DateTime(2026, 11, 3, 13))));
      expect(access.isMember, isTrue);
      now = DateTime(2026, 11, 3, 13, 0, 1);
      expect(access.isMember, isFalse);
    });

    test('a paid subscription is not cut off by the device clock', () {
      var now = DateTime(2026, 11, 3, 12);
      access.clock = () => now;
      access.setFromProfile(profile('u1', e: Entitlement(active: true, source: 'paid', rev: 1, expiresAt: DateTime(2026, 11, 3, 13))));
      now = DateTime(2026, 11, 4);
      expect(access.isMember, isTrue); // the server (or a renewal) decides, not a possibly wrong clock
    });

    test('losing membership removes what belongs to it', () {
      var lost = 0;
      access.onMembershipLost = () => lost++;
      access.setFromProfile(profile('u1', e: const Entitlement(active: true, source: 'beta', rev: 1)));
      access.onSocket(ev(active: false, source: 'none', rev: 2, userId: 'u1'));
      expect(lost, 1);
    });
  });
}
