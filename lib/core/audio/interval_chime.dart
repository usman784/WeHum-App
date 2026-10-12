import 'package:just_audio/just_audio.dart';

/// Plays the short bundled bell on top of a running meditation ("Chime every 5 m" in the player's mix sheet).
abstract class ChimePort {
  Future<void> ring();
  Future<void> dispose();
}

/// Tests and platforms without audio: nothing rings.
class NoChime implements ChimePort {
  const NoChime();
  @override
  Future<void> ring() async {}
  @override
  Future<void> dispose() async {}
}

class JustAudioChime implements ChimePort {
  AudioPlayer? _p;
  @override
  Future<void> ring() async {
    final p = _p ??= AudioPlayer();
    try {
      await p.setAsset('assets/audio/bell.wav');
      await p.setVolume(.8);
      await p.seek(Duration.zero);
      await p.play();
    } catch (_) {/* a missed chime is never an error for the meditation */}
  }

  @override
  Future<void> dispose() async {
    final p = _p;
    _p = null; // the next ring makes a fresh player (this object lives for the whole app run)
    await p?.dispose();
  }
}
