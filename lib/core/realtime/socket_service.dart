// NOTE: written against socket_io_client 3.x (setAuthFn, emitWithAckAsync). Verify against the pinned version at P4.
import 'dart:async';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/env.dart';
import '../network/session_store.dart';
import 'socket_events.dart';

enum SocketState { disconnected, connecting, connected, paused }

/// One /live socket for the whole app (spec §6.3). Rooms are remembered and re-joined after reconnect.
class SocketService extends GetxService {
  SocketService(this.session, this.refreshAccess);
  final SessionStore session;
  final Future<bool> Function() refreshAccess;

  io.Socket? _s;
  final state = SocketState.disconnected.obs;
  final _rooms = <String>{};
  final _streams = <String, StreamController<dynamic>>{};
  Timer? _pausedTimer;
  int serverOffsetMs = 0;

  Stream<T> on<T>(String event, T Function(dynamic) parse) =>
      (_streams[event] ??= StreamController<dynamic>.broadcast()).stream.map(parse);

  Future<void> connect() async {
    if (_s != null) return;
    state.value = SocketState.connecting;
    final s = _s = io.io('${Env.socketUrl}/live', io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .enableReconnection()
        .setReconnectionDelay(1000)
        .setReconnectionDelayMax(30000)
        .setRandomizationFactor(0.5)
        .setAuthFn((cb) async => cb({'token': session.accessToken, 'installId': await session.installId()}))
        .build());

    s.onConnect((_) async {
      _pausedTimer?.cancel();
      state.value = SocketState.connected;
      for (final r in _rooms) { s.emitWithAck(SocketEvents.roomJoin, {'room': r}); }
      await syncTime();
    });
    s.onDisconnect((_) => _schedulePaused());
    s.onConnectError((err) async {
      final code = (err is Map) ? err['code'] : null;
      if (code == 'TOKEN_EXPIRED' && await refreshAccess()) { s.connect(); }
      _schedulePaused();
    });
    s.on(SocketEvents.authExpiring, (_) async {
      if (await refreshAccess()) s.emitWithAck(SocketEvents.authRefresh, {'token': session.accessToken});
    });
    for (final e in [SocketEvents.liveAgg, SocketEvents.sessionLive, SocketEvents.motdStats, SocketEvents.lobbyState,
        SocketEvents.groupStart, SocketEvents.dedicationNew, SocketEvents.dedicationHolding, SocketEvents.dedicationRemoved,
        SocketEvents.entitlementChanged, SocketEvents.inboxNew, SocketEvents.configChanged, SocketEvents.catalogChanged,
        SocketEvents.forceLogout]) {
      s.on(e, (data) => (_streams[e] ??= StreamController<dynamic>.broadcast()).add(data));
    }
    s.connect();
  }

  /// UI shows "Live counts paused" only after 10 s without a connection.
  void _schedulePaused() {
    _pausedTimer?.cancel();
    _pausedTimer = Timer(const Duration(seconds: 10), () {
      if (state.value != SocketState.connected) state.value = SocketState.paused;
    });
  }

  Future<Map?> join(String room) async {
    _rooms.add(room);
    if (state.value != SocketState.connected) return null;
    return await _s!.emitWithAckAsync(SocketEvents.roomJoin, {'room': room}) as Map?;
  }

  void leave(String room) {
    _rooms.remove(room);
    _s?.emit(SocketEvents.roomLeave, {'room': room});
  }

  Future<dynamic> emitAck(String event, Map<String, dynamic> data) =>
      _s!.emitWithAckAsync(event, data).timeout(const Duration(seconds: 5));

  void emit(String event, Map<String, dynamic> data) => _s?.emit(event, data);

  /// Median of 3 samples: offset = serverTime − (t0 + rtt/2). Used for group countdown (never device clock).
  Future<void> syncTime() async {
    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final r = await emitAck(SocketEvents.timeSync, {'t0': t0}) as Map;
      final t1 = DateTime.now().millisecondsSinceEpoch;
      samples.add((r['data']['serverTime'] as int) - (t0 + (t1 - t0) ~/ 2));
    }
    samples.sort();
    serverOffsetMs = samples[1];
  }

  DateTime get serverNow => DateTime.now().add(Duration(milliseconds: serverOffsetMs)).toUtc();

  Future<void> disconnect() async {
    _s?.dispose();
    _s = null;
    state.value = SocketState.disconnected;
  }

  @override
  void onClose() { disconnect(); for (final c in _streams.values) { c.close(); } super.onClose(); }
}
