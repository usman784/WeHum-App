import 'dart:async';
import 'package:get/get.dart';
import 'socket_events.dart';
import 'socket_service.dart';

/// "You are meditating" (spec §6.3): `presence:start` (ack = together numbers), `presence:beat` every 30 s —
/// also in the background — and `presence:stop`. The server drops an entry 90 s after the last beat.
class PresenceService extends GetxService {
  PresenceService(this._socket, {this.beatEvery = const Duration(seconds: 30)});
  final SocketService _socket;
  final Duration beatEvery;

  /// People/countries meditating with you, from the start ack and later `session:live`.
  final together = Rxn<({int people, int countries})>();
  final active = RxnString();
  Map<String, dynamic>? _startPayload;
  Timer? _beat;
  StreamSubscription<SessionLive>? _sessSub;

  /// [mode] solo | group | silence. Free YouTube playback of non-catalog items must not call this.
  Future<void> start({required String meditationId, String? sessionId, required String kind, int? lengthMin, String mode = 'solo'}) async {
    await stop();
    active.value = meditationId;
    _socket.keepAlive = true;
    _startPayload = {'meditationId': meditationId, if (sessionId != null) 'sessionId': sessionId, 'kind': kind, if (lengthMin != null) 'lengthMin': lengthMin, 'mode': mode};
    if (sessionId != null) {
      _socket.joinRoom('session:$sessionId');
      _sessSub = _socket.on(SocketEvents.sessionLive, SessionLive.fromJson).where((s) => s.sessionId == sessionId).listen((s) => together.value = (people: s.people, countries: s.countries));
    }
    await _sendStart();
    _beat = Timer.periodic(beatEvery, (_) => _tick());
  }

  Future<void> _sendStart() async {
    final p = _startPayload;
    if (p == null) return;
    final a = await _socket.emitAck(SocketEvents.presenceStart, p);
    final t = a?.data?['together'];
    if (a != null && a.ok && t is Map) together.value = (people: (t['people'] as num).toInt(), countries: (t['countries'] as num).toInt());
  }

  Future<void> _tick() async {
    final id = active.value;
    if (id == null) return;
    if (!_socket.connected) return; // the next beat after reconnect starts over if the server forgot us
    final a = await _socket.emitAck(SocketEvents.presenceBeat, {'meditationId': id});
    if (a != null && !a.ok && a.code == 'NOT_FOUND') await _sendStart(); // server dropped the entry (e.g. >90 s offline)
  }

  Future<void> stop() async {
    final id = active.value;
    final sid = _startPayload?['sessionId'] as String?;
    _beat?.cancel();
    _beat = null;
    // tell the server first: the room should empty at once, not after the cleanup below
    if (id != null) _socket.emit(SocketEvents.presenceStop, {'meditationId': id});
    if (sid != null) _socket.leaveRoom('session:$sid');
    active.value = null;
    _startPayload = null;
    together.value = null;
    _socket.keepAlive = false;
    final sub = _sessSub;
    _sessSub = null;
    await sub?.cancel();
  }

  @override
  void onClose() {
    stop();
    super.onClose();
  }
}
