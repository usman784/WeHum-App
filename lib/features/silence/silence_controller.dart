import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/routes/app_routes.dart';
import '../../core/audio/session_recorder.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/activity.dart';
import '../../core/data/models/stitch.dart';
import '../../core/realtime/live_service.dart';
import '../../core/realtime/presence_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/sync_service.dart';
import '../player/controllers/player_controller.dart';
import '../player/player_args.dart';
import '../today/controllers/today_controller.dart';

/// Plays the bell. A port so the timer can be tested without audio.
abstract class BellPlayer {
  /// [url]: a bell from the CMS (signed URL); null = the bundled bell.
  Future<void> ring({String? url});
  Future<void> dispose();
}

class AssetBellPlayer implements BellPlayer {
  final _p = AudioPlayer();
  @override
  Future<void> ring({String? url}) async {
    try {
      if (url != null) {
        await _p.setUrl(url);
      } else {
        await _p.setAsset('assets/audio/bell.wav');
      }
      await _p.seek(Duration.zero);
      // a playback session, as in the guided player: the bell is heard with the iPhone's ring switch on silent
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
      await session.setActive(true);
      await _p.play();
    } catch (_) {
      // a bell that cannot load falls back to the bundled one; a missing bell never stops the meditation
      if (url != null) await ring();
    }
  }

  @override
  Future<void> dispose() => _p.dispose();
}

/// Screen dimming + keep-awake while meditating in silence.
abstract class ScreenPort {
  Future<void> dim();
  Future<void> restore();
  Future<void> keepAwake(bool on);
}

class DeviceScreen implements ScreenPort {
  @override
  Future<void> dim() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(0.03);
    } catch (_) {}
  }

  @override
  Future<void> restore() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  @override
  Future<void> keepAwake(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {}
  }
}

enum SilencePhase { setup, running, paused, done }

/// 50 Silence Room setup + 51 meditating. The remaining time comes from timestamps (start − pauses), never from
/// counting ticks, so 30 minutes in the background is still 30 minutes (spec §10, §14 P10).
class SilenceController extends GetxController with WidgetsBindingObserver {
  SilenceController({BellPlayer? bell, ScreenPort? screen, SyncService? sync, PresenceService? presence, NotificationService? notifications, AnalyticsService? analytics, SilenceNav? nav, this.dimAfter = const Duration(seconds: 5)})
      : _bell = bell ?? AssetBellPlayer(), _screen = screen ?? DeviceScreen(), _sync = sync ?? Get.find(), _presence = presence ?? Get.find(), _notifications = notifications ?? Get.find(), _analytics = analytics ?? Get.find(), _nav = nav ?? GetSilenceNav();
  final BellPlayer _bell;
  final ScreenPort _screen;
  final SyncService _sync;
  final PresenceService _presence;
  final NotificationService _notifications;
  final AnalyticsService _analytics;
  final SilenceNav _nav;
  final Duration dimAfter;

  /// Used until the server answers (`GET /v1/silence`); 0 = open-ended.
  static const presets = [5, 10, 15, 20, 30, 45, 60, 0];

  /// Setup numbers and options from the server; null until loaded.
  final info = Rxn<SilenceInfo>();
  final openingId = RxnString();
  final intervalId = RxnString();
  final closingId = RxnString();
  /// Soft marker every N minutes while sitting; 0 = none.
  final intervalMin = 5.obs;
  /// Off until the person asks for it: a soft marker every [intervalMin] minutes.
  final chimeOn = false.obs;
  String? _openingUrl, _intervalUrl, _closingUrl;
  int _lastIntervalMark = 0;

  List<int> get durations => info.value?.durations ?? presets;
  int get extendMin => info.value?.extendMin ?? 5;
  int get inhaleSec => info.value?.inhaleSec ?? 4;
  int get exhaleSec => info.value?.exhaleSec ?? 6;

  final minutes = 15.obs;
  final bellStart = true.obs;
  final bellEnd = true.obs;
  final phase = SilencePhase.setup.obs;
  final remaining = Duration.zero.obs;
  final elapsed = Duration.zero.obs;
  final dimmed = false.obs;
  /// Seconds left of the quiet gap between the opening bell and the start of the timer; 0 = the timer is running.
  final settleLeft = 0.obs;

  /// The opening bell rings, then 3 seconds of quiet, then the meditation starts (no gap when the bell is off).
  static const openingGap = Duration(seconds: 3);

  late final LiveService live = Get.find();
  SessionRecorder? _rec;
  DateTime? _startedAt, _pausedAt;
  Duration _paused = Duration.zero;
  Timer? _tick, _dimTimer;
  bool _finishing = false;

  bool get openEnded => minutes.value == 0;
  Duration get planned => Duration(minutes: minutes.value);

  /// People sitting in silence right now: the socket first, then the setup snapshot. Null = not known yet.
  int? get sittingNow => live.paused ? null : (live.silence.value?.people ?? info.value?.sittingNow);

  /// Quiet room: the "low traffic" variant (a few people, so we say "N sat here today" instead of a crowd).
  bool get quietRoom => live.silence.value?.quiet ?? info.value?.quiet ?? true;

  /// Countries meditating in silence right now (live socket first, then the setup snapshot), most people first.
  /// Empty while the live numbers are paused: old numbers are never shown as live.
  List<({String country, int n})> get liveCountries => live.paused ? const [] : (live.silence.value?.top ?? info.value?.top ?? const []);

  /// Where people meditated in silence today (the quiet room's map and list).
  List<({String country, int n})> get todayCountries => live.paused ? const [] : (live.silence.value?.todayTop ?? info.value?.todayTop ?? const []);

  /// True when the rows are "right now"; false when the room is empty and we show where people meditated today.
  bool get countriesLive => liveCountries.isNotEmpty;

  /// The rows for "Where people are meditating": live first, else today's.
  List<({String country, int n})> get whereRows => countriesLive ? liveCountries : todayCountries;

  /// Glowing countries on the dot map.
  Map<String, int> get mapHot => {for (final t in whereRows) t.country: t.n};

  /// Belts right now (socket first).
  Belts get belts {
    final s = live.silence.value;
    return s == null ? (info.value?.belts ?? const Belts()) : Belts(americas: s.americas, emea: s.emea, apac: s.apac);
  }

  /// Honest count only (spec: never fake): quiet room → "N sat here today".
  String get bigNum {
    if (info.value == null && live.silence.value == null) return live.agg.value == null ? '–' : groupNumber(live.agg.value!.headline);
    return groupNumber(quietRoom ? (info.value?.todayTotal ?? 0) : (sittingNow ?? 0));
  }

  String get bigLabel {
    if (live.paused) return 'Live counts paused';
    if (info.value == null && live.silence.value == null) return (live.agg.value?.quiet ?? true) ? 'meditated here today' : 'meditating now';
    return quietRoom ? 'meditated in this room today' : 'meditating in silence now';
  }

  /// "7:30" style clock of the next interval marker, or null when there is none (open-ended sits count up).
  DateTime? get nextChimeAt {
    final s = _startedAt;
    if (s == null || !chimeOn.value || intervalMin.value <= 0) return null;
    final step = Duration(minutes: intervalMin.value);
    final mark = (elapsed.value.inSeconds ~/ step.inSeconds) + 1;
    final at = s.add(_paused).add(step * mark);
    if (!openEnded && at.isAfter(s.add(_paused).add(planned))) return null;
    return at;
  }

  @override
  void onReady() {
    super.onReady();
    live.acquireToday();
    live.acquireSilence();
    WidgetsBinding.instance.addObserver(this);
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    try {
      final i = await Get.find<TodayRepository>().silence();
      info.value = i;
      if (!i.durations.contains(minutes.value) && i.durations.isNotEmpty) minutes.value = i.durations.contains(15) ? 15 : i.durations.first;
      openingId.value ??= i.opening.firstOrNull?.id;
      intervalId.value ??= i.interval.firstOrNull?.id;
      closingId.value ??= i.closing.firstOrNull?.id;
      unawaited(_resolveBells()); // ready before "Begin", so the opening bell rings on the tap
    } catch (_) {/* the page keeps working with the built-in options */}
  }

  /// Resolves the chosen bells to signed URLs once, before the sit starts (a failure falls back to the bundled bell).
  Future<void> _resolveBells() async {
    final media = Get.isRegistered<MediaRepository>() ? Get.find<MediaRepository>() : null;
    if (media == null) return;
    Future<String?> url(String? id) async {
      if (id == null) return null;
      try {
        final u = await media.playUrl(PlayBlock(id));
        return u.url ?? u.hlsUrl;
      } catch (_) {
        return null;
      }
    }
    final key = _bellKey;
    final r = await Future.wait([url(openingId.value), url(intervalId.value), url(closingId.value)]);
    _openingUrl = r[0];
    _intervalUrl = r[1];
    _closingUrl = r[2];
    _bellsFor = key;
  }

  /// Which bell choice the resolved URLs belong to (a new choice on the setup screen resolves again).
  String get _bellKey => '${openingId.value}|${intervalId.value}|${closingId.value}';
  String? _bellsFor;

  /// "+5 min": the sit gets longer (a timed sit only; the end bell moves with it).
  void extend() {
    if (openEnded || phase.value == SilencePhase.done) return;
    minutes.value += extendMin;
    refreshTime();
    if (phase.value == SilencePhase.running && bellEnd.value) _notifications.scheduleEndBell(clock.now().toUtc().add(remaining.value));
  }

  /// Back from the background: the time is recomputed from timestamps, so it is right at once.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshTime();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    _dimTimer?.cancel();
    live.releaseToday();
    live.releaseSilence();
    _screen.restore();
    _screen.keepAwake(false);
    _bell.dispose();
    super.onClose();
  }

  // ───────────── session
  Future<void> enter() async {
    _rec = SessionRecorder(kind: 'silence', plannedSec: openEnded ? null : planned.inSeconds);
    _paused = Duration.zero;
    _pausedAt = null;
    phase.value = SilencePhase.running;
    _analytics.track('silence_start', {'length': minutes.value, 'bells': bellStart.value || bellEnd.value});
    // the bells were resolved on the setup screen; only a missing URL waits here, and never long
    if (_bellsFor != _bellKey) await _resolveBells().timeout(const Duration(seconds: 2), onTimeout: () {});
    // the run screen opens on the tap, and the bell rings as "Begins in 3" starts: nothing slow comes before them
    _lastIntervalMark = 0;
    if (bellStart.value) unawaited(_bell.ring(url: _openingUrl));
    // the timer (and the recorded minutes) start after the gap, so the bell is not part of the meditation
    _startedAt = clock.now().add(bellStart.value ? openingGap : Duration.zero);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => refreshTime());
    refreshTime();
    _armDim();
    _nav.toRun();
    await _screen.keepAwake(true);
    // the end bell also rings as a local notification if the app is suspended
    if (!openEnded && bellEnd.value) await _notifications.scheduleEndBell(_startedAt!.toUtc().add(planned));
    await _presence.start(meditationId: _rec!.id, kind: 'silence', mode: 'silence', lengthMin: openEnded ? null : minutes.value);
  }

  /// Recomputes the time from timestamps. Called every second and when the app returns to the foreground.
  void refreshTime() {
    final s = _startedAt;
    if (s == null || phase.value == SilencePhase.done) return;
    final now = _pausedAt ?? clock.now();
    if (now.isBefore(s)) {
      settleLeft.value = (s.difference(now).inMilliseconds / 1000).ceil();
      elapsed.value = Duration.zero;
      if (!openEnded) remaining.value = planned;
      return;
    }
    settleLeft.value = 0;
    if (_rec?.started == false) _rec!.playing(s);
    final e = now.difference(s) - _paused;
    elapsed.value = e.isNegative ? Duration.zero : e;
    if (chimeOn.value && intervalMin.value > 0 && phase.value == SilencePhase.running) {
      final mark = elapsed.value.inSeconds ~/ (intervalMin.value * 60);
      if (mark > _lastIntervalMark) {
        _lastIntervalMark = mark;
        final isEnd = !openEnded && elapsed.value >= planned;
        if (!isEnd) unawaited(_bell.ring(url: _intervalUrl));
      }
    }
    if (!openEnded) {
      final left = planned - elapsed.value;
      remaining.value = left.isNegative ? Duration.zero : left;
      if (left <= Duration.zero && phase.value == SilencePhase.running && !_finishing) unawaited(_complete());
    }
  }

  void pause() {
    if (phase.value != SilencePhase.running) return;
    refreshTime();
    if (settleLeft.value > 0) return; // the 3-second gap after the bell is not pausable
    _pausedAt = clock.now();
    phase.value = SilencePhase.paused;
    _rec?.paused();
    _notifications.cancelEndBell();
    wake();
  }

  void resume() {
    if (phase.value != SilencePhase.paused) return;
    _paused += clock.now().difference(_pausedAt!);
    _pausedAt = null;
    phase.value = SilencePhase.running;
    _rec?.playing();
    if (!openEnded && bellEnd.value) _notifications.scheduleEndBell(clock.now().toUtc().add(remaining.value));
    _armDim();
  }

  Future<void> _complete() async {
    if (_finishing) return;
    if (bellEnd.value) unawaited(_bell.ring(url: _closingUrl));
    await finish(completed: true);
  }

  /// "End": a meditation that reached 3 minutes counts and shows the payoff; shorter ones just close.
  Future<void> finish({required bool completed}) async {
    if (phase.value == SilencePhase.done || _finishing) return;
    _finishing = true;
    refreshTime();
    phase.value = SilencePhase.done;
    _tick?.cancel();
    _dimTimer?.cancel();
    await _screen.restore();
    await _screen.keepAwake(false);
    await _notifications.cancelEndBell();
    final counts = _rec?.counts ?? false;
    final rec = _rec?.build(completed: completed);
    _analytics.track('silence_end', {'length': minutes.value, 'bells': bellStart.value || bellEnd.value});
    unawaited(_presence.stop());
    if (rec != null) unawaited(_sync.record(rec, waitForServer: false));
    if (counts && rec != null) {
      _nav.toComplete(CompleteArgs(player: const PlayerArgs(kind: 'silence', mode: 'silence', title: 'Silence Room'), record: rec, counted: true));
    } else {
      _nav.back();
    }
  }

  // ───────────── dimming
  void _armDim() {
    _dimTimer?.cancel();
    _dimTimer = Timer(dimAfter, () {
      if (phase.value == SilencePhase.running) {
        dimmed.value = true;
        _screen.dim();
      }
    });
  }

  /// Tap to wake: brightness back, dim again after a few seconds.
  void wake() {
    dimmed.value = false;
    _screen.restore();
    if (phase.value == SilencePhase.running) _armDim();
  }
}

abstract class SilenceNav {
  void toRun();
  void toComplete(CompleteArgs a);
  void back();
}

class GetSilenceNav implements SilenceNav {
  @override
  void toRun() => Get.toNamed(AppRoutes.silenceRoomMeditating);
  @override
  void toComplete(CompleteArgs a) => Get.offNamed(AppRoutes.meditationCompletePayoff, arguments: a);
  @override
  void back() => Get.until((r) => r.settings.name != AppRoutes.silenceRoomMeditating && r.settings.name != AppRoutes.silenceRoomSetup);
}
