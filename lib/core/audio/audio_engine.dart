import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'recipe_plan.dart';

sealed class EngineSource {
  const EngineSource();
}

class UrlSource extends EngineSource {
  const UrlSource(this.url);
  final String url;
}

/// A "Build your own" meditation: the timeline plus the signed URL of every block (played by RecipeEngine).
class RecipeSource extends EngineSource {
  const RecipeSource(this.plan, this.urls, {this.bellUrl});
  final RecipePlan plan;
  final Map<String, String> urls; // block id → signed URL
  final String? bellUrl;
}

/// A YouTube video id (free items from Raphael's online library).
class YoutubeSource extends EngineSource {
  const YoutubeSource(this.videoId);
  final String videoId;
}

class FileSource extends EngineSource {
  const FileSource(this.path);
  final String path;
}

enum EngineStatus { idle, loading, buffering, ready, completed }

/// Why audio paused on its own (spec §10): another app/phone call, headphones unplugged.
enum InterruptionKind { began, endedShouldResume, endedNoResume, becomingNoisy }

/// The audio output as the app sees it. The real one wraps just_audio; tests drive a fake.
abstract class AudioEngine {
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<EngineStatus> get status;
  Stream<bool> get playing;
  Stream<Object> get errors;
  Stream<InterruptionKind> get interruptions;
  bool get isPlaying;
  Duration get currentPosition;
  Duration? get currentDuration;

  /// Loads the source (starting at [start]) and returns its duration.
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero});
  /// Requests playback and returns at once (never waits for the track to finish).
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration to);
  Future<void> stop();
  Future<void> dispose();
}

typedef AudioEngineFactory = AudioEngine Function();

/// just_audio + audio_session: speech category, pause on interruption, resume only if it was playing, unplug → pause.
class JustAudioEngine implements AudioEngine {
  JustAudioEngine() {
    _init();
  }
  final _player = AudioPlayer();
  final _interrupt = StreamController<InterruptionKind>.broadcast();
  StreamSubscription<dynamic>? _s1, _s2;
  bool _resumeAfter = false;

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
    _s1 = session.interruptionEventStream.listen((e) {
      if (e.begin) {
        _resumeAfter = _player.playing;
        _interrupt.add(InterruptionKind.began);
        if (_player.playing) _player.pause();
      } else {
        final resume = _resumeAfter && e.type != AudioInterruptionType.unknown;
        _interrupt.add(resume ? InterruptionKind.endedShouldResume : InterruptionKind.endedNoResume);
        if (resume) _player.play();
        _resumeAfter = false;
      }
    });
    _s2 = session.becomingNoisyEventStream.listen((_) {
      _interrupt.add(InterruptionKind.becomingNoisy);
      _player.pause();
    });
  }

  @override
  Stream<Duration> get position => _player.positionStream;
  @override
  Stream<Duration?> get duration => _player.durationStream;
  @override
  Stream<bool> get playing => _player.playingStream;
  @override
  Stream<Object> get errors => _player.playbackEventStream.transform(StreamTransformer.fromHandlers(handleData: (_, __) {}, handleError: (e, st, sink) => sink.add(e)));
  @override
  Stream<InterruptionKind> get interruptions => _interrupt.stream;
  @override
  Stream<EngineStatus> get status => _player.processingStateStream.map((s) => switch (s) {
        ProcessingState.idle => EngineStatus.idle,
        ProcessingState.loading => EngineStatus.loading,
        ProcessingState.buffering => EngineStatus.buffering,
        ProcessingState.ready => EngineStatus.ready,
        ProcessingState.completed => EngineStatus.completed,
      });
  @override
  bool get isPlaying => _player.playing;
  @override
  Duration get currentPosition => _player.position;
  @override
  Duration? get currentDuration => _player.duration;

  @override
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero}) async {
    final uri = switch (src) { UrlSource() => Uri.parse(src.url), FileSource() => Uri.file(src.path), YoutubeSource() => throw UnsupportedError('YouTube is played by YoutubeEngine'), RecipeSource() => throw UnsupportedError('recipes are played by RecipeEngine') };
    return _player.setAudioSource(AudioSource.uri(uri), initialPosition: start);
  }

  @override
  Future<void> play() async {
    await (await AudioSession.instance).setActive(true);
    // just_audio's play() completes only when playback ends or pauses. Waiting for it would hold up everything
    // that follows "start playing" (presence, the outbox…) for the whole meditation: request it and return.
    unawaited(_player.play());
  }

  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> seek(Duration to) => _player.seek(to);
  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _s1?.cancel();
    await _s2?.cancel();
    await _interrupt.close();
    await _player.dispose();
  }
}
