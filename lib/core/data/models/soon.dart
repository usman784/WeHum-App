import 'content.dart';
import 'json.dart';

class ChallengeMe {
  const ChallengeMe({required this.completedDays, this.lastDay, this.finishedAt, this.joinedAt});
  final int completedDays;
  final String? lastDay;
  final DateTime? finishedAt, joinedAt;
}

class Challenge {
  const Challenge({required this.id, required this.name, required this.days, this.counts = 'any', this.minMinutes = 0, this.membersOnly = true, this.cover, this.peopleInIt = 0, this.me});
  final String id, name, counts;
  final int days, minMinutes, peopleInIt;
  final bool membersOnly;
  final Cover? cover;
  final ChallengeMe? me;
  factory Challenge.fromJson(Json j) {
    final m = j['me'] is Map ? asJson(j['me']) : null;
    return Challenge(
        id: j['id'] as String, name: j['name'] as String, days: asInt(j['days'], 7), counts: (j['counts'] ?? 'any') as String, minMinutes: asInt(j['minMinutes']), membersOnly: j['membersOnly'] != false,
        cover: Cover.from(j['cover']), peopleInIt: asInt(j['peopleInIt']),
        me: m == null ? null : ChallengeMe(completedDays: asInt(m['completedDays']), lastDay: asStr(m['lastDay']), finishedAt: asDate(m['finishedAt']), joinedAt: asDate(m['joinedAt'])));
  }
}

class ChallengesData {
  const ChallengesData({this.inProgress = const [], this.available = const [], this.finished = const []});
  final List<Challenge> inProgress, available;
  final List<({String id, String name, int days, DateTime? finishedAt})> finished;
  factory ChallengesData.fromJson(Json j) => ChallengesData(
        inProgress: asJsonList(j['inProgress']).map(Challenge.fromJson).toList(), available: asJsonList(j['available']).map(Challenge.fromJson).toList(),
        finished: [for (final f in asJsonList(j['finished'])) (id: f['id'] as String, name: f['name'] as String, days: asInt(f['days']), finishedAt: asDate(f['finishedAt']))]);
}

class GratitudePost {
  const GratitudePost({required this.id, required this.kind, required this.firstName, this.country, required this.text, this.createdAt});
  final String id, kind, firstName, text;
  final String? country;
  final DateTime? createdAt;
  factory GratitudePost.fromJson(Json j) => GratitudePost(
      id: j['id'] as String, kind: (j['kind'] ?? 'gratitude') as String, firstName: (j['firstName'] ?? '') as String, country: asStr(j['country']), text: (j['text'] ?? '') as String, createdAt: asDate(j['createdAt']));
}

class BreathPattern {
  const BreathPattern({this.id, required this.name, this.subtitle, required this.inhaleSec, this.hold1Sec = 0, required this.exhaleSec, this.hold2Sec = 0, this.rounds = 10});
  final String? id, subtitle;
  final String name;
  final int inhaleSec, hold1Sec, exhaleSec, hold2Sec, rounds;
  int get roundSec => inhaleSec + hold1Sec + exhaleSec + hold2Sec;
  int get totalSec => roundSec * rounds;
  /// "4-4-4-4"
  String get beats => [inhaleSec, hold1Sec, exhaleSec, hold2Sec].join('-');
  factory BreathPattern.fromJson(Json j) => BreathPattern(
      id: asStr(j['id']), name: (j['name'] ?? '') as String, subtitle: asStr(j['subtitle']), inhaleSec: asInt(j['inhaleSec'], 4), hold1Sec: asInt(j['hold1Sec']), exhaleSec: asInt(j['exhaleSec'], 4), hold2Sec: asInt(j['hold2Sec']), rounds: asInt(j['rounds'], 10));
  Json toJson() => {'name': name, 'inhaleSec': inhaleSec, 'hold1Sec': hold1Sec, 'exhaleSec': exhaleSec, 'hold2Sec': hold2Sec, 'rounds': rounds};
}

class BreathworkData {
  const BreathworkData({this.templates = const [], this.lessons = const []});
  final List<BreathPattern> templates;
  final List<({int lesson, SessionSummary session})> lessons;
  factory BreathworkData.fromJson(Json j) => BreathworkData(
        templates: asJsonList(j['templates']).map(BreathPattern.fromJson).toList(),
        lessons: [for (final l in asJsonList(j['lessons'])) (lesson: asInt(l['lesson']), session: SessionSummary.fromJson(asJson(l['session'])))]);
}

class Award {
  const Award({required this.key, required this.label, required this.badge, required this.target, required this.value, required this.reached, this.reachedAt});
  final String key, label, badge;
  final int target, value;
  final bool reached;
  final DateTime? reachedAt;
}

class MilestonesData {
  const MilestonesData({this.reached = 0, this.total = 0, this.awards = const [], this.world = const {}});
  final int reached, total;
  final List<Award> awards;
  final Map<String, int> world; // minutes, meditations, countries, dedications
  factory MilestonesData.fromJson(Json j) => MilestonesData(
        reached: asInt(j['reached']), total: asInt(j['total']),
        awards: [for (final a in asJsonList(j['awards'])) Award(key: a['key'] as String, label: (a['label'] ?? '') as String, badge: (a['badge'] ?? '') as String, target: asInt(a['target']), value: asInt(a['value']), reached: a['reached'] == true, reachedAt: asDate(a['reachedAt']))],
        world: {for (final e in asJson(j['world']).entries) e.key: asInt(e.value)});
}
