import 'dart:async';
import 'package:get/get.dart';
import '../services/time_service.dart';
import 'socket_events.dart';
import 'socket_service.dart';

/// Group meditation lobby (spec §6.3, §13). At T0 the server sends `group:start`; every device also schedules a
/// local timer from the server-synced clock, so the start still happens if the event is late. Whichever comes first
/// fires once; late joiners get the position `now − startsAt`.
class LobbyService extends GetxService {
  LobbyService(this._socket, this._time);
  final SocketService _socket;
  final TimeService _time;

  final state = Rxn<LobbyState>();
  final startsAt = Rxn<DateTime>();
  final started = Rxn<GroupStart>();
  final joinedDate = RxnString();
  StreamSubscription<LobbyState>? _stateSub;
  StreamSubscription<GroupStart>? _startSub;
  Timer? _timer;
  String? _firedFor;

  /// Seconds until T0 by the server clock (≤ 0 once started).
  Duration? get untilStart => startsAt.value?.difference(_time.now());

  /// Where a late joiner seeks to.
  Duration lateOffset() {
    final s = startsAt.value;
    if (s == null) return Duration.zero;
    final d = _time.now().difference(s);
    return d.isNegative ? Duration.zero : d;
  }

  @override
  void onInit() {
    super.onInit();
    _stateSub = _socket.on(SocketEvents.lobbyState, LobbyState.fromJson).listen((s) {
      if (s.date != joinedDate.value) return;
      state.value = s;
      if (s.startsAt != null) _schedule(s.date, s.startsAt!);
    });
    _startSub = _socket.on(SocketEvents.groupStart, GroupStart.fromJson).listen((g) => _fire(g.date, g));
  }

  /// Returns the ack code on failure (`PREMIUM_REQUIRED`, `ROOM_LIMIT`, `NETWORK`), null on success.
  Future<String?> join(String date) async {
    final a = await _socket.joinLobby(date);
    if (!a.ok) return a.code;
    joinedDate.value = date;
    final s = a.data?['startsAt'];
    if (s is String) _schedule(date, DateTime.parse(s).toUtc());
    return null;
  }

  void leave() {
    final d = joinedDate.value;
    if (d != null) _socket.leaveLobby(d);
    _timer?.cancel();
    joinedDate.value = null;
    state.value = null;
    startsAt.value = null;
    started.value = null;
    _firedFor = null;
  }

  void _schedule(String date, DateTime at) {
    startsAt.value = at;
    _timer?.cancel();
    final wait = at.difference(_time.now());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, () => _fire(date, null));
  }

  void _fire(String date, GroupStart? g) {
    if (_firedFor == date) return; // server event and local timer: only the first one counts
    _firedFor = date;
    _timer?.cancel();
    final at = g?.startsAt ?? startsAt.value ?? _time.now();
    started.value = g ?? GroupStart(date: date, startsAt: at, sessionId: '', lengthMin: 0, mediaKey: '');
  }

  @override
  void onClose() {
    _stateSub?.cancel();
    _startSub?.cancel();
    _timer?.cancel();
    super.onClose();
  }
}
