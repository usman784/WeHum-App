import 'dart:async';
import 'package:get/get.dart';
import 'socket_events.dart';
import 'socket_service.dart';

/// Live counts (`live:agg`) for Today, World map, Intro 2, Together (spec §6.3, §13).
/// Screens call [acquire] on show and [release] on hide; the `today`/`world` rooms are joined once and shared.
class LiveService extends GetxService {
  LiveService(this._socket, {Future<LiveAgg?> Function()? restSnapshot}) : _rest = restSnapshot;
  final SocketService _socket;
  final Future<LiveAgg?> Function()? _rest;

  final agg = Rxn<LiveAgg>();
  final motdPracticed = <String, int>{}.obs; // date → count (`motd:stats`)
  final sessionPeople = <String, SessionLive>{}.obs; // sessionId → live (`session:live`)
  StreamSubscription<LiveAgg>? _aggSub;
  StreamSubscription<MotdStats>? _motdSub;
  StreamSubscription<SessionLive>? _sessSub;
  Worker? _paused;
  bool _fallbackTried = false;

  /// True while numbers must not be presented as live ("Live counts paused").
  bool get paused => _socket.livePaused;

  @override
  void onInit() {
    super.onInit();
    _aggSub = _socket.on(SocketEvents.liveAgg, LiveAgg.fromJson).listen((a) => agg.value = a);
    _motdSub = _socket.on(SocketEvents.motdStats, MotdStats.fromJson).listen((m) => motdPracticed[m.date] = m.practicedToday);
    _sessSub = _socket.on(SocketEvents.sessionLive, SessionLive.fromJson).listen((s) => sessionPeople[s.sessionId] = s);
    // once, when the socket gives up: one REST snapshot as a fallback (never repeated, never labelled live)
    _paused = ever(_socket.state, (s) async {
      if (s == SocketState.paused && agg.value == null && !_fallbackTried && _rest != null) {
        _fallbackTried = true;
        agg.value = await _rest();
      }
    });
  }

  Future<void> acquire(String room) => _socket.joinRoom(room);
  void release(String room) => _socket.leaveRoom(room);

  Future<void> acquireToday() => acquire('today');
  void releaseToday() => release('today');
  Future<void> acquireWorld() => acquire('world');
  void releaseWorld() => release('world');
  Future<void> acquireMotd(String date) => acquire('motd:$date');
  void releaseMotd(String date) => release('motd:$date');
  Future<void> acquireSession(String id) => acquire('session:$id');
  void releaseSession(String id) => release('session:$id');

  @override
  void onClose() {
    _aggSub?.cancel();
    _motdSub?.cancel();
    _sessSub?.cancel();
    _paused?.dispose();
    super.onClose();
  }
}
