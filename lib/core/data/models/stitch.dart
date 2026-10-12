import 'content.dart';
import 'json.dart';

/// Models added with the Stitch redesign (backend spec §5.6). Every field is optional on the wire, so an older
/// backend never breaks the app: missing data simply hides the card that needs it.

/// People now, grouped into the three belts the designs show next to the live count.
class Belts {
  const Belts({this.americas = 0, this.emea = 0, this.apac = 0});
  final int americas, emea, apac;
  int get total => americas + emea + apac;
  bool get isEmpty => total == 0;
  static const none = Belts();
  factory Belts.from(Object? v) {
    final j = asJson(v);
    return Belts(americas: asInt(j['americas']), emea: asInt(j['emea']), apac: asInt(j['apac']));
  }
}

enum DayState { done, rest, today, upcoming, missed }

class StreakDay {
  const StreakDay({required this.date, required this.label, required this.state, this.minutes = 0});
  final String date, label;
  final DayState state;
  final int minutes;
}

/// Forgiving streak: current run, record, the weekly grace day and the Monday–Sunday strip.
class StreakInfo {
  const StreakInfo({
    this.current = 0, this.record = 0, this.graceLeft = 1, this.graceDays = 1, this.weeklyGoal = 5, this.goalDaysDone = 0, this.daysToGoal = 5, this.doneToday = false, this.week = const [],
  });
  final int current, record, graceLeft, graceDays, weeklyGoal, goalDaysDone, daysToGoal;
  final bool doneToday;
  final List<StreakDay> week;

  /// "1 sit to reach weekly goal" / "Weekly goal reached".
  String get goalLine => daysToGoal <= 0 ? 'Weekly goal reached' : '$daysToGoal ${daysToGoal == 1 ? 'sit' : 'sits'} to reach weekly goal';

  static StreakInfo? from(Object? v) {
    if (v is! Map) return null;
    final j = asJson(v);
    return StreakInfo(
      current: asInt(j['current']), record: asInt(j['record']), graceLeft: asInt(j['graceLeft'], 1), graceDays: asInt(j['graceDays'], 1), weeklyGoal: asInt(j['weeklyGoal'], 5),
      goalDaysDone: asInt(j['goalDaysDone']), daysToGoal: asInt(j['daysToGoal']), doneToday: j['doneToday'] == true,
      week: [
        for (final d in asJsonList(j['week']))
          StreakDay(
            date: (d['date'] ?? '') as String, label: (d['label'] ?? '') as String, minutes: asInt(d['minutes']),
            state: DayState.values.firstWhere((s) => s.name == d['state'], orElse: () => DayState.upcoming),
          ),
      ],
    );
  }
}

class ContinueLast {
  const ContinueLast({required this.sessionId, required this.title, this.positionSec = 0, this.leftSec = 0});
  final String sessionId, title;
  final int positionSec, leftSec;
  int get leftMin => (leftSec / 60).ceil().clamp(1, 999);
  static ContinueLast? from(Object? v) {
    if (v is! Map) return null;
    final j = asJson(v);
    final id = asStr(j['sessionId']);
    if (id == null) return null;
    return ContinueLast(sessionId: id, title: (j['title'] ?? '') as String, positionSec: asInt(j['positionSec']), leftSec: asInt(j['leftSec']));
  }
}

class LibrarySummary {
  const LibrarySummary({this.sittingNow = 0, this.belts = const [], this.sitsToday = const {}, this.completedToday = const {}, this.topToday = const []});
  final int sittingNow;
  final List<({String key, String name, int n})> belts;
  /// theme id → people who sat a meditation of it today.
  final Map<String, int> sitsToday;
  /// session id → people who finished it today.
  final Map<String, int> completedToday;
  final List<String> topToday;
  factory LibrarySummary.fromJson(Json j) => LibrarySummary(
        sittingNow: asInt(j['sittingNow']),
        belts: [for (final r in asJsonList(j['regions'])) (key: (r['key'] ?? '') as String, name: (r['name'] ?? '') as String, n: asInt(r['sittingNow']))],
        sitsToday: {for (final d in asJsonList(j['disciplines'])) d['id'] as String: asInt(d['sitsToday'])},
        completedToday: {for (final t in asJsonList(j['topToday'])) t['sessionId'] as String: asInt(t['completedToday'])},
        topToday: [for (final t in asJsonList(j['topToday'])) t['sessionId'] as String],
      );
}

class BellOption {
  const BellOption({required this.id, required this.name, this.durationSec, this.premium = true});
  final String id, name;
  final int? durationSec;
  final bool premium;
}

class SilenceInfo {
  const SilenceInfo({
    this.sittingNow = 0, this.belts = const Belts(), this.quiet = true, this.todayTotal = 0, this.todayZones = 0,
    this.durations = const [5, 10, 15, 20, 30, 45, 60, 0], this.inhaleSec = 4, this.exhaleSec = 6, this.extendMin = 5,
    this.opening = const [], this.interval = const [], this.closing = const [],
  });
  final int sittingNow, todayTotal, todayZones, inhaleSec, exhaleSec, extendMin;
  final Belts belts;
  final bool quiet;
  /// Minutes; 0 = open-ended.
  final List<int> durations;
  final List<BellOption> opening, interval, closing;

  factory SilenceInfo.fromJson(Json j) {
    List<BellOption> bells(Object? v) => [
          for (final b in asJsonList(v)) BellOption(id: b['id'] as String, name: (b['name'] ?? '') as String, durationSec: (b['durationSec'] as num?)?.toInt(), premium: b['access'] != 'free'),
        ];
    final c = asJson(j['cadence']);
    final b = asJson(j['bells']);
    return SilenceInfo(
      sittingNow: asInt(j['sittingNow']), belts: Belts.from(j['belts']), quiet: j['quiet'] != false, todayTotal: asInt(j['todayTotal']), todayZones: asInt(j['todayZones']),
      durations: [for (final d in ((j['durations'] as List?) ?? const [5, 10, 15, 20, 30, 45, 60, 0])) (d as num).toInt()],
      inhaleSec: asInt(c['inhaleSec'], 4), exhaleSec: asInt(c['exhaleSec'], 6), extendMin: asInt(j['extendMin'], 5),
      opening: bells(b['opening']), interval: bells(b['interval']), closing: bells(b['closing']),
    );
  }
}

class WorldBelt {
  const WorldBelt({required this.key, required this.name, this.sittingNow = 0, this.minutesToday = 0, this.syncShare = 0});
  final String key, name;
  final int sittingNow, minutesToday, syncShare;
}

class WorldGauge {
  const WorldGauge({this.total, this.countries, this.vibration = 0, this.quiet = true, this.meditatedToday, this.minutesToday = 0, this.trendPct, this.regions = const [], this.belts = const []});
  final int? total, countries, meditatedToday, trendPct;
  final int vibration, minutesToday;
  final bool quiet;
  final List<WorldBelt> regions, belts;
  factory WorldGauge.fromJson(Json j) {
    WorldBelt b(Json x, {bool country = false}) => WorldBelt(
          key: ((country ? x['country'] : x['key']) ?? '') as String, name: (x['name'] ?? '') as String, sittingNow: asInt(x['sittingNow']),
          minutesToday: asInt(x['minutesToday']), syncShare: asInt(x['syncShare']));
    return WorldGauge(
      total: (j['total'] as num?)?.toInt(), countries: (j['countries'] as num?)?.toInt(), vibration: asInt(j['vibration']), quiet: j['quiet'] != false,
      meditatedToday: (j['meditatedToday'] as num?)?.toInt(), minutesToday: asInt(j['minutesToday']), trendPct: (j['trendPct'] as num?)?.toInt(),
      regions: asJsonList(j['regions']).map(b).toList(), belts: [for (final x in asJsonList(j['belts'])) b(x, country: true)],
    );
  }
}

class CrisisAction {
  const CrisisAction({required this.type, required this.label, required this.value});
  final String type, label, value;
  bool get isCall => type == 'call';
}

class CrisisLine {
  const CrisisLine({required this.id, required this.name, this.kind = '', this.description = '', this.actions = const []});
  final String id, name, kind, description;
  final List<CrisisAction> actions;
}

class CrisisDirectory {
  const CrisisDirectory({this.regionCode = 'US', this.regionName = '', this.regions = const [], this.availability = '', this.lines = const [], this.international = const [], this.tip = ''});
  final String regionCode, regionName, availability, tip;
  final List<({String code, String name})> regions;
  final List<CrisisLine> lines;
  final List<({String country, String line, String value})> international;
  factory CrisisDirectory.fromJson(Json j) {
    final r = asJson(j['region']);
    return CrisisDirectory(
      regionCode: (r['code'] ?? 'US') as String, regionName: (r['name'] ?? '') as String, availability: (j['availability'] ?? '') as String, tip: (j['tip'] ?? '') as String,
      regions: [for (final x in asJsonList(j['regions'])) (code: x['code'] as String, name: (x['name'] ?? '') as String)],
      lines: [
        for (final l in asJsonList(j['lines']))
          CrisisLine(
            id: l['id'] as String, name: (l['name'] ?? '') as String, kind: (l['kind'] ?? '') as String, description: (l['description'] ?? '') as String,
            actions: [for (final a in asJsonList(l['actions'])) CrisisAction(type: (a['type'] ?? 'call') as String, label: (a['label'] ?? '') as String, value: (a['value'] ?? '') as String)],
          ),
      ],
      international: [for (final x in asJsonList(j['international'])) (country: (x['country'] ?? '') as String, line: (x['line'] ?? '') as String, value: (x['value'] ?? '') as String)],
    );
  }
}

class TranscriptLine {
  const TranscriptLine({required this.t, required this.text, this.section});
  final int t;
  final String text;
  final String? section;
}

class WeekMessage {
  const WeekMessage({required this.date, this.title, this.durationSec, required this.state, this.locked = false});
  final String date, state;
  final String? title;
  final int? durationSec;
  final bool locked;
}

/// `GET /v1/me/progress` → the You tab's lifetime block.
class Lifetime {
  const Lifetime({this.sits = 0, this.minutes = 0, this.together = 0, this.togetherPct = 0, this.avgMin = 0, this.hrShiftBpm});
  final int sits, minutes, together, togetherPct;
  final double avgMin;
  final int? hrShiftBpm;
  static Lifetime? from(Object? v) {
    if (v is! Map) return null;
    final j = asJson(v);
    return Lifetime(
        sits: asInt(j['sits']), minutes: asInt(j['minutes']), together: asInt(j['together']), togetherPct: asInt(j['togetherPct']),
        avgMin: ((j['avgMin'] as num?) ?? 0).toDouble(), hrShiftBpm: (j['hrShiftBpm'] as num?)?.toInt());
  }
}

class ScheduleDay {
  const ScheduleDay({required this.day, required this.title, this.minutes, this.summary = '', this.sessionId, required this.state, this.unlocksAt});
  final int day;
  final String title, summary, state; // done | today | locked
  final int? minutes;
  final String? sessionId;
  final DateTime? unlocksAt;
}

class ChallengeDetail {
  const ChallengeDetail({
    required this.id, required this.name, this.blurb, required this.days, this.leadName, this.leadRole, this.badge, this.unlockTime = '07:00', this.graceDays = 1, this.graceLeft = 1,
    this.cohort = 0, this.belts = const Belts(), this.schedule = const [], this.joined = false, this.completedDays = 0, this.pct = 0, this.remaining = 0, this.membersOnly = true,
  });
  final String id, name, unlockTime;
  final String? blurb, leadName, leadRole, badge;
  final int days, graceDays, graceLeft, cohort, completedDays, pct, remaining;
  final Belts belts;
  final List<ScheduleDay> schedule;
  final bool joined, membersOnly;

  ScheduleDay? get today => schedule.where((d) => d.state == 'today').firstOrNull;

  factory ChallengeDetail.fromJson(Json j) {
    final lead = j['lead'] is Map ? asJson(j['lead']) : null;
    final c = asJson(j['cohort']);
    final p = asJson(j['progress']);
    return ChallengeDetail(
      id: j['id'] as String, name: (j['name'] ?? '') as String, blurb: asStr(j['blurb']), days: asInt(j['days'], 7), leadName: asStr(lead?['name']), leadRole: asStr(lead?['specialty']) ?? asStr(lead?['role']),
      badge: asStr(asJson(j['badge'])['name']), unlockTime: (j['unlockTime'] ?? '07:00') as String, graceDays: asInt(j['graceDays'], 1), graceLeft: asInt(j['graceLeft'], 1),
      cohort: asInt(c['active']), belts: Belts.from(c['belts']), joined: j['joined'] == true, membersOnly: j['membersOnly'] != false,
      completedDays: asInt(p['completedDays']), pct: asInt(p['pct']), remaining: asInt(p['remaining']),
      schedule: [
        for (final d in asJsonList(j['schedule']))
          ScheduleDay(
              day: asInt(d['day']), title: (d['title'] ?? '') as String, minutes: (d['minutes'] as num?)?.toInt(), summary: (d['summary'] ?? '') as String, sessionId: asStr(d['sessionId']),
              state: (d['state'] ?? 'locked') as String, unlocksAt: asDate(d['unlocksAt'])),
      ],
    );
  }
}

class PreviewUrl {
  const PreviewUrl({this.url, this.previewSec, this.fullAccess = false, this.enforced, this.fullDurationSec});
  final String? url, enforced;
  final int? previewSec, fullDurationSec;
  final bool fullAccess;
  factory PreviewUrl.fromJson(Json j) => PreviewUrl(
        url: asStr(j['url']), previewSec: (j['previewSec'] as num?)?.toInt(), fullAccess: j['fullAccess'] == true, enforced: asStr(j['enforced']), fullDurationSec: (j['fullDurationSec'] as num?)?.toInt());
}

class SitTimeBlock {
  const SitTimeBlock({required this.time, required this.label});
  final String time, label;
}

/// A dedication in the Together feed: place, teacher badge and the meditation it belongs to.
class FeedItem {
  const FeedItem({required this.dedication, this.place, this.isTeacher = false, this.sessionId, this.sessionTitle});
  final Dedication dedication;
  final String? place, sessionId, sessionTitle;
  final bool isTeacher;
}
