import 'dart:async';
import 'package:meditation/core/realtime/socket_transport.dart';

/// In-memory stand-in for the backend gateway: records client events, answers acks, pushes server events.
class FakeTransport extends SocketTransport {
  bool _connected = false;
  final handlers = <String, void Function(dynamic)>{};
  final sent = <({String event, dynamic data})>[];
  /// event → ack reply. Default: `{ok:true,data:{}}`; time:sync echoes a server clock.
  final acks = <String, dynamic Function(dynamic data)>{};
  int connectCalls = 0;
  bool disposed = false;
  Duration serverClockSkew = Duration.zero;

  @override
  bool get connected => _connected;
  @override
  void connect() => connectCalls++;
  @override
  void dispose() {
    disposed = true;
    _connected = false;
  }

  @override
  void on(String event, void Function(dynamic data) cb) => handlers[event] = cb;
  @override
  void emit(String event, [dynamic data]) => sent.add((event: event, data: data));

  @override
  Future<dynamic> emitAck(String event, dynamic data, {Duration timeout = const Duration(seconds: 5)}) async {
    sent.add((event: event, data: data));
    if (!_connected) throw TimeoutException('offline');
    if (acks.containsKey(event)) return acks[event]!(data);
    if (event == 'time:sync') return {'ok': true, 'data': {'t0': data['t0'], 'serverTime': DateTime.now().add(serverClockSkew).millisecondsSinceEpoch}};
    return {'ok': true, 'data': {}};
  }

  // test controls
  void serverConnects() {
    _connected = true;
    onConnect?.call();
  }

  void serverDrops([String reason = 'transport close']) {
    _connected = false;
    onDisconnect?.call(reason);
  }

  void serverPushes(String event, Map<String, dynamic> data) => handlers[event]?.call(data);
  List<dynamic> sentData(String event) => [for (final s in sent) if (s.event == event) s.data];
  int count(String event) => sent.where((s) => s.event == event).length;
}
