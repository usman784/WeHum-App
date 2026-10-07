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
  Future<void> ring() async => rings++;
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
      now = now.add(const Duration(minutes: 3));
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
      now = now.add(const Duration(minutes: 2));
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

  test('bells can be switched off', () async {
    final r = Rig();
    r.ctrl.bellStart.value = false;
    r.ctrl.bellEnd.value = false;
    r.ctrl.minutes.value = 5;
    await r.ctrl.enter();
    expect(r.bell.rings, 0);
    expect(r.notif.calls.where((c) => c == 'bell'), isEmpty);
  });

  testWidgets('50/51 screens: honest numbers from live:agg (quiet wording), presets, Enter opens the run screen with the timer', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    await e.socket.connect();
    e.socketServer.serverConnects();
    await t.pumpWidget(e.app(initial: AppRoutes.silenceRoomSetup));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    e.socketServer.serverPushes('live:agg', {'total': 3, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 86, 'vibration': 5, 'at': 1});
    await t.pump();
    await t.pump(const Duration(milliseconds: 20));
    expect(find.text('86'), findsOneWidget);
    expect(find.text('meditated here today'), findsOneWidget);
    expect(find.textContaining('Quiet right now. We never add fake numbers'), findsOneWidget);
    await t.tap(find.text('30 min'));
    await t.pump();
    expect(find.text('30 minutes, then the bell.'), findsOneWidget);
    await t.tap(find.text('Open'));
    await t.pump();
    expect(find.text('No end: finish whenever you like.'), findsOneWidget);
    await t.tap(find.text('10 min'));
    await t.pump();
    await t.pumpWidget(const SizedBox());
    Get.delete<SilenceController>(force: true);
    await e.dispose();
  });
}

void driftOff() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}
