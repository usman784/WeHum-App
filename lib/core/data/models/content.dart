import 'json.dart';

class Cover {
  const Cover({required this.url, this.blurhash});
  final String url;
  final String? blurhash;
  static Cover? from(Object? v) => v is Map ? Cover(url: v['url'] as String, blurhash: v['blurhash'] as String?) : null;
}

enum Access { free, premium }

class SessionSummary {
  const SessionSummary({
    required this.id, required this.slug, required this.title, this.description, required this.type, required this.access,
    this.themeId, this.teacherId, this.tags = const [], this.durationSec, this.cover, this.youtubeId, this.downloadable = false, this.version = 1,
  });
  final String id, slug, title, type;
  final String? description, themeId, teacherId, youtubeId;
  final Access access;
  final List<String> tags;
  final int? durationSec;
  final Cover? cover;
  final bool downloadable;
  final int version;

  bool get isPremium => access == Access.premium;
  bool get isVideo => type == 'video';
  bool get isYoutube => type == 'youtube';
  int get minutes => ((durationSec ?? 0) / 60).round();

  factory SessionSummary.fromJson(Json j) => SessionSummary(
        id: j['id'] as String, slug: (j['slug'] ?? '') as String, title: j['title'] as String, description: asStr(j['description']), type: (j['type'] ?? 'audio') as String,
        access: j['access'] == 'free' ? Access.free : Access.premium, themeId: asStr(j['themeId']), teacherId: asStr(j['teacherId']),
        tags: [for (final t in ((j['tags'] as List?) ?? const [])) '$t'], durationSec: (j['durationSec'] as num?)?.toInt(), cover: Cover.from(j['cover']),
        youtubeId: asStr(j['youtubeId']), downloadable: j['downloadable'] == true, version: asInt(j['version'], 1),
      );

  Json toJson() => {
        'id': id, 'slug': slug, 'title': title, 'description': description, 'type': type, 'access': access.name, 'themeId': themeId, 'teacherId': teacherId,
        'tags': tags, 'durationSec': durationSec, 'cover': cover == null ? null : {'url': cover!.url, 'blurhash': cover!.blurhash}, 'youtubeId': youtubeId,
        'downloadable': downloadable, 'version': version,
      };
}

class ThemeInfo {
  const ThemeInfo({required this.id, required this.slug, required this.name, this.subtitle, this.description, this.iconKey, this.order = 0});
  final String id, slug, name;
  final String? subtitle, description, iconKey;
  final int order;
  factory ThemeInfo.fromJson(Json j) => ThemeInfo(
        id: j['id'] as String, slug: (j['slug'] ?? '') as String, name: j['name'] as String, subtitle: asStr(j['subtitle']), description: asStr(j['description']),
        iconKey: asStr(j['iconKey']), order: asInt(j['order']),
      );
}

class Teacher {
  const Teacher({required this.id, required this.name, this.role, this.specialty, this.bio, this.quote, this.photoUrl, this.youtubeUrl, this.instagramUrl, this.websiteUrl, this.sessions = const []});
  final String id, name;
  final String? role, specialty, bio, quote, photoUrl, youtubeUrl, instagramUrl, websiteUrl;
  final List<SessionSummary> sessions;
  factory Teacher.fromJson(Json j) => Teacher(
        id: j['id'] as String, name: j['name'] as String, role: asStr(j['role']), specialty: asStr(j['specialty']), bio: asStr(j['bio']), quote: asStr(j['quote']),
        photoUrl: asStr(j['photoUrl']), youtubeUrl: asStr(j['youtubeUrl']), instagramUrl: asStr(j['instagramUrl']), websiteUrl: asStr(j['websiteUrl']),
        sessions: asJsonList(j['sessions']).map(SessionSummary.fromJson).toList(),
      );
}

class ProgramDay {
  const ProgramDay({required this.day, this.title, this.sessionId, this.session});
  final int day;
  final String? title, sessionId;
  final SessionSummary? session;
}

class ProgramProgress {
  const ProgramProgress({required this.currentDay, required this.completedDays, this.completedAt});
  final int currentDay;
  final List<int> completedDays;
  final DateTime? completedAt;
}

class Program {
  const Program({required this.id, required this.slug, required this.title, this.description, required this.access, this.unlockRule, this.cover, this.days = const [], this.progress});
  final String id, slug, title;
  final String? description;
  final Access access;
  final Object? unlockRule;
  final Cover? cover;
  final List<ProgramDay> days;
  final ProgramProgress? progress;
  bool get started => progress != null;

  factory Program.fromJson(Json j) => Program(
        id: j['id'] as String, slug: (j['slug'] ?? '') as String, title: j['title'] as String, description: asStr(j['description']),
        access: j['access'] == 'free' ? Access.free : Access.premium, unlockRule: j['unlockRule'], cover: Cover.from(j['cover']),
        days: [
          for (final d in asJsonList(j['days']))
            ProgramDay(
              day: asInt(d['day']), title: asStr(d['title']), sessionId: asStr(d['sessionId']) ?? asStr(asJson(d['session'])['id']),
              session: d['session'] is Map ? SessionSummary.fromJson(asJson(d['session'])) : null,
            ),
        ],
        progress: j['progress'] is Map
            ? ProgramProgress(
                currentDay: asInt(asJson(j['progress'])['currentDay'], 1), completedDays: [for (final x in ((asJson(j['progress'])['completedDays'] as List?) ?? const [])) (x as num).toInt()],
                completedAt: asDate(asJson(j['progress'])['completedAt']))
            : null,
      );
}

class SoundBlock {
  const SoundBlock({required this.id, required this.kind, required this.name, this.durationSec, this.loopable = false, this.access = Access.premium});
  final String id, kind, name;
  final int? durationSec;
  final bool loopable;
  final Access access;
  factory SoundBlock.fromJson(Json j) => SoundBlock(
        id: j['id'] as String, kind: (j['kind'] ?? '') as String, name: j['name'] as String, durationSec: (j['durationSec'] as num?)?.toInt(), loopable: j['loopable'] == true,
        access: j['access'] == 'free' ? Access.free : Access.premium);
}

class SosTile {
  const SosTile({required this.sessionId, required this.feeling, this.subtitle, this.durationSec, this.access = Access.premium, this.cover});
  final String sessionId, feeling;
  final String? subtitle;
  final int? durationSec;
  final Access access;
  final Cover? cover;
}

class SosInfo {
  const SosInfo({this.title = 'How can I help?', this.subtitle, this.help = const {}, this.tiles = const []});
  final String title;
  final String? subtitle;
  /// `{ title, body, ctaLabel, url }` — the "Need more help?" card.
  final Json help;
  final List<SosTile> tiles;
  factory SosInfo.fromJson(Json j) => SosInfo(
        title: asStr(j['title']) ?? 'How can I help?', subtitle: asStr(j['subtitle']), help: asJson(j['help']),
        tiles: [
          for (final t in asJsonList(j['tiles']))
            SosTile(
                sessionId: t['sessionId'] as String, feeling: (t['feeling'] ?? '') as String, subtitle: asStr(t['subtitle']), durationSec: (t['durationSec'] as num?)?.toInt(),
                access: t['access'] == 'free' ? Access.free : Access.premium, cover: Cover.from(t['cover']))
        ],
      );
}

/// `GET /v1/catalog` — the whole library; filtered and searched locally (spec §6.2).
class Catalog {
  const Catalog({required this.version, this.themes = const [], this.teachers = const [], this.sessions = const [], this.programs = const [], this.soundBlocks = const [], this.sos = const SosInfo()});
  final int version;
  final List<ThemeInfo> themes;
  final List<Teacher> teachers;
  final List<SessionSummary> sessions;
  final List<Program> programs;
  final List<SoundBlock> soundBlocks;
  final SosInfo sos;

  SessionSummary? session(String id) => sessions.where((s) => s.id == id).firstOrNull;
  ThemeInfo? theme(String id) => themes.where((t) => t.id == id).firstOrNull;
  Teacher? teacher(String id) => teachers.where((t) => t.id == id).firstOrNull;
  List<SessionSummary> inTheme(String themeId) => sessions.where((s) => s.themeId == themeId).toList();

  factory Catalog.fromJson(Json j) => Catalog(
        version: asInt(j['version']),
        themes: asJsonList(j['themes']).map(ThemeInfo.fromJson).toList(),
        teachers: asJsonList(j['teachers']).map(Teacher.fromJson).toList(),
        sessions: asJsonList(j['sessions']).map(SessionSummary.fromJson).toList(),
        programs: asJsonList(j['programs']).map(Program.fromJson).toList(),
        soundBlocks: asJsonList(j['soundBlocks']).map(SoundBlock.fromJson).toList(),
        sos: SosInfo.fromJson(asJson(j['sos'])),
      );

  /// Stored raw in the local DB (P6) so the library works offline.
  Json toJson() => {'version': version, 'raw': _raw};
  final Json? _raw = null;
}

class Dedication {
  const Dedication({required this.id, required this.firstName, this.country, required this.text, this.holdingCount = 0, this.createdAt, this.heldByMe = false});
  final String id, firstName, text;
  final String? country;
  final int holdingCount;
  final DateTime? createdAt;
  final bool heldByMe;
  Dedication copyWith({int? holdingCount, bool? heldByMe}) =>
      Dedication(id: id, firstName: firstName, country: country, text: text, holdingCount: holdingCount ?? this.holdingCount, createdAt: createdAt, heldByMe: heldByMe ?? this.heldByMe);
  factory Dedication.fromJson(Json j) => Dedication(
        id: j['id'] as String, firstName: (j['firstName'] ?? '') as String, country: asStr(j['country']), text: (j['text'] ?? '') as String,
        holdingCount: asInt(j['holdingCount']), createdAt: asDate(j['createdAt']), heldByMe: j['holding'] == true);
}

class SessionDetail {
  const SessionDetail({required this.summary, this.theme, this.teacher, this.practicedToday = 0, this.dedications = const []});
  final SessionSummary summary;
  final ThemeInfo? theme;
  final Teacher? teacher;
  final int practicedToday;
  final List<Dedication> dedications;
  factory SessionDetail.fromJson(Json j) => SessionDetail(
        summary: SessionSummary.fromJson(j),
        theme: j['theme'] is Map ? ThemeInfo.fromJson({'slug': '', ...asJson(j['theme'])}) : null,
        teacher: j['teacher'] is Map ? Teacher.fromJson(asJson(j['teacher'])) : null,
        practicedToday: asInt(j['practicedToday']),
        dedications: asJsonList(asJson(j['dedications'])['preview']).map(Dedication.fromJson).toList(),
      );
}
