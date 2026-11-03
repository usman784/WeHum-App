import 'dart:async';
import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/network/session_store.dart';
import 'package:meditation/core/services/crash_service.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/realtime/live_service.dart';
import 'package:meditation/core/realtime/presence_service.dart';
import 'package:meditation/core/realtime/socket_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/sync_service.dart';
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/silence/silence_controller.dart';

import '../core/fake_adapter.dart';
import '../realtime/fake_transport.dart';
import '../support/test_env.dart';

class FakeBell implements BellPlayer {
  int rings = 0;
  @override
  Future<void> ring({String? url}) async => rings++;
  @override
  Future<void> dispose() async {}
}

class FakeScreen implements ScreenPort {
  final log = <String>[];
  @override
  Future<void> dim() async => log.add('dim');
  @override
  Future<void> restore() async => log.add('restore');
  @override
  Future<void> keepAwake(bool on) async => log.add(on ? 'awake' : 'sleep');
}

/// keepAwake waits like a slow device; stands in for every slow step before the bell.
class _SlowScreen extends FakeScreen {
  _SlowScreen(this.gate);
  final Future<void> gate;
  @override
  Future<void> keepAwake(bool on) async {
    if (on) await gate;
    log.add(on ? 'awake' : 'sleep');
  }
}

class FakeSilenceNav implements SilenceNav {
  final events = <String>[];
  CompleteArgs? complete;
  @override
  void toRun() => events.add('run');
  @override
  void toComplete(CompleteArgs a) {
    events.add('complete');
    complete = a;
  }

  @override
  void back() => events.add('back');
}

class Rig {
  Rig() {
    Get.reset();
    transport = FakeTransport();
    socket = SocketService(transportFactory: () => transport, refreshAccess: () async => true);
    presence = PresenceService(socket);
    Get.put(socket);
    live = Get.put(LiveService(socket));
    db = AppDatabase.memory();
    meditations = MockMeditationRepository();
    sync = SyncService(meditations, db);
    notif = FakeNotifications(MockMeRepository(), SessionStore(MemoryKv()), CrashService());
    bell = FakeBell();
    screen = FakeScreen();
    nav = FakeSilenceNav();
    ctrl = SilenceController(bell: bell, screen: screen, sync: sync, presence: presence, notifications: notif, analytics: AnalyticsService(), nav: nav);
  }
  late FakeTransport transport;
  late SocketService socket;
  late PresenceService presence;
  late LiveService live;
  late AppDatabase db;
  late MockMeditationRepository meditations;
  late SyncService sync;
  late FakeNotifications notif;
  late FakeBell bell;
  late FakeScreen screen;
  late FakeSilenceNav nav;
  late SilenceController ctrl;
}

void main() {
  setUp(() => driftOff());

  test('timer is computed from timestamps: 30 minutes in the background is still 30 minutes (±1 s)', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final r = Rig();
      r.ctrl.minutes.value = 30;
      await r.ctrl.enter();
      expect(r.ctrl.phase.value, SilencePhase.running);
      expect(r.nav.events, ['run']);
      now = now.add(SilenceController.openingGap); // the opening bell rings, then 3 s of quiet before the timer starts
      now = now.add(const Duration(minutes: 12, seconds: 31)); // phone was suspended: no timer ticks happened
      r.ctrl.refreshTime(); // what runs when the app returns
      expect(r.ctrl.remaining.value.inSeconds, 30 * 60 - (12 * 60 + 31));
      now = now.add(const Duration(minutes: 17, seconds: 29));
      r.ctrl.refreshTime();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.ctrl.phase.value, SilencePhase.done);
      expect(r.ctrl.elapsed.value.inSeconds, 30 * 60);
      expect(r.bell.rings, 2); // start and end
      expect(r.nav.events, ['run', 'complete']);
      expect(r.nav.complete!.record!.kind, 'silence');
      expect(r.nav.complete!.record!.durationSec, 1800);
    });
  });

  test('pause stops the clock; resume continues; the end bell notification is rescheduled for the new end time', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final r = Rig();
      r.ctrl.minutes.value = 10;
      await r.ctrl.enter();
      now = now.add(SilenceController.openingGap + const Duration(minutes: 3));
      r.ctrl.pause();
      expect(r.ctrl.phase.value, SilencePhase.paused);
      expect(r.notif.calls, contains('cancelBell'));
      now = now.add(const Duration(minutes: 20)); // paused for 20 minutes
      r.ctrl.refreshTime();
      expect(r.ctrl.elapsed.value, const Duration(minutes: 3));
      r.ctrl.resume();
      now = now.add(const Duration(minutes: 7));
      r.ctrl.refreshTime();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.ctrl.phase.value, SilencePhase.done);
      expect(r.notif.calls.where((c) => c == 'bell').length, 2);
    });
  });

  test('presence in silence mode over the socket, with the right kind; stopped at the end', () async {
    final r = Rig();
    await r.socket.connect();
    r.transport.serverConnects();
    r.ctrl.minutes.value = 5;
    await r.ctrl.enter();
    final start = r.transport.sentData('presence:start').single as Map;
    expect(start['mode'], 'silence');
    expect(start['kind'], 'silence');
    expect(start['lengthMin'], 5);
    await r.ctrl.finish(completed: false);
    expect(r.transport.count('presence:stop'), 1);
  });

  test('open-ended counts up; no end bell is scheduled; ending under 3 minutes records nothing and closes', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final r = Rig();
      r.ctrl.minutes.value = 0;
      await r.ctrl.enter();
      expect(r.notif.calls.where((c) => c == 'bell'), isEmpty);
      now = now.add(SilenceController.openingGap + const Duration(minutes: 2));
      r.ctrl.refreshTime();
      expect(r.ctrl.elapsed.value, const Duration(minutes: 2));
      await r.ctrl.finish(completed: false);
      expect(r.nav.events.last, 'back');
      expect(r.meditations.recorded, isEmpty);
    });
  });

  test('dims after 5 seconds, tap wakes it and dims again; screen kept awake and restored at the end', () {
    fakeAsync((fa) {
      final r = Rig();
      r.ctrl.minutes.value = 15;
      r.ctrl.enter();
      fa.flushMicrotasks();
      expect(r.ctrl.dimmed.value, false);
      fa.elapse(const Duration(seconds: 6));
      expect(r.ctrl.dimmed.value, true);
      expect(r.screen.log, containsAllInOrder(['awake', 'dim']));
      r.ctrl.wake();
      expect(r.ctrl.dimmed.value, false);
      fa.elapse(const Duration(seconds: 6));
      expect(r.ctrl.dimmed.value, true);
      r.ctrl.finish(completed: false);
      fa.flushMicrotasks();
      expect(r.screen.log.last, 'sleep');
      expect(r.screen.log, contains('restore'));
    });
  });

  test('opening bell, then 3 seconds of quiet, then the meditation starts; the gap is not counted or pausable', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final r = Rig();
      r.ctrl.minutes.value = 5;
      await r.ctrl.enter();
      expect(r.bell.rings, 1); // the bell rings at once
      expect(r.ctrl.settleLeft.value, 3);
      expect(r.ctrl.remaining.value, const Duration(minutes: 5));
      now = now.add(const Duration(seconds: 1));
      r.ctrl.refreshTime();
      expect(r.ctrl.settleLeft.value, 2);
      r.ctrl.pause(); // not during the gap
      expect(r.ctrl.phase.value, SilencePhase.running);
      now = now.add(const Duration(seconds: 1));
      r.ctrl.refreshTime();
      expect(r.ctrl.settleLeft.value, 1);
      expect(r.ctrl.elapsed.value, Duration.zero);
      now = now.add(const Duration(seconds: 1)); // 3 s after the bell: the timer starts
      r.ctrl.refreshTime();
      expect(r.ctrl.settleLeft.value, 0);
      expect(r.ctrl.remaining.value, const Duration(minutes: 5));
      now = now.add(const Duration(minutes: 5));
      r.ctrl.refreshTime();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(r.ctrl.phase.value, SilencePhase.done);
      expect(r.bell.rings, 2); // opening and closing
      expect(r.nav.complete!.record!.durationSec, 300); // the 3-second gap is not part of the meditation
      expect(r.nav.complete!.record!.startedAt, DateTime.utc(2026, 10, 7, 8, 0, 3));
    });
  });

  test('Begin opens the run screen at once; the bell and "Begins in 3" start together, slow device work does not hold them', () async {
    final r = Rig();
    final slow = Completer<void>();
    r.ctrl = SilenceController(bell: r.bell, screen: _SlowScreen(slow.future), sync: r.sync, presence: r.presence, notifications: r.notif, analytics: AnalyticsService(), nav: r.nav);
    r.ctrl.minutes.value = 5;
    final done = r.ctrl.enter();
    await Future<void>.delayed(Duration.zero);
    expect(r.nav.events, ['run']); // the meditation screen right away
    expect(r.bell.rings, 1); // the bell rings as the countdown starts
    expect(r.ctrl.settleLeft.value, 3);
    expect(r.ctrl.remaining.value, const Duration(minutes: 5));
    slow.complete();
    await done;
    expect(r.nav.events, ['run']);
    expect(r.bell.rings, 1);
  });

  test('no opening bell: no gap, the timer starts at once', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final r = Rig();
      r.ctrl.bellStart.value = false;
      r.ctrl.minutes.value = 5;
      await r.ctrl.enter();
      expect(r.ctrl.settleLeft.value, 0);
      now = now.add(const Duration(seconds: 2));
      r.ctrl.refreshTime();
      expect(r.ctrl.elapsed.value, const Duration(seconds: 2));
    });
  });

  test('bells can be switched off', () async {
    final r = Rig();
    r.ctrl.bellStart.value = false;
    r.ctrl.bellEnd.value = false;
    r.ctrl.minutes.value = 5;
    await r.ctrl.enter();
    expect(r.bell.rings, 0);
    expect(r.notif.calls.where((c) => c == 'bell'), isEmpty);
  });

  testWidgets('50/51 screens: honest numbers from the silence room (busy, then quiet), durations, Enter opens the run screen with the timer', (t) async {
    phone(t);
    t.view.physicalSize = const Size(1170, 6000); // the whole page is built
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await e.socket.connect();
    e.socketServer.serverConnects();
    final bell = FakeBell();
    Get.put(SilenceController(bell: bell, screen: FakeScreen())); // no real audio / wakelock plugins in a widget test
    await t.pumpWidget(e.app(initial: AppRoutes.silenceRoomSetup));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    // snapshot from GET /v1/silence: busy room
    expect(find.text('214 MEDITATING IN SILENCE NOW'), findsOneWidget);
    expect(find.byKey(const Key('silence-belts')), findsOneWidget);
    // the room's connection with the world: map + where people are meditating, from the setup snapshot
    expect(find.byKey(const Key('silence-where')), findsOneWidget);
    expect(find.text('WHERE PEOPLE ARE MEDITATING'), findsOneWidget);
    expect(find.text('4 COUNTRIES LIVE'), findsOneWidget);
    expect(find.text('United Kingdom'), findsOneWidget);
    expect(find.text('61 meditating now'), findsOneWidget);
    // a socket update moves the map and the list at once (no reload)
    e.socketServer.serverPushes('silence:live', {'people': 5, 'countries': 2, 'top': [{'c': 'PK', 'n': 3}, {'c': 'DE', 'n': 2}], 'todayTop': [], 'belts': {'americas': 0, 'emea': 2, 'apac': 3}, 'quiet': false, 'at': 1});
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text('2 COUNTRIES LIVE'), findsOneWidget);
    expect(find.byKey(const Key('silence-country-PK')), findsOneWidget);
    expect(find.text('3 meditating now'), findsOneWidget);
    expect(find.text('United Kingdom'), findsNothing);
    // the room empties: the quiet variant shows the day's total and the honest-presence note
    e.socketServer.serverPushes('silence:live', {'people': 3, 'countries': 2, 'top': [{'c': 'DE', 'n': 2}, {'c': 'US', 'n': 1}], 'todayTop': [{'c': 'JP', 'n': 4}], 'belts': {'americas': 1, 'emea': 2, 'apac': 0}, 'quiet': true, 'at': 1});
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text('842'), findsOneWidget);
    expect(find.text('meditated in this room today'), findsOneWidget);
    expect(find.text('2 COUNTRIES LIVE'), findsOneWidget); // a quiet room still shows where its few people are
    expect(find.text('3 quietly right now · across 3 zones'), findsOneWidget);
    expect(find.byKey(const Key('honest-card')), findsOneWidget);
    // the room empties: the map and list switch to where people meditated in silence today
    e.socketServer.serverPushes('silence:live', {'people': 0, 'countries': 0, 'top': [], 'todayTop': [{'c': 'JP', 'n': 4}], 'belts': {'americas': 0, 'emea': 0, 'apac': 0}, 'quiet': true, 'at': 2});
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text('WHERE PEOPLE MEDITATED TODAY'), findsOneWidget);
    expect(find.text('4 today'), findsOneWidget);
    await t.tap(find.byKey(const Key('dur-30')));
    await t.pump();
    expect(find.textContaining('30 minutes, then the bell.'), findsOneWidget);
    // no breathing labels in a meditation: no cadence chip, no "Breathing cue" line
    expect(find.textContaining('CADENCE'), findsNothing);
    expect(find.textContaining('Breathing cue'), findsNothing);
    await t.tap(find.byKey(const Key('dur-0')));
    await t.pump();
    expect(find.text('No end: finish whenever you like.'), findsOneWidget);
    await t.tap(find.byKey(const Key('dur-10')));
    await t.pump();
    // the run screen: the timer, and no "Breathe in / Breathe out" words over the ring
    expect(find.text('SELECT MEDITATION DURATION'), findsOneWidget); // "meditation", not "sit"
    await t.tap(find.byKey(const Key('silence-enter')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    // the bell rings, then 3 seconds of quiet, counted down live before the timer starts
    expect(bell.rings, 1);
    expect(find.text('BEGINS IN 3'), findsOneWidget);
    expect(find.byKey(const Key('silence-where-line')), findsOneWidget); // the run screen keeps the world in view
    expect(find.textContaining('Meditated here today in'), findsOneWidget);
    e.socketServer.serverPushes('silence:live', {'people': 2, 'countries': 1, 'top': [{'c': 'PK', 'n': 2}], 'todayTop': [], 'belts': {'americas': 0, 'emea': 0, 'apac': 2}, 'quiet': true, 'at': 3});
    await t.pump();
    expect(find.textContaining('Meditating now in'), findsOneWidget);
    expect(find.textContaining('Pakistan 2'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('End meditation'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('BEGINS IN 2'), findsOneWidget);
    expect(find.byKey(const Key('silence-time')), findsOneWidget);
    expect(find.byKey(const Key('breath-cue')), findsNothing);
    expect(find.textContaining('Breathe'), findsNothing);
    await t.tap(find.byKey(const Key('silence-end'))); // ending in the gap records nothing and stops the timers
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.pumpWidget(const SizedBox());
    Get.delete<SilenceController>(force: true);
    await e.dispose();
  });
  testWidgets('51 End meditation asks "Are you sure you want to end early?": No carries on, Yes ends; the map stays on the run screen', (t) async {
    phone(t);
    t.view.physicalSize = const Size(1170, 6000); // the whole setup page is built
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await e.socket.connect();
    e.socketServer.serverConnects();
    Get.put(SilenceController(bell: FakeBell(), screen: FakeScreen()));
    await t.pumpWidget(e.app(initial: AppRoutes.silenceRoomSetup));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('silence-enter')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    expect(find.byKey(const Key('silence-where-compact')), findsOneWidget); // the map is part of the sit, on any phone height
    await t.tap(find.byKey(const Key('silence-end')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Are you sure you want to end early?'), findsOneWidget);
    await t.tap(find.byKey(const Key('silence-end-keep')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.text('Are you sure you want to end early?'), findsNothing);
    expect(find.byKey(const Key('silence-time')), findsOneWidget); // still meditating
    await t.tap(find.byKey(const Key('silence-end')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await t.tap(find.byKey(const Key('silence-end-confirm')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('silence-time')), findsNothing);
    await t.pumpWidget(const SizedBox());
    Get.delete<SilenceController>(force: true);
    await e.dispose();
  });
}

void driftOff() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}
