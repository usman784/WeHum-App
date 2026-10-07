import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// The socket as the app sees it. The real one wraps socket_io_client; tests use a fake server.
abstract class SocketTransport {
  void Function()? onConnect;
  void Function(String reason)? onDisconnect;
  void Function(Object error)? onConnectError;

  bool get connected;
  void connect();
  void dispose();
  void on(String event, void Function(dynamic data) cb);
  void emit(String event, [dynamic data]);

  /// Emit and wait for the ack. Throws [TimeoutException] when there is none in [timeout].
  Future<dynamic> emitAck(String event, dynamic data, {Duration timeout = const Duration(seconds: 5)});
}

typedef AuthProvider = Future<Map<String, dynamic>> Function();

/// Websocket-only `/live` connection with automatic reconnection (1 s → 30 s, jitter), spec §6.3.
class IoTransport extends SocketTransport {
  IoTransport(String url, AuthProvider auth) {
    _s = io.io(
      '$url/live',
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setRandomizationFactor(0.5)
          // evaluated on every (re)connect, so a refreshed access token is used automatically
          .setAuthFn((cb) => auth().then(cb))
          .build(),
    );
    _s.onConnect((_) => onConnect?.call());
    _s.onDisconnect((r) => onDisconnect?.call('$r'));
    _s.onConnectError((e) => onConnectError?.call(e ?? 'connect_error'));
  }
  late final io.Socket _s;

  @override
  bool get connected => _s.connected;
  @override
  void connect() => _s.connect();
  @override
  void dispose() => _s.dispose();
  @override
  void on(String event, void Function(dynamic data) cb) => _s.on(event, cb);
  @override
  void emit(String event, [dynamic data]) => _s.emit(event, data);
  @override
  Future<dynamic> emitAck(String event, dynamic data, {Duration timeout = const Duration(seconds: 5)}) =>
      _s.emitWithAckAsync(event, data).timeout(timeout);
}
