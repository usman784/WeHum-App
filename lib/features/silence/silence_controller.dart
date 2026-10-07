import 'dart:async';
import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:just_audio/just_audio.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../app/routes/app_routes.dart';
import '../../core/audio/session_recorder.dart';
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
  Future<void> ring();
  Future<void> dispose();
}

class AssetBellPlayer implements BellPlayer {
  final _p = AudioPlayer();
  @override
  Future<void> ring() async {
    try {
      await _p.setAsset('assets/audio/bell.wav');
      await _p.seek(Duration.zero);
      await _p.play();
    } catch (_) {/* a missing bell never stops the meditation */}
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

  static const presets = [5, 10, 15, 20, 30, 45, 60, 0]; // 0 = open-ended

  final minutes = 15.obs;
  final bellStart = true.obs;
  final bellEnd = true.obs;
  final phase = SilencePhase.setup.obs;
  final remaining = Duration.zero.obs;
  final elapsed = Duration.zero.obs;
  final dimmed = false.obs;

  late final LiveService live = Get.find();
  SessionRecorder? _rec;
  DateTime? _startedAt, _pausedAt;
  Duration _paused = Duration.zero;
  Timer? _tick, _dimTimer;
  bool _finishing = false;

  bool get openEnded => minutes.value == 0;
  Duration get planned => Duration(minutes: minutes.value);

  /// Honest count only (spec: never fake): quiet room → "N meditated here today".
  String get bigNum => live.agg.value == null ? '–' : groupNumber(live.agg.value!.headline);
  String get bigLabel => live.paused ? 'Live counts paused' : ((live.agg.value?.quiet ?? true) ? 'meditated here today' : 'meditating now');

  @override
  void onReady() {
    super.onReady();
    live.acquireToday();
    WidgetsBinding.instance.addObserver(this);
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
    _screen.restore();
    _screen.keepAwake(false);
    _bell.dispose();
    super.onClose();
  }

  // ───────────── session
  Future<void> enter() async {
    _rec = SessionRecorder(kind: 'silence', plannedSec: openEnded ? null : planned.inSeconds);
    _startedAt = clock.now();
    _paused = Duration.zero;
    _pausedAt = null;
    phase.value = SilencePhase.running;
    _rec!.playing();
    _analytics.track('silence_start', {'length': minutes.value, 'bells': bellStart.value || bellEnd.value});
    await _screen.keepAwake(true);
    if (bellStart.value) unawaited(_bell.ring());
    // the end bell also rings as a local notification if the app is suspended
    if (!openEnded && bellEnd.value) await _notifications.scheduleEndBell(_startedAt!.toUtc().add(planned));
    await _presence.start(meditationId: _rec!.id, kind: 'silence', mode: 'silence', lengthMin: openEnded ? null : minutes.value);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => refreshTime());
    refreshTime();
    _armDim();
    _nav.toRun();
  }

  /// Recomputes the time from timestamps. Called every second and when the app returns to the foreground.
  void refreshTime() {
    final s = _startedAt;
    if (s == null || phase.value == SilencePhase.done) return;
    final now = _pausedAt ?? clock.now();
    final e = now.difference(s) - _paused;
    elapsed.value = e.isNegative ? Duration.zero : e;
    if (!openEnded) {
      final left = planned - elapsed.value;
      remaining.value = left.isNegative ? Duration.zero : left;
      if (left <= Duration.zero && phase.value == SilencePhase.running && !_finishing) unawaited(_complete());
    }
  }

  void pause() {
    if (phase.value != SilencePhase.running) return;
    refreshTime();
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
    if (bellEnd.value) unawaited(_bell.ring());
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
