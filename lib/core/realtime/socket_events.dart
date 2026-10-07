/// Socket event names — mirror of backend `src/realtime/socket-events.ts` (backend spec §7.2).
abstract final class SocketEvents {
  // client → server (all with ack)
  static const roomJoin = 'room:join';
  static const roomLeave = 'room:leave';
  static const timeSync = 'time:sync';
  static const presenceStart = 'presence:start';
  static const presenceBeat = 'presence:beat';
  static const presenceStop = 'presence:stop';
  static const lobbyJoin = 'lobby:join';
  static const lobbyLeave = 'lobby:leave';
  static const authRefresh = 'auth:refresh';
  // server → client
  static const liveAgg = 'live:agg';
  static const sessionLive = 'session:live';
  static const motdStats = 'motd:stats';
  static const lobbyState = 'lobby:state';
  static const groupStart = 'group:start';
  static const dedicationNew = 'dedication:new';
  static const dedicationHolding = 'dedication:holding';
  static const dedicationRemoved = 'dedication:removed';
  static const entitlementChanged = 'entitlement:changed';
  static const inboxNew = 'inbox:new';
  static const configChanged = 'config:changed';
  static const catalogChanged = 'catalog:changed';
  static const authExpiring = 'auth:expiring';
  static const forceLogout = 'force:logout';
}

class LiveAgg {
  LiveAgg({required this.total, required this.countries, required this.top, required this.quiet,
      required this.meditatedToday, required this.vibration, required this.at});
  final int total, countries, meditatedToday, vibration, at;
  final bool quiet;
  final List<({String country, int n})> top;

  factory LiveAgg.fromJson(Map<String, dynamic> j) => LiveAgg(
        total: j['total'] as int, countries: j['countries'] as int, quiet: j['quiet'] as bool,
        meditatedToday: j['meditatedToday'] as int, vibration: j['vibration'] as int, at: j['at'] as int,
        top: [for (final t in (j['top'] as List)) (country: t['c'] as String, n: t['n'] as int)],
      );
}
