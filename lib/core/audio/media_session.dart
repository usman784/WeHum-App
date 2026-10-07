import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart' show AudioSession;

/// What the lock screen / notification shade can ask for (spec §10: play/pause/±15 s).
class MediaCallbacks {
  const MediaCallbacks({required this.play, required this.pause, required this.seekBy, required this.stop});
  final Future<void> Function() play, pause, stop;
  final Future<void> Function(Duration by) seekBy;
}

/// The lock-screen controls as the player sees them. A no-op in tests.
abstract class MediaSessionPort {
  Future<void> start({required String id, required String title, String? subtitle, String? artUri, Duration? duration, bool canSeek = true, required MediaCallbacks callbacks});
  void update({required bool playing, required bool buffering, required Duration position});
  Future<void> stop();
}

class NoMediaSession implements MediaSessionPort {
  const NoMediaSession();
  @override
  Future<void> start({required String id, required String title, String? subtitle, String? artUri, Duration? duration, bool canSeek = true, required MediaCallbacks callbacks}) async {}
  @override
  void update({required bool playing, required bool buffering, required Duration position}) {}
  @override
  Future<void> stop() async {}
}

/// `audio_service` handler: media notification with play/pause/±15 s on Android, Now Playing + remote commands on iOS.
class WehumAudioHandler extends BaseAudioHandler with SeekHandler {
  MediaCallbacks? _cb;
  bool _canSeek = true;

  void attach(MediaItem item, MediaCallbacks cb, {required bool canSeek}) {
    _cb = cb;
    _canSeek = canSeek;
    mediaItem.add(item);
    playbackState.add(PlaybackState(processingState: AudioProcessingState.loading, playing: false, controls: _controls(false)));
  }

  List<MediaControl> _controls(bool playing) => [
        if (_canSeek) MediaControl.rewind,
        playing ? MediaControl.pause : MediaControl.play,
        if (_canSeek) MediaControl.fastForward,
        MediaControl.stop,
      ];

  void push({required bool playing, required bool buffering, required Duration position}) {
    playbackState.add(playbackState.value.copyWith(
      controls: _controls(playing), playing: playing, updatePosition: position, speed: 1,
      processingState: buffering ? AudioProcessingState.buffering : AudioProcessingState.ready,
      systemActions: {if (_canSeek) MediaAction.seek, if (_canSeek) MediaAction.rewind, if (_canSeek) MediaAction.fastForward},
      androidCompactActionIndices: _canSeek ? const [0, 1, 2] : const [0]));
  }

  @override
  Future<void> play() async => _cb?.play();
  @override
  Future<void> pause() async => _cb?.pause();
  @override
  Future<void> rewind() async => _cb?.seekBy(const Duration(seconds: -15));
  @override
  Future<void> fastForward() async => _cb?.seekBy(const Duration(seconds: 15));
  @override
  Future<void> seek(Duration position) async {
    final cur = playbackState.value.position;
    await _cb?.seekBy(position - cur);
  }

  @override
  Future<void> stop() async {
    await _cb?.stop();
    playbackState.add(playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
    return super.stop();
  }
}

class AudioServiceMediaSession implements MediaSessionPort {
  AudioServiceMediaSession(this._handler);
  final WehumAudioHandler _handler;

  /// Called once from `bootstrap()`.
  static Future<AudioServiceMediaSession> init() async {
    final h = await AudioService.init(
      builder: WehumAudioHandler.new,
      config: const AudioServiceConfig(androidNotificationChannelId: 'app.wehum.meditation.playback', androidNotificationChannelName: 'WeHum playback', androidStopForegroundOnPause: false, androidNotificationOngoing: false),
    );
    return AudioServiceMediaSession(h);
  }

  @override
  Future<void> start({required String id, required String title, String? subtitle, String? artUri, Duration? duration, bool canSeek = true, required MediaCallbacks callbacks}) async {
    _handler.attach(MediaItem(id: id, title: title, artist: subtitle, duration: duration, artUri: artUri != null && artUri.startsWith('http') ? Uri.parse(artUri) : null), callbacks, canSeek: canSeek);
    await (await AudioSession.instance).setActive(true);
  }

  @override
  void update({required bool playing, required bool buffering, required Duration position}) => _handler.push(playing: playing, buffering: buffering, position: position);

  @override
  Future<void> stop() async {
    _handler.playbackState.add(_handler.playbackState.value.copyWith(processingState: AudioProcessingState.idle, playing: false));
  }
}
