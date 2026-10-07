import 'content.dart';
import 'json.dart';

class MotdInfo {
  const MotdInfo({required this.date, required this.sessionId, required this.title, this.teacher, this.theme, this.cover, this.lengths = const [], this.practicedToday = 0, this.fallback = false});
  final String date, sessionId, title;
  final String? teacher, theme;
  final Cover? cover;
  final List<int> lengths;
  final int practicedToday;
  /// No MOTD for the date: the server picked the most played meditation.
  final bool fallback;
  factory MotdInfo.fromJson(Json j) => MotdInfo(
        date: j['date'] as String, sessionId: j['sessionId'] as String, title: j['title'] as String, teacher: asStr(j['teacher']), theme: asStr(j['theme']), cover: Cover.from(j['cover']),
        lengths: [for (final l in ((j['lengths'] as List?) ?? const [])) (l as num).toInt()], practicedToday: asInt(j['practicedToday']), fallback: j['fallback'] == true);
}

enum GroupPhase { scheduled, lobby, live, ended }

class GroupInfo {
  const GroupInfo({required this.date, required this.startsAt, required this.endsAt, required this.lobbyOpensAt, required this.lengthMin, this.reminderMin = 10, required this.state, this.waiting = 0, this.sessionId, this.title});
  final String date;
  final DateTime startsAt, endsAt, lobbyOpensAt;
  final int lengthMin, reminderMin, waiting;
  final GroupPhase state;
  final String? sessionId, title;
  factory GroupInfo.fromJson(Json j) => GroupInfo(
        date: j['date'] as String, startsAt: DateTime.parse(j['startsAt'] as String).toUtc(), endsAt: DateTime.parse(j['endsAt'] as String).toUtc(),
        lobbyOpensAt: DateTime.parse(j['lobbyOpensAt'] as String).toUtc(), lengthMin: asInt(j['lengthMin']), reminderMin: asInt(j['reminderMin'], 10),
        state: GroupPhase.values.firstWhere((p) => p.name == j['state'], orElse: () => GroupPhase.scheduled), waiting: asInt(j['waiting']), sessionId: asStr(j['sessionId']), title: asStr(j['title']));
}

class FreePick {
  const FreePick({required this.sessionId, required this.title, this.youtubeId, this.durationSec});
  final String sessionId, title;
  final String? youtubeId;
  final int? durationSec;
}

class ProgramCard {
  const ProgramCard({required this.id, required this.title, required this.day, required this.days, this.unlockAt});
  final String id, title;
  final int day, days;
  final DateTime? unlockAt;
}

class WeekProgress {
  const WeekProgress({this.minutes = 0, this.meditations = 0, this.daysThisWeek = const []});
  final int minutes, meditations;
  final List<dynamic> daysThisWeek;
}

class LiveLine {
  const LiveLine({required this.total, required this.countries, required this.quiet, required this.meditatedToday});
  final int total, countries, meditatedToday;
  final bool quiet;
}

class DailyMessageRef {
  const DailyMessageRef({required this.date, required this.title, required this.type});
  final String date, title, type;
}

/// `GET /v1/today`.
class TodayData {
  const TodayData({required this.date, this.motd, this.live, this.group, this.freePick, this.program, this.progress = const WeekProgress(), this.dailyMessage});
  final String date;
  final MotdInfo? motd;
  final LiveLine? live;
  final GroupInfo? group;
  final FreePick? freePick;
  final ProgramCard? program;
  final WeekProgress progress;
  final DailyMessageRef? dailyMessage;

  factory TodayData.fromJson(Json j) {
    final l = j['live'] is Map ? asJson(j['live']) : null;
    final p = j['program'] is Map ? asJson(j['program']) : null;
    final f = j['freePick'] is Map ? asJson(j['freePick']) : null;
    final w = asJson(j['progress']);
    final d = j['dailyMessage'] is Map ? asJson(j['dailyMessage']) : null;
    return TodayData(
      date: j['date'] as String,
      motd: j['motd'] is Map ? MotdInfo.fromJson(asJson(j['motd'])) : null,
      live: l == null ? null : LiveLine(total: asInt(l['total']), countries: asInt(l['countries']), quiet: l['quiet'] == true, meditatedToday: asInt(l['meditatedToday'])),
      group: j['group'] is Map ? GroupInfo.fromJson(asJson(j['group'])) : null,
      freePick: f == null ? null : FreePick(sessionId: f['sessionId'] as String, title: f['title'] as String, youtubeId: asStr(f['youtubeId']), durationSec: (f['durationSec'] as num?)?.toInt()),
      program: p == null ? null : ProgramCard(id: p['id'] as String, title: p['title'] as String, day: asInt(p['day'], 1), days: asInt(p['days'], 1), unlockAt: asDate(p['unlockAt'])),
      progress: WeekProgress(minutes: asInt(w['minutesWeek']), meditations: asInt(w['meditationsWeek']), daysThisWeek: (w['daysThisWeek'] as List?) ?? const []),
      dailyMessage: d == null ? null : DailyMessageRef(date: d['date'] as String, title: (d['title'] ?? '') as String, type: (d['type'] ?? 'text') as String),
    );
  }
}
