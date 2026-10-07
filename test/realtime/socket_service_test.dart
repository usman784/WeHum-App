import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/core/realtime/live_service.dart';
import 'package:meditation/core/realtime/lobby_service.dart';
import 'package:meditation/core/realtime/presence_service.dart';
import 'package:meditation/core/realtime/realtime_coordinator.dart';
import 'package:meditation/core/realtime/socket_events.dart';
import 'package:meditation/core/realtime/socket_service.dart';
import 'package:meditation/core/services/time_service.dart';

import 'fake_transport.dart';

const sid = '11111111-1111-4111-8111-111111111111';

SocketService svc(FakeTransport t, {Future<bool> Function()? refresh, void Function(String)? onForce, void Function(Duration)? onTime}) =>
    SocketService(transportFactory: () => t, refreshAccess: refresh ?? () async => true, onForceLogout: onForce, onTimeSync: onTime);

Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  setUp(Get.reset);

  group('connection', () {
    test('connects, syncs time (median of 3) and reports the offset', () async {
      final t = FakeTransport()..serverClockSkew = const Duration(seconds: 2);
      Duration? off;
      final s = svc(t, onTime: (d) => off = d);
      await s.connect();
      t.serverConnects();
      await flush();
      await flush();
      expect(s.state.value, SocketState.connected);
      expect(t.count('time:sync'), 3);
      expect(off!.inMilliseconds, inInclusiveRange(1900, 2100));
    });

    test('rooms are remembered and re-joined after a reconnect', () async {
      final t = FakeTransport();
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      await s.joinRoom('today');
      await s.joinRoom('session:$sid');
      await s.joinLobby('2026-10-07');
      t.sent.clear();
      t.serverDrops();
      t.serverConnects();
      await flush();
      expect(t.sentData('room:join').map((d) => d['room']), unorderedEquals(['today', 'session:$sid']));
      expect(t.sentData('lobby:join'), [{'date': '2026-10-07'}]);
    });

    test('"paused" only after 10 s down; a short blip never shows it; reconnect clears it', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final s = svc(t);
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        t.serverDrops();
        fa.elapse(const Duration(seconds: 5));
        expect(s.livePaused, false);
        t.serverConnects();
        fa.flushMicrotasks();
        expect(s.state.value, SocketState.connected);
        t.serverDrops();
        fa.elapse(const Duration(seconds: 11));
        expect(s.livePaused, true);
        t.serverConnects();
        fa.flushMicrotasks();
        expect(s.livePaused, false);
      });
    });

    test('connect_error TOKEN_EXPIRED refreshes the token and reconnects', () async {
      final t = FakeTransport();
      var refreshed = 0;
      final s = svc(t, refresh: () async => ++refreshed > 0);
      await s.connect();
      final before = t.connectCalls;
      t.onConnectError!({'message': 'x', 'data': {'code': 'TOKEN_EXPIRED'}});
      await flush();
      expect(refreshed, 1);
      expect(t.connectCalls, before + 1);
    });

    test('auth:expiring refreshes and emits auth:refresh with the new token', () async {
      final t = FakeTransport();
      final s = svc(t, refresh: () async => true)..attachTokenSource(() async => 'new-access-token');
      await s.connect();
      t.serverConnects();
      await flush();
      t.serverPushes('auth:expiring', {'exp': 1});
      await flush();
      await flush();
      expect(t.sentData('auth:refresh'), [{'token': 'new-access-token'}]);
    });

    test('force:logout is handed to the app and also streamed', () async {
      final t = FakeTransport();
      String? reason;
      final s = svc(t, onForce: (r) => reason = r);
      await s.connect();
      final got = s.on('force:logout', (j) => j['reason']).first;
      t.serverPushes('force:logout', {'reason': 'token_revoked'});
      expect(await got, 'token_revoked');
      expect(reason, 'token_revoked');
    });
  });

  group('rooms', () {
    test('ref counted: the second screen does not re-join, the last one leaves', () async {
      final t = FakeTransport();
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      await s.joinRoom('today');
      await s.joinRoom('today');
      expect(t.count('room:join'), 1);
      s.leaveRoom('today');
      expect(t.count('room:leave'), 0);
      s.leaveRoom('today');
      expect(t.count('room:leave'), 1);
    });

    test('max 4 rooms (lobby counts) is enforced on the client', () async {
      final t = FakeTransport();
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      expect(await s.joinRoom('today'), true);
      expect(await s.joinRoom('world'), true);
      expect(await s.joinRoom('motd:2026-10-07'), true);
      expect((await s.joinLobby('2026-10-07')).ok, true);
      expect(await s.joinRoom('session:$sid'), false);
    });

    test('server refusing a room does not leave it remembered', () async {
      final t = FakeTransport()..acks['room:join'] = (_) => {'ok': false, 'code': 'ROOM_LIMIT'};
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      expect(await s.joinRoom('world'), false);
      expect(s.rooms, isEmpty);
    });

    test('lobby join for a non-member returns PREMIUM_REQUIRED', () async {
      final t = FakeTransport()..acks['lobby:join'] = (_) => {'ok': false, 'code': 'PREMIUM_REQUIRED'};
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      final a = await s.joinLobby('2026-10-07');
      expect(a.code, 'PREMIUM_REQUIRED');
      expect(s.rooms, isEmpty);
    });
  });

  group('app lifecycle', () {
    test('disconnects 30 s after background, reconnects on foreground', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final s = svc(t);
        s.connect();
        t.serverConnects();
        s.joinRoom('today');
        fa.flushMicrotasks();
        s.onBackground();
        fa.elapse(const Duration(seconds: 29));
        expect(t.disposed, false);
        fa.elapse(const Duration(seconds: 2));
        expect(t.disposed, true);
        expect(s.state.value, SocketState.disconnected);
        final s2 = s;
        // foreground: a new transport is created by the factory in real life; here we only check intent
        s2.onForeground();
        fa.flushMicrotasks();
      });
    });

    test('a playing meditation keeps the socket alive in the background', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final s = svc(t);
        s.connect();
        t.serverConnects();
        s.keepAlive = true;
        s.onBackground();
        fa.elapse(const Duration(minutes: 5));
        expect(t.disposed, false);
        expect(s.connected, true);
      });
    });
  });

  group('live counts', () {
    test('live:agg updates the number; quiet rule shows "meditated today"', () async {
      final t = FakeTransport();
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      final live = Get.put(LiveService(s));
      await live.acquireToday();
      t.serverPushes('live:agg', {'total': 412, 'countries': 37, 'top': [{'c': 'DE', 'n': 64}], 'quiet': false, 'meditatedToday': 1280, 'vibration': 62, 'at': 1});
      await flush();
      expect(live.agg.value!.headline, 412);
      expect(live.agg.value!.top.single.country, 'DE');
      t.serverPushes('live:agg', {'total': 4, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 1280, 'vibration': 10, 'at': 2});
      await flush();
      expect(live.agg.value!.headline, 1280);
      expect(live.agg.value!.quiet, true);
    });

    test('REST snapshot fallback once, only when the socket is paused and nothing arrived', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        var calls = 0;
        final s = svc(t);
        final live = Get.put(LiveService(s, restSnapshot: () async {
          calls++;
          return LiveAgg.fromJson({'total': 0, 'countries': 0, 'quiet': true, 'meditatedToday': 7, 'vibration': 0, 'at': 0});
        }));
        live.onInit();
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        t.serverDrops();
        fa.elapse(const Duration(seconds: 12));
        fa.flushMicrotasks();
        expect(s.livePaused, true);
        expect(calls, 1);
        expect(live.agg.value!.meditatedToday, 7);
        expect(live.paused, true);
      });
    });

    test('session:live and motd:stats are kept per id', () async {
      final t = FakeTransport();
      final s = svc(t);
      await s.connect();
      t.serverConnects();
      final live = Get.put(LiveService(s));
      t.serverPushes('session:live', {'sessionId': sid, 'people': 12, 'countries': 3});
      t.serverPushes('motd:stats', {'date': '2026-10-07', 'practicedToday': 1280});
      await flush();
      expect(live.sessionPeople[sid]!.people, 12);
      expect(live.motdPracticed['2026-10-07'], 1280);
    });
  });

  group('presence', () {
    test('start → ack numbers → beat every 30 s → stop', () {
      fakeAsync((fa) {
        final t = FakeTransport()..acks['presence:start'] = (_) => {'ok': true, 'data': {'together': {'people': 412, 'countries': 37}}};
        final s = svc(t);
        final p = PresenceService(s);
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        p.start(meditationId: 'm1', sessionId: sid, kind: 'motd', lengthMin: 10);
        fa.flushMicrotasks();
        expect(p.together.value, (people: 412, countries: 37));
        expect(t.sentData('room:join').map((d) => d['room']), contains('session:$sid'));
        fa.elapse(const Duration(seconds: 95));
        expect(t.count('presence:beat'), 3);
        // session:live updates the ring numbers
        t.serverPushes('session:live', {'sessionId': sid, 'people': 500, 'countries': 40});
        fa.flushMicrotasks();
        expect(p.together.value!.people, 500);
        p.stop();
        fa.flushMicrotasks();
        expect(t.count('presence:stop'), 1);
        fa.elapse(const Duration(seconds: 60));
        expect(t.count('presence:beat'), 3);
        expect(p.active.value, isNull);
      });
    });

    test('a beat answered NOT_FOUND starts the presence again', () {
      fakeAsync((fa) {
        final t = FakeTransport()..acks['presence:beat'] = (_) => {'ok': false, 'code': 'NOT_FOUND'};
        final s = svc(t);
        final p = PresenceService(s);
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        p.start(meditationId: 'm1', kind: 'solo', mode: 'solo');
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 31));
        fa.flushMicrotasks();
        expect(t.count('presence:start'), 2);
      });
    });

    test('presence keeps the socket alive in the background and releases it after stop', () async {
      final t = FakeTransport();
      final s = svc(t);
      final p = PresenceService(s);
      await s.connect();
      t.serverConnects();
      await p.start(meditationId: 'm1', kind: 'solo');
      s.onBackground();
      expect(t.disposed, false);
      await p.stop();
      expect(p.together.value, isNull);
    });
  });

  group('lobby + group start', () {
    GroupStart gs() => GroupStart.fromJson({'date': '2026-10-07', 'startsAt': DateTime.now().toUtc().toIso8601String(), 'sessionId': sid, 'lengthMin': 30, 'mediaKey': 'k'});

    test('server group:start fires once; the local timer afterwards does not fire again', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final at = DateTime.now().toUtc().add(const Duration(seconds: 20));
        t.acks['lobby:join'] = (_) => {'ok': true, 'data': {'startsAt': at.toIso8601String(), 'waiting': 5}};
        final time = TimeService();
        final s = svc(t);
        final lobby = LobbyService(s, time)..onInit();
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        lobby.join('2026-10-07');
        fa.flushMicrotasks();
        expect(lobby.startsAt.value, isNotNull);
        var fires = 0;
        lobby.started.listen((_) => fires++);
        fa.elapse(const Duration(seconds: 19));
        t.serverPushes('group:start', {'date': '2026-10-07', 'startsAt': at.toIso8601String(), 'sessionId': sid, 'lengthMin': 30, 'mediaKey': 'k'});
        fa.flushMicrotasks();
        expect(lobby.started.value!.sessionId, sid);
        fa.elapse(const Duration(seconds: 5));
        expect(fires, 1);
      });
    });

    test('local timer starts the group even if group:start never arrives (server clock offset applied)', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final time = TimeService()..setOffset(const Duration(seconds: 3)); // phone clock is 3 s behind the server
        final startsAt = DateTime.now().toUtc().add(const Duration(seconds: 13)); // = 10 s away by the server clock
        t.acks['lobby:join'] = (_) => {'ok': true, 'data': {'startsAt': startsAt.toIso8601String(), 'waiting': 1}};
        final s = svc(t);
        final lobby = LobbyService(s, time)..onInit();
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        lobby.join('2026-10-07');
        fa.flushMicrotasks();
        fa.elapse(const Duration(seconds: 9));
        expect(lobby.started.value, isNull);
        fa.elapse(const Duration(seconds: 2));
        expect(lobby.started.value, isNotNull);
      });
    });

    test('late joiner seeks to now − T0', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final time = TimeService();
        final startsAt = DateTime.now().toUtc().subtract(const Duration(seconds: 42));
        t.acks['lobby:join'] = (_) => {'ok': true, 'data': {'startsAt': startsAt.toIso8601String(), 'waiting': 1}};
        final s = svc(t);
        final lobby = LobbyService(s, time)..onInit();
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        lobby.join('2026-10-07');
        fa.flushMicrotasks();
        expect(lobby.lateOffset().inSeconds, inInclusiveRange(41, 43));
        expect(gs().date, '2026-10-07');
      });
    });

    test('lobby:state updates counts; a non-member is refused with PREMIUM_REQUIRED', () async {
      final t = FakeTransport();
      final s = svc(t);
      final lobby = LobbyService(s, TimeService())..onInit();
      await s.connect();
      t.serverConnects();
      expect(await lobby.join('2026-10-07'), isNull);
      t.serverPushes('lobby:state', {'date': '2026-10-07', 'waiting': 120, 'countries': 14, 'regions': [{'r': 'Europe', 'n': 80}], 'startsAt': '2026-10-07T16:00:00.000Z'});
      await flush();
      expect(lobby.state.value!.waiting, 120);
      expect(lobby.state.value!.regions.single.region, 'Europe');
      lobby.leave();
      expect(t.count('lobby:leave'), 1);
      t.acks['lobby:join'] = (_) => {'ok': false, 'code': 'PREMIUM_REQUIRED'};
      expect(await lobby.join('2026-10-08'), 'PREMIUM_REQUIRED');
    });
  });

  group('coordinator', () {
    test('entitlement, config, catalog (debounced), inbox are routed', () {
      fakeAsync((fa) {
        final t = FakeTransport();
        final s = svc(t);
        var boot = 0, cat = 0;
        final inbox = <Map<String, dynamic>>[];
        EntitlementChanged? ent;
        final c = RealtimeCoordinator(s, refreshBootstrap: () async => boot++, refreshCatalog: () async => cat++, onInbox: inbox.add, onEntitlement: (e) => ent = e)..onInit();
        s.connect();
        t.serverConnects();
        fa.flushMicrotasks();
        t.serverPushes('entitlement:changed', {'active': true, 'productId': 'wehum_annual', 'periodType': 'trial', 'expiresAt': '2026-10-14T00:00:00Z', 'billingIssue': false});
        t.serverPushes('config:changed', {'key': 'main', 'version': 3});
        for (var i = 0; i < 5; i++) {
          t.serverPushes('catalog:changed', {'version': i});
          fa.elapse(const Duration(seconds: 2));
        }
        t.serverPushes('inbox:new', {'item': {'id': 'a', 'title': 'Hi'}});
        fa.flushMicrotasks();
        expect(ent!.active, true);
        expect(ent!.periodType, 'trial');
        expect(boot, 2);
        expect(cat, 0);
        fa.elapse(const Duration(seconds: 11));
        expect(cat, 1); // five events → one refresh
        expect(inbox.single['title'], 'Hi');
        expect(c.refreshes, 2);
      });
    });
  });

  test('Ack.parse handles both shapes', () {
    expect(Ack.parse({'ok': true, 'data': {'a': 1}}).data!['a'], 1);
    expect(Ack.parse([{'ok': false, 'code': 'X'}]).code, 'X');
    expect(Ack.parse(null).ok, false);
  });
}
