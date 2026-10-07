import 'json.dart';

class PlayUrl {
  const PlayUrl({required this.type, this.url, this.hlsUrl, this.youtubeId, this.mime, this.durationSec, this.expiresAt});
  final String type; // audio | video | youtube
  final String? url, hlsUrl, youtubeId, mime;
  final int? durationSec;
  final DateTime? expiresAt;
  bool get expired => expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt!.subtract(const Duration(minutes: 2)));
  factory PlayUrl.fromJson(Json j) => PlayUrl(
        type: (j['type'] ?? 'audio') as String, url: asStr(j['url']), hlsUrl: asStr(j['hlsUrl']), youtubeId: asStr(j['youtubeId']), mime: asStr(j['mime']),
        durationSec: (j['durationSec'] as num?)?.toInt(), expiresAt: asDate(j['expiresAt']));
}

/// What to play. `kind` maps to the backend `play-url` body.
sealed class PlayTarget {
  const PlayTarget();
  Json toBody({bool download = false});
}

class PlaySession extends PlayTarget {
  const PlaySession(this.id);
  final String id;
  @override
  Json toBody({bool download = false}) => {'kind': 'session', 'id': id, if (download) 'download': true};
}

class PlayMotd extends PlayTarget {
  const PlayMotd(this.date, this.lengthMin);
  final String date;
  final int lengthMin;
  @override
  Json toBody({bool download = false}) => {'kind': 'motd', 'date': date, 'lengthMin': lengthMin, if (download) 'download': true};
}

class PlayBlock extends PlayTarget {
  const PlayBlock(this.id);
  final String id;
  @override
  Json toBody({bool download = false}) => {'kind': 'block', 'id': id, if (download) 'download': true};
}

class PlayDailyMessage extends PlayTarget {
  const PlayDailyMessage(this.date);
  final String date;
  @override
  Json toBody({bool download = false}) => {'kind': 'daily_message', 'date': date, if (download) 'download': true};
}

/// One finished meditation, written to the local outbox first (spec §6.2).
class MeditationRecord {
  const MeditationRecord({
    required this.id, this.sessionId, this.recipeId, required this.kind, this.lengthVariant, required this.startedAt, required this.endedAt,
    required this.durationSec, this.completed = false, this.offline = false,
  });
  final String id, kind;
  final String? sessionId, recipeId;
  final int? lengthVariant;
  final DateTime startedAt, endedAt;
  final int durationSec;
  final bool completed, offline;

  Json toJson() => {
        'id': id, if (sessionId != null) 'sessionId': sessionId, if (recipeId != null) 'recipeId': recipeId, 'kind': kind,
        if (lengthVariant != null) 'lengthVariant': lengthVariant, 'startedAt': startedAt.toUtc().toIso8601String(), 'endedAt': endedAt.toUtc().toIso8601String(),
        'durationSec': durationSec, 'completed': completed, 'offline': offline,
      };
  factory MeditationRecord.fromJson(Json j) => MeditationRecord(
        id: j['id'] as String, sessionId: asStr(j['sessionId']), recipeId: asStr(j['recipeId']), kind: j['kind'] as String, lengthVariant: (j['lengthVariant'] as num?)?.toInt(),
        startedAt: DateTime.parse(j['startedAt'] as String), endedAt: DateTime.parse(j['endedAt'] as String), durationSec: asInt(j['durationSec']),
        completed: j['completed'] == true, offline: j['offline'] == true);
}

class MeditationResult {
  const MeditationResult({required this.id, this.counted = false, this.canDedicate = false, this.dedicationsLeftToday = 0, this.togetherPeople = 0, this.togetherCountries = 0, this.status = 'created'});
  final String id, status;
  final bool counted, canDedicate;
  final int dedicationsLeftToday, togetherPeople, togetherCountries;
  factory MeditationResult.fromJson(Json j) {
    final t = asJson(j['together']);
    return MeditationResult(
        id: j['id'] as String, status: (j['status'] ?? 'created') as String, counted: j['counted'] == true, canDedicate: j['canDedicate'] == true,
        dedicationsLeftToday: asInt(j['dedicationsLeftToday']), togetherPeople: asInt(t['people']), togetherCountries: asInt(t['countries']));
  }
}

enum Period { week, month, year, all }

class ProgressBar {
  const ProgressBar({required this.label, required this.minutes, required this.current});
  final String label;
  final int minutes;
  final bool current;
}

class ProgressData {
  const ProgressData({required this.period, this.minutes = 0, this.meditations = 0, this.together = 0, this.average = 0, this.daysMeditated = 0, this.daysThisWeek = const [], this.bars = const []});
  final Period period;
  final int minutes, meditations, together, average, daysMeditated;
  final List<bool> daysThisWeek;
  final List<ProgressBar> bars;
  factory ProgressData.fromJson(Json j) => ProgressData(
        period: Period.values.firstWhere((p) => p.name == j['period'], orElse: () => Period.week), minutes: asInt(j['minutes']), meditations: asInt(j['meditations']),
        together: asInt(j['together']), average: asInt(j['average']), daysMeditated: asInt(j['daysMeditated']),
        daysThisWeek: [for (final d in ((j['daysThisWeek'] as List?) ?? const [])) d == true || (d is num && d > 0)],
        bars: [for (final b in asJsonList(j['bars'])) ProgressBar(label: (b['label'] ?? '') as String, minutes: asInt(b['minutes']), current: b['current'] == true)]);
}

class Recipe {
  const Recipe({
    required this.id, required this.name, required this.lengthMin, this.openingId, this.soundId, this.soundLevel = 50, this.texture = 'simple',
    this.bells = const RecipeBells(), this.blocks = const [], this.shareUrl, this.shareSlug,
  });
  final String id, name, texture;
  final int lengthMin, soundLevel;
  final String? openingId, soundId, shareUrl, shareSlug;
  final RecipeBells bells;
  final List<Json> blocks;

  Json toJson() => {
        'name': name, 'lengthMin': lengthMin, 'openingId': openingId, 'soundId': soundId, 'soundLevel': soundLevel, 'texture': texture,
        'bells': {'start': bells.start, 'end': bells.end, 'intervalMin': bells.intervalMin}, 'blocks': blocks,
      };
  factory Recipe.fromJson(Json j) {
    final b = asJson(j['bells']);
    return Recipe(
        id: j['id'] as String, name: j['name'] as String, lengthMin: asInt(j['lengthMin'], 10), openingId: asStr(j['openingId']), soundId: asStr(j['soundId']),
        soundLevel: asInt(j['soundLevel'], 50), texture: (j['texture'] ?? 'simple') as String,
        bells: RecipeBells(start: b['start'] != false, end: b['end'] != false, intervalMin: asInt(b['intervalMin'])), blocks: asJsonList(j['blocks']),
        shareUrl: asStr(j['shareUrl']), shareSlug: asStr(j['shareSlug']));
  }
}

class RecipeBells {
  const RecipeBells({this.start = true, this.end = true, this.intervalMin = 0});
  final bool start, end;
  final int intervalMin;
}

class InboxItem {
  const InboxItem({required this.id, required this.type, required this.title, this.body, this.deepLink, required this.createdAt, this.read = false});
  final String id, type, title;
  final String? body, deepLink;
  final DateTime createdAt;
  final bool read;
  InboxItem asRead() => InboxItem(id: id, type: type, title: title, body: body, deepLink: deepLink, createdAt: createdAt, read: true);
  factory InboxItem.fromJson(Json j) => InboxItem(
        id: j['id'] as String, type: (j['type'] ?? '') as String, title: (j['title'] ?? '') as String, body: asStr(j['body']), deepLink: asStr(j['deepLink']),
        createdAt: asDate(j['createdAt']) ?? DateTime.now().toUtc(), read: j['read'] == true || j['readAt'] != null);
}

class DailyMessage {
  const DailyMessage({required this.date, required this.type, required this.title, this.text, this.durationSec, this.themeTag, this.imageUrl, this.hasMedia = false});
  final String date, type, title;
  final String? text, themeTag, imageUrl;
  final int? durationSec;
  final bool hasMedia;
  factory DailyMessage.fromJson(Json j) => DailyMessage(
        date: j['date'] as String, type: (j['type'] ?? 'text') as String, title: (j['title'] ?? '') as String, text: asStr(j['text']), durationSec: (j['durationSec'] as num?)?.toInt(),
        themeTag: asStr(j['themeTag']), imageUrl: asStr(asJson(j['image'])['url']), hasMedia: j['hasMedia'] == true);
}

class Page<T> {
  const Page(this.items, this.nextCursor);
  final List<T> items;
  final String? nextCursor;
}

/// Entitlement as the server sees it (`me.entitlement`).
class Entitlement {
  const Entitlement({this.active = false, this.productId, this.periodType, this.expiresAt, this.willRenew = false, this.billingIssue = false, this.isFounding = false});
  final bool active, willRenew, billingIssue, isFounding;
  final String? productId, periodType;
  final DateTime? expiresAt;
  bool get isTrial => periodType == 'trial';
  factory Entitlement.fromJson(Json j) => Entitlement(
        active: j['active'] == true, productId: asStr(j['productId']), periodType: asStr(j['periodType']), expiresAt: asDate(j['expiresAt']), willRenew: j['willRenew'] == true,
        billingIssue: j['billingIssue'] == true, isFounding: j['isFounding'] == true);
}

class MeProfile {
  const MeProfile({
    required this.id, this.firstName, this.email, this.isGuest = true, this.providers = const [], this.country, this.timezone, this.theme = 'system',
    this.reminderEnabled = true, this.reminderTime = '07:00', this.groupWarning = false, this.dailyMessagePush = true, this.showCountry = true, this.entitlement = const Entitlement(),
  });
  final String id;
  final String? firstName, email, country, timezone;
  final bool isGuest, reminderEnabled, groupWarning, dailyMessagePush, showCountry;
  final List<String> providers;
  final String theme, reminderTime;
  final Entitlement entitlement;
  String get initials => (firstName ?? '').trim().isEmpty ? '' : firstName!.trim().substring(0, 1).toUpperCase();
  factory MeProfile.fromJson(Json j) {
    final r = asJson(j['reminder']);
    return MeProfile(
        id: j['id'] as String, firstName: asStr(j['firstName']), email: asStr(j['email']), isGuest: j['isGuest'] != false,
        providers: [for (final p in ((j['providers'] as List?) ?? const [])) '$p'], country: asStr(j['country']), timezone: asStr(j['timezone']), theme: (j['theme'] ?? 'system') as String,
        reminderEnabled: r['enabled'] != false, reminderTime: (r['time'] ?? '07:00') as String, groupWarning: j['groupWarning'] == true, dailyMessagePush: j['dailyMessagePush'] != false,
        showCountry: j['showCountry'] != false, entitlement: Entitlement.fromJson(asJson(j['entitlement'])));
  }
}
