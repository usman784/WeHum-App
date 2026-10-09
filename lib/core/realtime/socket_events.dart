/// Socket event names and payloads — mirror of backend `src/realtime/socket-events.ts` (backend spec §7.2).
abstract final class SocketEvents {
  // client → server
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
  static const gratitudeNew = 'gratitude:new';
  static const gratitudeRemoved = 'gratitude:removed';
  static const entitlementChanged = 'entitlement:changed';
  static const inboxNew = 'inbox:new';
  static const configChanged = 'config:changed';
  static const catalogChanged = 'catalog:changed';
  static const authExpiring = 'auth:expiring';
  static const forceLogout = 'force:logout';
  static const error = 'error';

  static const serverToClient = [
    liveAgg, sessionLive, motdStats, lobbyState, groupStart, dedicationNew, dedicationHolding, dedicationRemoved,
    gratitudeNew, gratitudeRemoved, entitlementChanged, inboxNew, configChanged, catalogChanged, authExpiring, forceLogout, error,
  ];
}

/// `{ ok: true, data } | { ok: false, code }`
class Ack {
  const Ack(this.ok, {this.data, this.code});
  final bool ok;
  final Map<String, dynamic>? data;
  final String? code;

  factory Ack.parse(dynamic raw) {
    final m = raw is List && raw.isNotEmpty ? raw.first : raw;
    if (m is Map && m['ok'] == true) return Ack(true, data: (m['data'] as Map?)?.cast<String, dynamic>() ?? const {});
    if (m is Map) return Ack(false, code: m['code'] as String? ?? 'INTERNAL');
    return const Ack(false, code: 'INTERNAL');
  }
}

int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

class LiveAgg {
  const LiveAgg({required this.total, required this.countries, required this.top, this.todayTop = const [], required this.quiet, required this.meditatedToday, required this.vibration, required this.at});
  final int total, countries, meditatedToday, vibration, at;
  final bool quiet;
  final List<({String country, int n})> top;

  /// Where people meditated today (country → people): the map lights these up even when nobody is live right now.
  final List<({String country, int n})> todayTop;

  /// Countries for the map: everyone live now plus everyone who meditated today.
  Map<String, int> get where {
    final m = <String, int>{for (final t in todayTop) t.country: t.n};
    for (final t in top) {
      m[t.country] = (m[t.country] ?? 0) + t.n;
    }
    return m;
  }

  /// The one number the UI shows: people meditating now, or — when the room is quiet — people who meditated today.
  int get headline => quiet ? meditatedToday : total;

  factory LiveAgg.fromJson(Map<String, dynamic> j) => LiveAgg(
        total: _i(j['total']), countries: _i(j['countries']), quiet: j['quiet'] == true, meditatedToday: _i(j['meditatedToday']),
        vibration: _i(j['vibration']), at: _i(j['at']),
        top: [for (final t in ((j['top'] as List?) ?? const [])) (country: (t as Map)['c'] as String, n: _i(t['n']))],
        todayTop: [for (final t in ((j['todayTop'] as List?) ?? const [])) (country: (t as Map)['c'] as String, n: _i(t['n']))],
      );
}

class SessionLive {
  const SessionLive({required this.sessionId, required this.people, required this.countries});
  final String sessionId;
  final int people, countries;
  factory SessionLive.fromJson(Map<String, dynamic> j) => SessionLive(sessionId: j['sessionId'] as String, people: _i(j['people']), countries: _i(j['countries']));
}

class MotdStats {
  const MotdStats({required this.date, required this.practicedToday});
  final String date;
  final int practicedToday;
  factory MotdStats.fromJson(Map<String, dynamic> j) => MotdStats(date: j['date'] as String, practicedToday: _i(j['practicedToday']));
}

class LobbyState {
  const LobbyState({required this.date, required this.waiting, required this.countries, required this.regions, required this.startsAt});
  final String date;
  final int waiting, countries;
  final List<({String region, int n})> regions;
  final DateTime? startsAt;
  factory LobbyState.fromJson(Map<String, dynamic> j) => LobbyState(
        date: j['date'] as String, waiting: _i(j['waiting']), countries: _i(j['countries']),
        regions: [for (final r in ((j['regions'] as List?) ?? const [])) (region: (r as Map)['r'] as String, n: _i(r['n']))],
        startsAt: j['startsAt'] == null ? null : DateTime.parse(j['startsAt'] as String).toUtc(),
      );
}

class GroupStart {
  const GroupStart({required this.date, required this.startsAt, required this.sessionId, required this.lengthMin, required this.mediaKey});
  final String date, sessionId, mediaKey;
  final DateTime startsAt;
  final int lengthMin;
  factory GroupStart.fromJson(Map<String, dynamic> j) => GroupStart(
        date: j['date'] as String, startsAt: DateTime.parse(j['startsAt'] as String).toUtc(), sessionId: (j['sessionId'] ?? '') as String,
        lengthMin: _i(j['lengthMin']), mediaKey: (j['mediaKey'] ?? '') as String,
      );
}

class EntitlementChanged {
  const EntitlementChanged({required this.active, this.productId, this.periodType, this.expiresAt, this.billingIssue = false});
  final bool active, billingIssue;
  final String? productId, periodType;
  final DateTime? expiresAt;
  factory EntitlementChanged.fromJson(Map<String, dynamic> j) => EntitlementChanged(
        active: j['active'] == true, productId: j['productId'] as String?, periodType: j['periodType'] as String?,
        expiresAt: j['expiresAt'] == null ? null : DateTime.tryParse(j['expiresAt'] as String)?.toUtc(), billingIssue: j['billingIssue'] == true,
      );
}
