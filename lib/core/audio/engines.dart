import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import 'audio_engine.dart';

typedef VideoEngineFactory = AudioEngine Function();
typedef YoutubeEngineFactory = AudioEngine Function();

/// Premium video meditations (spec #43) on `video_player`. Same engine contract as audio, so presence, counting,
/// stall handling and recording are shared.
class VideoEngine implements AudioEngine {
  VideoPlayerController? controller;
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _status = StreamController<EngineStatus>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  bool _wasPlaying = false, _wasBuffering = false, _completed = false;
  Duration _last = Duration.zero;

  void _onValue() {
    final v = controller!.value;
    if (v.hasError) _errors.add(v.errorDescription ?? 'video error');
    if (v.position != _last) {
      _last = v.position;
      _pos.add(v.position);
    }
    if (v.isPlaying != _wasPlaying) {
      _wasPlaying = v.isPlaying;
      _playing.add(v.isPlaying);
    }
    if (v.isBuffering != _wasBuffering) {
      _wasBuffering = v.isBuffering;
      _status.add(v.isBuffering ? EngineStatus.buffering : EngineStatus.ready);
    }
    if (v.isCompleted && !_completed) {
      _completed = true;
      _status.add(EngineStatus.completed);
    }
  }

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
  bool get isPlaying => controller?.value.isPlaying ?? false;
  @override
  Duration get currentPosition => controller?.value.position ?? Duration.zero;
  @override
  Duration? get currentDuration => controller?.value.duration;

  @override
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero}) async {
    await controller?.dispose();
    _completed = false;
    controller = switch (src) {
      UrlSource() => VideoPlayerController.networkUrl(Uri.parse(src.url)),
      FileSource() => VideoPlayerController.file(File(src.path)),
      YoutubeSource() => throw UnsupportedError('use YoutubeEngine'),
    };
    await controller!.initialize();
    controller!.addListener(_onValue);
    if (start > Duration.zero) await controller!.seekTo(start);
    final d = controller!.value.duration;
    _dur.add(d);
    _status.add(EngineStatus.ready);
    return d;
  }

  @override
  Future<void> play() async => controller?.play();
  @override
  Future<void> pause() async => controller?.pause();
  @override
  Future<void> seek(Duration to) async => controller?.seekTo(to);
  @override
  Future<void> stop() async => controller?.pause();

  @override
  Future<void> dispose() async {
    controller?.removeListener(_onValue);
    await controller?.dispose();
    for (final c in [_pos, _dur, _status, _playing, _errors]) {
      await c.close();
    }
  }
}

/// Free YouTube items (spec #44): played in the embedded iframe player; the app never mentions YouTube in its copy.
class YoutubeEngine implements AudioEngine {
  yt.YoutubePlayerController? controller;
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _status = StreamController<EngineStatus>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  StreamSubscription<yt.YoutubeVideoState>? _s1;
  StreamSubscription<yt.YoutubePlayerValue>? _s2;
  Duration _p = Duration.zero;
  bool _isPlaying = false;

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
  Duration get currentPosition => _p;
  @override
  Duration? get currentDuration => controller?.metadata.duration;

  @override
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero}) async {
    final id = (src as YoutubeSource).videoId;
    controller = yt.YoutubePlayerController.fromVideoId(videoId: id, startSeconds: start.inSeconds.toDouble(), params: const yt.YoutubePlayerParams(showControls: false, showFullscreenButton: false, strictRelatedVideos: true, enableCaption: true));
    _s1 = controller!.videoStateStream.listen((s) {
      _p = s.position;
      _pos.add(s.position);
    });
    _s2 = controller!.stream.listen((v) {
      final d = v.metaData.duration;
      if (d > Duration.zero) _dur.add(d);
      final playing = v.playerState == yt.PlayerState.playing;
      if (playing != _isPlaying) {
        _isPlaying = playing;
        _playing.add(playing);
      }
      switch (v.playerState) {
        case yt.PlayerState.ended:
          _status.add(EngineStatus.completed);
        case yt.PlayerState.buffering:
          _status.add(EngineStatus.buffering);
        case yt.PlayerState.playing || yt.PlayerState.paused || yt.PlayerState.cued:
          _status.add(EngineStatus.ready);
        default:
          break;
      }
      if (v.error != yt.YoutubeError.none) _errors.add(v.error); // removed / region-blocked → "Not available right now"
    });
    return null;
  }

  @override
  Future<void> play() async => controller?.playVideo();
  @override
  Future<void> pause() async => controller?.pauseVideo();
  @override
  Future<void> seek(Duration to) async => controller?.seekTo(seconds: to.inSeconds.toDouble(), allowSeekAhead: true);
  @override
  Future<void> stop() async => controller?.pauseVideo();

  @override
  Future<void> dispose() async {
    await _s1?.cancel();
    await _s2?.cancel();
    await controller?.close();
    for (final c in [_pos, _dur, _status, _playing, _errors]) {
      await c.close();
    }
  }
}
