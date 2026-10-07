import 'dart:async';
import 'package:meditation/core/audio/audio_engine.dart';

class FakeAudioEngine implements AudioEngine {
  final _pos = StreamController<Duration>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _status = StreamController<EngineStatus>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _errors = StreamController<Object>.broadcast();
  final _interrupt = StreamController<InterruptionKind>.broadcast();
  bool _isPlaying = false;
  Duration _p = Duration.zero;
  Duration? total = const Duration(minutes: 10);
  final opened = <({EngineSource src, Duration start})>[];
  final seeks = <Duration>[];
  int stops = 0;
  bool disposed = false;
  Object? openError;

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
  Stream<InterruptionKind> get interruptions => _interrupt.stream;
  @override
  bool get isPlaying => _isPlaying;
  @override
  Duration get currentPosition => _p;
  @override
  Duration? get currentDuration => total;

  @override
  Future<Duration?> open(EngineSource src, {Duration start = Duration.zero}) async {
    if (openError != null) throw openError!;
    opened.add((src: src, start: start));
    _p = start;
    return total;
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration to) async {
    seeks.add(to);
    _p = to;
  }

  @override
  Future<void> stop() async => stops++;
  @override
  Future<void> dispose() async => disposed = true;

  // test controls
  void tick(Duration p) {
    _p = p;
    _pos.add(p);
  }

  void setStatus(EngineStatus s) => _status.add(s);
  void fail(Object e) => _errors.add(e);
  void interrupt(InterruptionKind k) {
    _interrupt.add(k);
    if (k == InterruptionKind.began || k == InterruptionKind.becomingNoisy) pause();
    if (k == InterruptionKind.endedShouldResume) play();
  }
}
