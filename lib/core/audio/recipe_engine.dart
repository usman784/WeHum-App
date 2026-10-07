import 'dart:async';
import 'package:clock/clock.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_engine.dart';
import 'recipe_plan.dart';

/// A short piece of audio (a block or the bell). A port so the timeline can be tested.
abstract class ClipPlayer {
  Future<void> play(String url, {double volume = 1, bool loop = false});
  Future<void> stop();
  Future<void> pause();
  Future<void> resume();
  Future<void> dispose();
}

typedef RecipeEngineFactory = AudioEngine Function();

/// The bundled bell (`asset:` URLs play from the app bundle).
const bundledBell = 'asset:assets/audio/bell.wav';

class JustClipPlayer implements ClipPlayer {
  final _p = AudioPlayer();
  @override
  Future<void> play(String url, {double volume = 1, bool loop = false}) async {
    try {
      await _p.setVolume(volume);
      await _p.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      if (url.startsWith('asset:')) {
        await _p.setAsset(url.substring(6));
      } else {
        await _p.setUrl(url);
      }
      unawaited(_p.play());
    } catch (_) {/* one missing clip never stops the meditation: the timeline carries on in silence */}
  }

  @override
  Future<void> stop() => _p.stop();
  @override
  Future<void> pause() => _p.pause();
  @override
  Future<void> resume() async => unawaited(_p.play());
  @override
  Future<void> dispose() => _p.dispose();
}

/// Plays a [RecipePlan]: the timeline is a clock (position = time spent playing), voice blocks start at their offsets,
/// the background sound loops under everything, bells fire at their seconds. Total length is exact (±1 s) because
/// silence is time, not an audio file (spec §13).
class RecipeEngine implements AudioEngine {
  RecipeEngine({required ClipPlayer Function() clipFactory}) : _clip = clipFactory;
  final ClipPlayer Function() _clip;

  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _status = StreamController<EngineStatus>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();

  RecipeSource? _src;
  Timer? _ticker;
  DateTime? _playingSince;
  Duration _before = Duration.zero;
  bool _isPlaying = false, _done = false;
  final _fired = <String>{};
  ClipPlayer? _voice, _sound, _bell;

  @override
  Stream<Duration> get position => _pos.stream;
  @override
  Stream<Duration?> get duration => _dur.stream;
  @override
  Stream<EngineStatus> get status => _status.stream;
  @override
  Stream<bool> get playing => _playing.stream;
  @override
  Stream<Object> get errors => _errors.stream;
  @override
  Stream<InterruptionKind> get interruptions => const Stream.empty();
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get currentPosition => _before + (_playingSince == null ? Duration.zero : clock.now().difference(_playingSince!));
  @override
  Duration? get currentDuration => _src == null ? null : Duration(seconds: _src!.plan.totalSec);

  @override
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero}) async {
    _src = src as RecipeSource;
    _before = start;
    _done = false;
    _fired.clear();
    final d = Duration(seconds: src.plan.totalSec);
    _dur.add(d);
    _status.add(EngineStatus.ready);
    return d;
  }

  @override
  Future<void> play() async {
    final s = _src;
    if (s == null || _isPlaying || _done) return;
    _isPlaying = true;
    _playingSince = clock.now();
    _playing.add(true);
    _voice ??= _clip();
    _bell ??= _clip();
    if (s.plan.soundId != null && s.urls[s.plan.soundId] != null) {
      if (_sound == null) {
        _sound = _clip();
        await _sound!.play(s.urls[s.plan.soundId]!, volume: s.plan.soundVolume, loop: true);
      } else {
        await _sound!.resume();
      }
    }
    await _voice!.resume();
    _ticker ??= Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _tick();
  }

  void _tick() {
    final s = _src;
    if (s == null || !_isPlaying) return;
    final p = currentPosition;
    _pos.add(p);
    final sec = p.inMilliseconds / 1000;
    for (final c in s.plan.clips) {
      final key = 'c${c.startSec}';
      if (sec >= c.startSec && sec < c.endSec && _fired.add(key) && s.urls[c.blockId] != null) {
        _voice!.play(s.urls[c.blockId]!);
      }
    }
    for (final b in s.plan.bellsAt) {
      if (sec >= b && sec < b + 2 && _fired.add('b$b') && s.bellUrl != null) _bell!.play(s.bellUrl!);
    }
    if (sec >= s.plan.totalSec) {
      _done = true;
      _isPlaying = false;
      _ticker?.cancel();
      _ticker = null;
      _playing.add(false);
      _pos.add(Duration(seconds: s.plan.totalSec));
      _status.add(EngineStatus.completed);
    }
  }

  @override
  Future<void> pause() async {
    if (!_isPlaying) return;
    _before = currentPosition;
    _playingSince = null;
    _isPlaying = false;
    _playing.add(false);
    await _voice?.pause();
    await _sound?.pause();
  }

  /// Custom meditations do not seek (clips are placed by time); the player hides the skip buttons.
  @override
  Future<void> seek(Duration to) async {}

  @override
  Future<void> stop() async {
    _ticker?.cancel();
    _ticker = null;
    _isPlaying = false;
    await _voice?.stop();
    await _sound?.stop();
    await _bell?.stop();
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _voice?.dispose();
    await _sound?.dispose();
    await _bell?.dispose();
    for (final c in [_pos, _dur, _status, _playing, _errors]) {
      await c.close();
    }
  }
}
