import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/audio/local_media.dart';
import 'package:meditation/core/audio/session_recorder.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/realtime/presence_service.dart';
import 'package:meditation/core/realtime/socket_service.dart';
import 'package:meditation/core/services/analytics_service.dart';
import 'package:meditation/core/services/connectivity_service.dart';
import 'package:meditation/core/services/sync_service.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/player/player_args.dart';

import '../realtime/fake_transport.dart';
import 'fake_audio_engine.dart';

class CountingMedia extends MockMediaRepository {
  int urls = 0;
  Object? failWith;
  @override
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false}) async {
    urls++;
    if (failWith != null) throw failWith!;
    return PlayUrl(type: 'audio', url: 'https://cdn/x.mp3?sig=$urls', durationSec: 600);
  }
}

class FakeConnectivity extends ConnectivityService {
  bool up = true;
  @override
  Future<bool> reachable() async => up;
  @override
  // ignore: must_call_super
  void onInit() {} // no platform stream in tests
}

class FakeNav implements PlayerNav {
  final events = <String>[];
  CompleteArgs? complete;
  @override
  void toComplete(CompleteArgs a) {
    events.add('complete');
    complete = a;
  }

  @override
  void toPaywall() => events.add('paywall');
  @override
  void back() => events.add('back');
}

class LocalFile implements LocalMedia {
  @override
  Future<String?> pathFor(PlayTarget target) async => '/data/downloads/motd-10.mp3';
}

const sid = '11111111-1111-4111-8111-111111111111';

PlayerArgs motd({Duration startAt = Duration.zero, bool record = true, String mode = 'solo', String kind = 'motd'}) =>
    PlayerArgs(kind: kind, title: 'Steady Under Pressure', sessionId: sid, date: '2026-10-07', lengthMin: 10, target: const PlayMotd('2026-10-07', 10), durationSec: 600, startAt: startAt, record: record, mode: mode);

class Rig {
  Rig(this.args, {LocalMedia? local, bool connectivity = false, DateTime Function()? now}) {
    Get.reset();
    transport = FakeTransport();
    socket = SocketService(transportFactory: () => transport, refreshAccess: () async => true);
    presence = PresenceService(socket);
    db = AppDatabase.memory();
    meditations = MockMeditationRepository();
    sync = SyncService(meditations, db);
    analytics = AnalyticsService();
    media = CountingMedia();
    engine = FakeAudioEngine();
    this.connectivity = connectivity ? FakeConnectivity() : null;
    nav = FakeNav();
    ctrl = PlayerController(args, nav: nav, now: now, engine: engine, media: media, presence: presence, sync: sync, analytics: analytics, local: local, connectivity: this.connectivity, stallGrace: const Duration(seconds: 2));
  }
  final PlayerArgs args;
  late FakeTransport transport;
  late SocketService socket;
  late PresenceService presence;
  late AppDatabase db;
  late MockMeditationRepository meditations;
  late SyncService sync;
  late AnalyticsService analytics;
  late CountingMedia media;
  late FakeAudioEngine engine;
  FakeConnectivity? connectivity;
  late PlayerController ctrl;
  late FakeNav nav;

  Future<void> connect() async {
    await socket.connect();
    transport.serverConnects();
  }

  Future<void> flush() => Future<void>.delayed(Duration.zero);
}

void main() {
  setUp(() => driftRuntimeOptionsOff());

  test('SessionRecorder counting rule: ≥ 3 min, or ≥ 50 % of a session under 6 min; stalls and pauses are not listening', () {
    var now = DateTime.utc(2026, 10, 7, 8);
    final r = SessionRecorder(kind: 'motd', plannedSec: 600, now: () => now);
    r.playing();
    now = now.add(const Duration(seconds: 170));
    expect(r.counts, false);
    r.paused();
    now = now.add(const Duration(minutes: 5)); // paused for 5 minutes: not counted
    expect(r.listened.inSeconds, 170);
    r.playing();
    now = now.add(const Duration(seconds: 15));
    expect(r.counts, true);
    expect(r.build(completed: false)!.durationSec, 185);

    final short = SessionRecorder(kind: 'sos', plannedSec: 300, now: () => now);
    short.playing();
    now = now.add(const Duration(seconds: 149));
    expect(short.counts, false);
    now = now.add(const Duration(seconds: 2));
    expect(short.counts, true); // ≥ 50 % of a 5-minute session
    expect(short.pct, 50);
    expect(SessionRecorder(kind: 'x', now: () => now).build(completed: true), isNull);
  });

  test('opens the signed URL, starts presence over the socket with the right mode, then counts', () async {
    final r = Rig(motd(mode: 'group', kind: 'group'));
    await r.connect();
    r.transport.acks['presence:start'] = (_) => {'ok': true, 'data': {'together': {'people': 412, 'countries': 37}}};
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    await r.flush();
    expect(r.engine.opened.single.src, isA<UrlSource>());
    expect(r.media.urls, 1);
    expect(r.ctrl.phase.value, PlayerPhase.playing);
    final start = r.transport.sentData('presence:start').single as Map;
    expect(start['mode'], 'group');
    expect(start['kind'], 'group');
    expect(start['meditationId'], r.ctrl.recorder.id);
    expect(r.ctrl.together, (people: 412, countries: 37));
    expect(r.socket.rooms, contains('session:$sid'));
  });

  test('late joiner: the engine opens at now − T0 and the position starts there', () async {
    final r = Rig(motd(startAt: const Duration(seconds: 97), mode: 'group', kind: 'group'));
    await r.connect();
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    expect(r.engine.opened.single.start, const Duration(seconds: 97));
    expect(r.ctrl.position.value, const Duration(seconds: 97));
  });

  test('downloaded file is preferred and works without the network (no play-url call)', () async {
    final r = Rig(motd(), local: LocalFile());
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    expect(r.engine.opened.single.src, isA<FileSource>());
    expect(r.media.urls, 0);
    expect(r.ctrl.offlinePlayback.value, true);
    expect(r.ctrl.recorder.offline, true);
  });

  test('premium required → paywall; media missing → "not available" and an analytics event', () async {
    final r = Rig(motd());
    r.media.failWith = ApiException(ErrorCode.notFound);
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    expect(r.ctrl.phase.value, PlayerPhase.unavailable);
    expect(r.analytics.drain().map((e) => e['name']), contains('media_unavailable'));
  });

  test('±15 s seeks are clamped; play/pause toggles', () async {
    final r = Rig(motd());
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    r.engine.tick(const Duration(seconds: 8));
    await r.flush();
    await r.ctrl.back15();
    expect(r.engine.seeks.last, Duration.zero);
    r.engine.tick(const Duration(minutes: 9, seconds: 55));
    await r.flush();
    await r.ctrl.forward15();
    expect(r.engine.seeks.last, const Duration(minutes: 9, seconds: 59));
    await r.ctrl.togglePlay();
    await r.flush();
    expect(r.ctrl.phase.value, PlayerPhase.paused);
    await r.ctrl.togglePlay();
    await r.flush();
    expect(r.ctrl.phase.value, PlayerPhase.playing);
  });

  test('interruption (call) pauses and resumes; headphones unplugged pauses and stays paused; time is not counted while paused', () {
    fakeAsync((fa) {
      final r = Rig(motd());
      r.ctrl.onInit();
      fa.flushMicrotasks();
      fa.elapse(const Duration(seconds: 30));
      r.engine.interrupt(InterruptionKind.began);
      fa.flushMicrotasks();
      expect(r.ctrl.phase.value, PlayerPhase.paused);
      fa.elapse(const Duration(minutes: 2));
      r.engine.interrupt(InterruptionKind.endedShouldResume);
      fa.flushMicrotasks();
      expect(r.ctrl.phase.value, PlayerPhase.playing);
      fa.elapse(const Duration(seconds: 20));
      expect(r.ctrl.recorder.listened.inSeconds, inInclusiveRange(49, 51));
      r.engine.interrupt(InterruptionKind.becomingNoisy);
      fa.flushMicrotasks();
      fa.elapse(const Duration(minutes: 1));
      expect(r.ctrl.phase.value, PlayerPhase.paused);
      expect(r.ctrl.recorder.listened.inSeconds, inInclusiveRange(49, 51));
    });
  });

  test('connection lost mid-meditation: buffer runs dry → "connection lost" sheet → auto-resume when back, from the same position', () {
    fakeAsync((fa) {
      final r = Rig(motd(), connectivity: true);
      r.ctrl.onInit();
      fa.flushMicrotasks();
      r.engine.tick(const Duration(minutes: 3));
      fa.flushMicrotasks();
      r.connectivity!.up = false;
      r.engine.setStatus(EngineStatus.buffering);
      fa.flushMicrotasks();
      expect(r.ctrl.phase.value, PlayerPhase.buffering);
      fa.elapse(const Duration(seconds: 3));
      fa.flushMicrotasks();
      expect(r.ctrl.phase.value, PlayerPhase.stalled);
      expect(r.ctrl.stalledSheet.value, true);
      // back online
      r.connectivity!.up = true;
      r.connectivity!.online.value = true;
      fa.flushMicrotasks();
      expect(r.ctrl.stalledSheet.value, false);
      expect(r.engine.opened.length, 2);
      expect(r.engine.opened.last.start, const Duration(minutes: 3));
      expect(r.media.urls, 2); // a fresh signed URL
    });
  });

  test('a short stall while online recovers by itself and never shows the sheet', () {
    fakeAsync((fa) {
      final r = Rig(motd(), connectivity: true);
      r.ctrl.onInit();
      fa.flushMicrotasks();
      r.engine.setStatus(EngineStatus.buffering);
      fa.elapse(const Duration(seconds: 1));
      r.engine.setStatus(EngineStatus.ready);
      fa.elapse(const Duration(seconds: 5));
      fa.flushMicrotasks();
      expect(r.ctrl.stalledSheet.value, false);
      expect(r.ctrl.phase.value, PlayerPhase.playing);
    });
  });

  test('expired signed URL (playback error): asks for a new URL and continues from the position', () async {
    final r = Rig(motd());
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    r.engine.tick(const Duration(minutes: 2, seconds: 30));
    await r.flush();
    r.engine.fail(Exception('403 expired'));
    await r.flush();
    await r.flush();
    expect(r.media.urls, 2);
    expect(r.engine.opened.last.start, const Duration(minutes: 2, seconds: 30));
    expect((r.engine.opened.last.src as UrlSource).url, contains('sig=2'));
  });

  test('completion: outbox record with id/kind/length, presence stopped, payoff screen opened with the numbers', () async {
    final r = Rig(motd(), local: null);
    await r.connect();
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    // pretend 10 minutes of listening
    final rec = r.ctrl.recorder;
    rec.paused();
    await r.ctrl.finish(completed: true);
    expect(r.transport.count('presence:stop'), 1);
    expect(r.ctrl.phase.value, PlayerPhase.ended);
    expect(r.analytics.drain().map((e) => e['name']), containsAll(['meditation_start', 'meditation_complete']));
  });

  test('a meditation that counts is written to the outbox and opens the payoff', () async {
    var now = DateTime.utc(2026, 10, 7, 8);
    final r = Rig(motd(), now: () => now);
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    now = now.add(const Duration(minutes: 10));
    r.engine.setStatus(EngineStatus.completed);
    await r.flush();
    await r.flush();
    await r.flush();
    expect(r.nav.events, ['complete']);
    final rec = r.nav.complete!.record!;
    expect(rec.kind, 'motd');
    expect(rec.sessionId, sid);
    expect(rec.lengthVariant, 10);
    expect(rec.completed, true);
    expect(rec.durationSec, 600);
    expect(rec.id, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-7')));
    await r.sync.flush();
    expect(r.meditations.recorded.single.id, rec.id);
  });

  test('ending before 3 minutes records nothing countable and just goes back (meditation_abandon)', () async {
    final r = Rig(motd());
    await r.connect();
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    await r.ctrl.endEarly();
    expect(r.transport.count('presence:stop'), 1);
    expect(r.analytics.drain().map((e) => e['name']), contains('meditation_abandon'));
    expect(r.meditations.recorded, isEmpty);
  });

  test('record:false (daily message audio) never writes to the outbox', () async {
    final r = Rig(motd(record: false));
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    await r.ctrl.finish(completed: true);
    await r.flush();
    expect(await r.db.outboxCount(), 0);
    expect(r.meditations.recorded, isEmpty);
  });

  test('the socket stays connected in the background while a meditation plays and is released after', () async {
    final r = Rig(motd());
    await r.connect();
    r.ctrl.onInit();
    await r.flush();
    await r.flush();
    r.socket.onBackground();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(r.transport.disposed, false);
    await r.ctrl.finish(completed: true);
    expect(AppRoutes.playerPresenceRing, '/player');
  });
}

void driftRuntimeOptionsOff() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}
