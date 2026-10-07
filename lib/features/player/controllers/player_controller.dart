import 'dart:async';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/audio/audio_engine.dart';
import '../../../core/audio/local_media.dart';
import '../../../core/audio/media_session.dart';
import '../../../core/audio/recipe_engine.dart';
import '../../../core/audio/recipe_plan.dart';
import '../../../core/data/models/content.dart';
import '../../../core/audio/session_recorder.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/realtime/presence_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/perf_service.dart';
import '../../../core/services/sync_service.dart';
import '../player_args.dart';

enum PlayerPhase { loading, ready, playing, paused, buffering, stalled, unavailable, error, ended }

/// Navigation the player needs, injectable so the controller is testable without a router.
abstract class PlayerNav {
  void toComplete(CompleteArgs a);
  void toPaywall();
  void back();
}

class GetPlayerNav implements PlayerNav {
  @override
  void toComplete(CompleteArgs a) => Get.offNamed(AppRoutes.meditationCompletePayoff, arguments: a);
  @override
  void toPaywall() => Get.offNamed(AppRoutes.membershipPaywall, arguments: {'source': 'lock'});
  @override
  void back() {
    if (!(Get.isDialogOpen ?? false)) Get.back<void>();
  }
}

/// What the completion screen needs (screen 45).
class CompleteArgs {
  const CompleteArgs({required this.player, this.record, this.counted = false});
  final PlayerArgs player;
  final MeditationRecord? record;
  final bool counted;
}

/// 42 Audio player. One controller per meditation: loads the source (download first, else a signed URL), starts presence
/// over the socket, counts real listening time, survives interruptions / lost connection / expired URLs, records the
/// meditation in the outbox and hands over to the completion screen (spec §6.3, §10, §13).
class PlayerController extends GetxController {
  PlayerController(this.args, {
    required AudioEngine engine, required MediaRepository media, required PresenceService presence, required SyncService sync, required AnalyticsService analytics,
    LocalMedia? local, ConnectivityService? connectivity, PlayerNav? nav, DateTime Function()? now, Catalog? Function()? catalog, MediaSessionPort? mediaSession,
    this.stallGrace = const Duration(seconds: 4),
  })  : _engine = engine, _media = media, _presence = presence, _sync = sync, _analytics = analytics, _local = local ?? const NoLocalMedia(), _connectivity = connectivity, _nav = nav ?? GetPlayerNav(), _now = now, _catalog = catalog, _session = mediaSession ?? const NoMediaSession();

  final PlayerArgs args;
  final AudioEngine _engine;
  final MediaRepository _media;
  final PresenceService _presence;
  final SyncService _sync;
  final AnalyticsService _analytics;
  final LocalMedia _local;
  final ConnectivityService? _connectivity;
  final PlayerNav _nav;
  final DateTime Function()? _now;
  final Catalog? Function()? _catalog;
  final MediaSessionPort _session;
  final Duration stallGrace;

  late final SessionRecorder recorder = SessionRecorder(
      kind: args.kind, sessionId: args.sessionId, recipeId: args.recipe?.id, lengthVariant: args.target is PlayMotd ? (args.target as PlayMotd).lengthMin : args.lengthMin,
      plannedSec: args.durationSec, now: _now);

  final phase = PlayerPhase.loading.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final offlinePlayback = false.obs; // playing a downloaded file
  final stalledSheet = false.obs;
  final errorCode = Rxn<ErrorCode>();

  final _subs = <StreamSubscription<dynamic>>[];
  Timer? _stallTimer;
  PlayUrl? _url;
  bool _finished = false, _wantPlaying = false;
  Worker? _online;

  /// People meditating with you (ring numbers), from `presence:start` ack and `session:live`.
  ({int people, int countries})? get together => _presence.together.value;
  Rx<({int people, int countries})?> get togetherRx => _presence.together;

  double get progress => duration.value.inMilliseconds == 0 ? 0 : (position.value.inMilliseconds / duration.value.inMilliseconds).clamp(0.0, 1.0);
  bool get isPlaying => phase.value == PlayerPhase.playing;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    Perf.start('player_ready'); // tap → audio playing, target < 1 s on 4G
    phase.value = PlayerPhase.loading;
    _analytics.track('meditation_start', {'kind': args.kind, 'session_id': args.sessionId ?? '', 'length': args.lengthMin ?? 0, 'offline': false});
    try {
      final src = await _resolve();
      final d = await _engine.open(src, start: args.startAt);
      duration.value = d ?? Duration(seconds: args.durationSec ?? 0);
      position.value = args.startAt;
      _listen();
      await _session.start(
        id: recorder.id, title: args.title, subtitle: args.subtitle, artUri: args.coverUrl, duration: duration.value, canSeek: !(args.live || args.recipe != null),
        callbacks: MediaCallbacks(play: play, pause: pause, seekBy: skip, stop: endEarly));
      phase.value = PlayerPhase.ready;
      unawaited(play()); // never wait for playback itself: a real engine's play() can last as long as the track
      // presence: you are counted live; the ack carries the "together" numbers (not for non-catalog free items)
      await _presence.start(meditationId: recorder.id, sessionId: args.sessionId, kind: args.kind, lengthMin: args.lengthMin, mode: args.mode);
    } on ApiException catch (e) {
      errorCode.value = e.code;
      if (e.code == ErrorCode.premiumRequired) {
        _nav.toPaywall();
      } else {
        if (e.code == ErrorCode.notFound) _analytics.track('media_unavailable', {'session_id': args.sessionId ?? ''});
        phase.value = e.code == ErrorCode.notFound ? PlayerPhase.unavailable : PlayerPhase.error;
      }
    } catch (e) {
      errorCode.value = ErrorCode.internal;
      _analytics.track('media_unavailable', {'session_id': args.sessionId ?? ''});
      phase.value = PlayerPhase.unavailable;
    }
  }

  /// Downloaded file first (works offline), else the signed URL (prefetched when Session detail opened).
  Future<EngineSource> _resolve() async {
    if (args.recipe != null) return _recipeSource(args.recipe!);
    final t = args.target;
    if (t == null && args.youtubeId != null) return YoutubeSource(args.youtubeId!);
    if (t == null) throw ApiException(ErrorCode.notFound);
    final path = await _local.pathFor(t);
    if (path != null) {
      offlinePlayback.value = true;
      recorder.offline = true;
      return FileSource(path);
    }
    _url = await _media.playUrl(t);
    final u = _url!.url ?? _url!.hlsUrl;
    if (u == null) throw ApiException(ErrorCode.notFound);
    return UrlSource(u);
  }

  /// "Build your own": timeline from the catalog's block lengths, every block's signed URL fetched in parallel.
  Future<EngineSource> _recipeSource(Recipe r) async {
    final cat = _catalog?.call();
    if (cat == null) throw ApiException(ErrorCode.notFound);
    final plan = RecipePlan.build(r, cat);
    final ids = plan.blockIds.toList();
    final urls = await Future.wait([for (final id in ids) _media.playUrl(PlayBlock(id)).then((u) => u.url ?? u.hlsUrl)]);
    return RecipeSource(plan, {for (final (i, id) in ids.indexed) if (urls[i] != null) id: urls[i]!}, bellUrl: bundledBell);
  }

  void _listen() {
    _subs.add(_engine.position.listen((p) {
      position.value = p;
      _session.update(playing: isPlaying, buffering: phase.value == PlayerPhase.buffering, position: p);
    }));
    _subs.add(_engine.duration.listen((d) {
      if (d != null && d > Duration.zero) duration.value = d;
    }));
    _subs.add(_engine.playing.listen(_onPlaying));
    _subs.add(_engine.status.listen(_onStatus));
    _subs.add(_engine.errors.listen(_onError));
    _subs.add(_engine.interruptions.listen((k) {
      // the engine already paused/resumed; keep the listened-time clock honest
      if (k == InterruptionKind.began || k == InterruptionKind.becomingNoisy) recorder.paused();
    }));
    _online = _connectivity == null ? null : ever(_connectivity.online, (on) {
      if (on && stalledSheet.value) _resumeAfterStall();
    });
  }

  void _onPlaying(bool playing) {
    if (_finished) return;
    if (playing) {
      Perf.finish('player_ready');
      recorder.playing();
      if (phase.value != PlayerPhase.buffering) phase.value = PlayerPhase.playing;
    } else {
      recorder.paused();
      if (phase.value == PlayerPhase.playing) phase.value = PlayerPhase.paused;
    }
  }

  void _onStatus(EngineStatus s) {
    if (_finished) return;
    switch (s) {
      case EngineStatus.completed:
        finish(completed: true);
      case EngineStatus.buffering:
        if (_wantPlaying) {
          phase.value = PlayerPhase.buffering;
          recorder.paused(); // stalled time is not listening
          _stallTimer?.cancel();
          _stallTimer = Timer(stallGrace, _checkStall);
        }
      case EngineStatus.ready:
        _stallTimer?.cancel();
        if (phase.value == PlayerPhase.buffering || phase.value == PlayerPhase.stalled) {
          stalledSheet.value = false;
          phase.value = _engine.isPlaying ? PlayerPhase.playing : PlayerPhase.paused;
          if (_engine.isPlaying) recorder.playing();
        }
      default:
        break;
    }
  }

  /// Buffer ran dry: if we are offline say so and resume by ourselves when the connection is back (spec §10).
  Future<void> _checkStall() async {
    if (phase.value != PlayerPhase.buffering || _finished) return;
    final online = _connectivity == null ? true : (_connectivity.online.value && await _connectivity.reachable());
    if (!online) {
      phase.value = PlayerPhase.stalled;
      stalledSheet.value = true;
    }
  }

  Future<void> _resumeAfterStall() async {
    if (_connectivity != null && !await _connectivity.reachable()) return;
    stalledSheet.value = false;
    phase.value = PlayerPhase.buffering;
    await _reopenAt(position.value);
  }

  /// Signed URL expired or the stream failed: ask for a fresh one and continue from where we were (spec §10).
  Future<void> _onError(Object e) async {
    if (_finished || offlinePlayback.value || args.target == null) return; // YouTube and recipes handle their own errors
    _analytics.track('error_shown', {'code': 'playback', 'screen': 'player'});
    await _reopenAt(position.value);
  }

  bool _reopening = false;
  Future<void> _reopenAt(Duration at) async {
    if (_reopening) return;
    _reopening = true;
    try {
      _url = await _media.playUrl(args.target!, fresh: true);
      final u = _url!.url ?? _url!.hlsUrl;
      if (u == null) throw ApiException(ErrorCode.notFound);
      await _engine.open(UrlSource(u), start: at);
      if (_wantPlaying) await _engine.play();
    } catch (_) {
      if (_connectivity != null && !(await _connectivity.reachable())) {
        phase.value = PlayerPhase.stalled;
        stalledSheet.value = true;
      } else {
        phase.value = PlayerPhase.error;
      }
    } finally {
      _reopening = false;
    }
  }

  // ───────────── controls
  Future<void> play() async {
    _wantPlaying = true;
    await _engine.play();
  }

  Future<void> pause() async {
    _wantPlaying = false;
    await _engine.pause();
  }

  Future<void> togglePlay() => isPlaying || phase.value == PlayerPhase.buffering ? pause() : play();

  Future<void> skip(Duration by) async {
    final max = duration.value;
    var to = position.value + by;
    if (to < Duration.zero) to = Duration.zero;
    if (max > Duration.zero && to > max) to = max - const Duration(seconds: 1);
    await _engine.seek(to);
    position.value = to;
  }

  Future<void> back15() => skip(const Duration(seconds: -15));
  Future<void> forward15() => skip(const Duration(seconds: 15));

  /// "End meditation" or system back.
  Future<void> endEarly() async {
    if (recorder.counts) {
      await finish(completed: false);
    } else {
      _analytics.track('meditation_abandon', {'kind': args.kind, 'pct': recorder.pct});
      await _teardown();
      _nav.back();
    }
  }

  /// Completed (or ended after ≥ 3 min): record to the outbox, then show the payoff.
  Future<void> finish({required bool completed}) async {
    if (_finished) return;
    _finished = true;
    phase.value = PlayerPhase.ended;
    final rec = recorder.build(completed: completed);
    final counts = recorder.counts;
    _analytics.track(completed ? 'meditation_complete' : 'meditation_abandon', {'kind': args.kind, 'session_id': args.sessionId ?? '', 'duration_sec': rec?.durationSec ?? 0, 'pct': recorder.pct});
    await _teardown();
    if (rec != null && args.record) {
      unawaited(_sync.record(rec, waitForServer: false)); // outbox first; the payoff never waits on the network
    }
    if (counts && args.record) {
      _nav.toComplete(CompleteArgs(player: args, record: rec, counted: true));
    } else {
      _nav.back();
    }
  }

  Future<void> _teardown() async {
    _stallTimer?.cancel();
    for (final s in _subs) {
      unawaited(s.cancel()); // cancelling a subscription never needs to be waited for
    }
    _subs.clear();
    unawaited(_session.stop());
    unawaited(_presence.stop()); // tells the server at once (sync part); the rest is cleanup
    await _engine.stop();
  }

  @override
  void onClose() {
    _online?.dispose();
    _stallTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _presence.stop();
    _engine.dispose();
    super.onClose();
  }
}
