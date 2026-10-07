import 'dart:async';
import 'package:get/get.dart';
import '../services/logger.dart';
import '../services/perf_service.dart';
import 'socket_events.dart';
import 'socket_transport.dart';

enum SocketState { disconnected, connecting, connected, paused }

/// One `/live` socket for the whole app (spec §6.3).
/// - rooms are reference counted, remembered and re-joined after every reconnect (max 4);
/// - "paused" only after 10 s without a connection, so short blips never flash a warning;
/// - the app is disconnected 30 s after going to the background unless a meditation keeps it alive.
class SocketService extends GetxService {
  SocketService({
    required SocketTransport Function() transportFactory,
    required this.refreshAccess,
    this.onForceLogout,
    this.onTimeSync,
    this.pausedAfter = const Duration(seconds: 10),
    this.backgroundGrace = const Duration(seconds: 30),
    this.maxRooms = 4,
  }) : _factory = transportFactory;

  final SocketTransport Function() _factory;
  /// Returns true when a fresh access token is available.
  final Future<bool> Function() refreshAccess;
  final void Function(String reason)? onForceLogout;
  /// Called with the median server clock offset after every sync.
  final void Function(Duration offset)? onTimeSync;
  final Duration pausedAfter, backgroundGrace;
  final int maxRooms;

  SocketTransport? _t;
  final state = SocketState.disconnected.obs;
  final _roomRefs = <String, int>{};
  final _lobbies = <String>{};
  final _streams = <String, StreamController<dynamic>>{};
  Timer? _pausedTimer, _bgTimer;
  DateTime? _downSince;
  bool _keepAlive = false, _wantConnected = false;

  /// Seconds the socket was down before the last reconnect (for the `socket_state` analytics event).
  void Function(String state, int downSec)? onStateEvent;

  bool get connected => state.value == SocketState.connected;
  /// "Live counts paused" is shown when this is true. Never show numbers as live while it is.
  bool get livePaused => state.value == SocketState.paused;
  Set<String> get rooms => {..._roomRefs.keys, for (final d in _lobbies) 'lobby:$d'};

  Stream<T> on<T>(String event, T Function(Map<String, dynamic>) parse) =>
      (_streams[event] ??= StreamController<dynamic>.broadcast()).stream.map((d) => parse((d as Map).cast<String, dynamic>()));

  StreamController<dynamic> _ctl(String e) => _streams[e] ??= StreamController<dynamic>.broadcast();

  // ───────────── connection
  Future<void> connect() async {
    _wantConnected = true;
    _bgTimer?.cancel();
    if (_t != null) {
      if (!_t!.connected && state.value == SocketState.disconnected) {
        state.value = SocketState.connecting;
        _t!.connect();
      }
      return;
    }
    state.value = SocketState.connecting;
    Perf.start('socket_connect');
    final t = _t = _factory();
    t.onConnect = _handleConnect;
    t.onDisconnect = (r) {
      logd('socket', 'disconnect $r');
      _markDown();
    };
    t.onConnectError = (e) async {
      logd('socket', 'connect_error $e');
      if (_isTokenExpired(e) && await refreshAccess()) {
        t.connect(); // the auth function reads the new token
        return;
      }
      _markDown();
    };
    for (final e in SocketEvents.serverToClient) {
      t.on(e, (d) => _onServer(e, d));
    }
    t.connect();
  }

  static bool _isTokenExpired(Object e) {
    if (e is Map) {
      final data = e['data'];
      if (data is Map && data['code'] == 'TOKEN_EXPIRED') return true;
      if (e['code'] == 'TOKEN_EXPIRED') return true;
    }
    return e.toString().contains('TOKEN_EXPIRED');
  }

  void _handleConnect() {
    Perf.finish('socket_connect');
    _pausedTimer?.cancel();
    final wasDown = _downSince;
    _downSince = null;
    state.value = SocketState.connected;
    final t = _t!;
    for (final r in _roomRefs.keys) {
      t.emitAck(SocketEvents.roomJoin, {'room': r}).catchError((_) => null);
    }
    for (final d in _lobbies) {
      t.emitAck(SocketEvents.lobbyJoin, {'date': d}).catchError((_) => null);
    }
    syncTime();
    if (wasDown != null) onStateEvent?.call('reconnected', DateTime.now().difference(wasDown).inSeconds);
  }

  void _markDown() {
    if (state.value == SocketState.disconnected && _t == null) return;
    _downSince ??= DateTime.now();
    if (state.value == SocketState.connected || state.value == SocketState.connecting) state.value = SocketState.connecting;
    _pausedTimer?.cancel();
    _pausedTimer = Timer(pausedAfter, () {
      if (_wantConnected && state.value != SocketState.connected) {
        state.value = SocketState.paused;
        onStateEvent?.call('paused', 0);
      }
    });
  }

  Future<void> _onServer(String event, dynamic data) async {
    if (event == SocketEvents.authExpiring) {
      if (await refreshAccess()) {
        final tok = await _currentToken?.call();
        if (tok != null) await _emitAckSafe(SocketEvents.authRefresh, {'token': tok});
      }
      return;
    }
    if (event == SocketEvents.error && data is Map && data['code'] == 'TOKEN_EXPIRED') {
      if (await refreshAccess()) _t?.connect();
      return;
    }
    if (event == SocketEvents.forceLogout) {
      onForceLogout?.call((data is Map ? data['reason'] : null)?.toString() ?? 'revoked');
    }
    if (data is Map) _ctl(event).add(data);
  }

  /// Set by the app so `auth:expiring` can send the refreshed token.
  Future<String?> Function()? _currentToken;
  void attachTokenSource(Future<String?> Function() f) => _currentToken = f;

  Future<void> disconnect() async {
    _wantConnected = false;
    _pausedTimer?.cancel();
    _bgTimer?.cancel();
    _t?.dispose();
    _t = null;
    _downSince = null;
    state.value = SocketState.disconnected;
  }

  // ───────────── app lifecycle (spec §6.3)
  /// While a meditation plays the socket stays up in the background (presence beats continue).
  set keepAlive(bool v) {
    _keepAlive = v;
    if (v && _wantConnected == false && _bgPaused) {
      _bgPaused = false;
      connect();
    }
  }

  bool _bgPaused = false;

  void onBackground() {
    _bgTimer?.cancel();
    if (_keepAlive) return;
    _bgTimer = Timer(backgroundGrace, () async {
      if (_keepAlive) return;
      _bgPaused = true;
      await disconnect();
    });
  }

  Future<void> onForeground() async {
    _bgTimer?.cancel();
    if (_bgPaused || (_t == null && _roomRefs.isNotEmpty)) {
      _bgPaused = false;
      await connect();
    }
  }

  // ───────────── rooms
  /// Join [room] (ref counted). Returns false when the 4-room limit would be exceeded.
  Future<bool> joinRoom(String room) async {
    final had = _roomRefs.containsKey(room);
    if (!had && _roomRefs.length + _lobbies.length >= maxRooms) return false;
    _roomRefs[room] = (_roomRefs[room] ?? 0) + 1;
    if (!had && connected) {
      final a = await _emitAckSafe(SocketEvents.roomJoin, {'room': room});
      if (a != null && !a.ok) {
        _roomRefs.remove(room);
        return false;
      }
    }
    return true;
  }

  void leaveRoom(String room) {
    final n = (_roomRefs[room] ?? 0) - 1;
    if (n > 0) {
      _roomRefs[room] = n;
      return;
    }
    if (_roomRefs.remove(room) != null && connected) _t?.emit(SocketEvents.roomLeave, {'room': room});
  }

  /// Joins the lobby for [date]. Ack gives `startsAt` + `waiting`; code `PREMIUM_REQUIRED` for non-members.
  Future<Ack> joinLobby(String date) async {
    if (!_lobbies.contains(date) && _roomRefs.length + _lobbies.length >= maxRooms) return const Ack(false, code: 'ROOM_LIMIT');
    _lobbies.add(date);
    final a = await _emitAckSafe(SocketEvents.lobbyJoin, {'date': date});
    if (a != null && !a.ok) _lobbies.remove(date);
    return a ?? const Ack(false, code: 'NETWORK');
  }

  void leaveLobby(String date) {
    if (_lobbies.remove(date) && connected) _t?.emit(SocketEvents.lobbyLeave, {'date': date});
  }

  // ───────────── emit helpers
  Future<Ack?> _emitAckSafe(String event, Map<String, dynamic> data) async {
    final t = _t;
    if (t == null || !t.connected) return null;
    try {
      return Ack.parse(await t.emitAck(event, data));
    } catch (_) {
      return null;
    }
  }

  /// Emit with ack; null when offline or timed out.
  Future<Ack?> emitAck(String event, Map<String, dynamic> data) => _emitAckSafe(event, data);

  void emit(String event, Map<String, dynamic> data) {
    final t = _t;
    if (t != null && t.connected) t.emit(event, data);
  }

  /// Median of 3 samples: offset = serverTime − (t0 + rtt/2) (spec §10).
  Future<Duration?> syncTime() async {
    final samples = <int>[];
    for (var i = 0; i < 3; i++) {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final a = await _emitAckSafe(SocketEvents.timeSync, {'t0': t0});
      final t1 = DateTime.now().millisecondsSinceEpoch;
      final st = a?.data?['serverTime'];
      if (st is num) samples.add(st.toInt() - (t0 + (t1 - t0) ~/ 2));
    }
    if (samples.isEmpty) return null;
    samples.sort();
    final off = Duration(milliseconds: samples[samples.length ~/ 2]);
    onTimeSync?.call(off);
    return off;
  }

  @override
  void onClose() {
    disconnect();
    for (final c in _streams.values) {
      c.close();
    }
    super.onClose();
  }
}
