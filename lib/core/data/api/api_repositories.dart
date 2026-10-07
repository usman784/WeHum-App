import '../../realtime/socket_events.dart';
import '../contracts/repositories.dart';
import '../models/activity.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../models/soon.dart';
import '../models/today.dart';
import 'api_base.dart';

class TodayApi extends ApiBase implements TodayRepository {
  TodayApi(super.api);
  @override
  Future<TodayData> today(String date) async => TodayData.fromJson(await getJson('/v1/today', query: {'date': date}, etag: true));
  @override
  Future<MotdInfo> motd(String date) async => MotdInfo.fromJson(await getJson('/v1/motd/$date'));
  @override
  Future<GroupInfo> groupNext() async => GroupInfo.fromJson(await getJson('/v1/group/next'));
  @override
  Future<DailyMessage> dailyMessage(String date) async => DailyMessage.fromJson(await getJson('/v1/daily-messages/$date'));
  @override
  Future<Page<DailyMessage>> archive({String? q, String? theme, String? cursor}) async {
    final (rows, next) = await getPage('/v1/daily-messages', query: {if (q != null && q.isNotEmpty) 'q': q, if (theme != null) 'theme': theme, if (cursor != null) 'cursor': cursor});
    return Page(rows.map(DailyMessage.fromJson).toList(), next);
  }

  @override
  Future<LiveAgg?> live() async {
    final j = await getJson('/v1/live');
    return j.isEmpty ? null : LiveAgg.fromJson({'top': const [], ...j});
  }

  @override
  Future<void> setGroupReminder(bool on) async {
    await call(on ? 'PUT' : 'DELETE', '/v1/group/remind');
  }
}

class CatalogApi extends ApiBase implements CatalogRepository {
  CatalogApi(super.api);
  @override
  Future<Catalog?> catalog({int? knownVersion}) async {
    final j = await getJson('/v1/catalog', query: {if (knownVersion != null) 'version': knownVersion}, etag: true);
    if (j.isEmpty) return null; // 304 / nothing newer
    final c = Catalog.fromJson(j);
    return (knownVersion != null && c.version == knownVersion) ? null : c;
  }

  @override
  Future<SessionDetail> session(String id) async => SessionDetail.fromJson(await getJson('/v1/sessions/$id'));
  @override
  Future<Program> program(String id) async => Program.fromJson(await getJson('/v1/programs/$id'));
  @override
  Future<Teacher> teacher(String id) async => Teacher.fromJson(await getJson('/v1/teachers/$id'));
  @override
  Future<SosInfo> sos() async => SosInfo.fromJson(await getJson('/v1/sos', etag: true));
  @override
  Future<List<SessionSummary>> search({required String q, String? themeId, String? type}) async {
    final (rows, _) = await getPage('/v1/search', query: {'q': q, if (themeId != null) 'themeId': themeId, if (type != null) 'type': type});
    return rows.map(SessionSummary.fromJson).toList();
  }
}

class MediaApi extends ApiBase implements MediaRepository {
  MediaApi(super.api);
  @override
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false}) async => PlayUrl.fromJson(await call('POST', '/v1/media/play-url', body: target.toBody(download: download)));
}

class MeditationApi extends ApiBase implements MeditationRepository {
  MeditationApi(super.api);
  @override
  Future<MeditationResult> record(MeditationRecord m) async => MeditationResult.fromJson(await call('POST', '/v1/meditations', body: m.toJson()));
  @override
  Future<List<MeditationResult>> batch(List<MeditationRecord> items) async {
    final j = await call('POST', '/v1/meditations/batch', body: {'items': [for (final i in items) i.toJson()]});
    return asJsonList(j['results']).map(MeditationResult.fromJson).toList();
  }

  @override
  Future<Page<Json>> history({String? cursor}) async {
    final (rows, next) = await getPage('/v1/meditations', query: {if (cursor != null) 'cursor': cursor});
    return Page(rows, next);
  }
}

class MeApi extends ApiBase implements MeRepository {
  MeApi(super.api);
  @override
  Future<MeProfile> me() async => MeProfile.fromJson(await getJson('/v1/me'));
  @override
  Future<MeProfile> patch(Json changes) async => MeProfile.fromJson(await call('PATCH', '/v1/me', body: changes));
  @override
  Future<String> registerDevice(DeviceRegistration d) async {
    final j = await call('POST', '/v1/me/devices', body: {
      'installId': d.installId, 'platform': d.platform, 'appVersion': d.appVersion, if (d.pushToken != null) 'pushToken': d.pushToken,
      if (d.osVersion != null) 'osVersion': d.osVersion, if (d.model != null) 'model': d.model,
    });
    return j['id'] as String;
  }

  @override
  Future<void> unregisterDevice(String deviceId) async {
    await call('DELETE', '/v1/me/devices/$deviceId');
  }

  @override
  Future<ProgressData> progress(Period p) async => ProgressData.fromJson(await getJson('/v1/me/progress', query: {'period': p.name}));
  @override
  Future<Page<InboxItem>> inbox({String? cursor}) async {
    final (rows, next) = await getPage('/v1/me/inbox', query: {if (cursor != null) 'cursor': cursor});
    return Page(rows.map(InboxItem.fromJson).toList(), next);
  }

  @override
  Future<void> markRead({List<String>? ids, bool all = false}) async {
    await call('POST', '/v1/me/inbox/read', body: all ? {'all': true} : {'ids': ids});
  }

  @override
  Future<void> syncEntitlement() async {
    await call('POST', '/v1/me/entitlement/sync');
  }

  @override
  Future<String> startExport() async => (await call('POST', '/v1/me/export'))['jobId'] as String;
  @override
  Future<({String status, String? jsonUrl, String? csvUrl})> exportStatus(String jobId) async {
    final j = await getJson('/v1/me/export/$jobId');
    final r = asJson(j['result']);
    return (status: j['status'] as String, jsonUrl: asStr(r['json']), csvUrl: asStr(r['csv']));
  }

  @override
  Future<void> deleteAccount() async {
    await call('DELETE', '/v1/me', body: {'confirm': 'DELETE'});
  }
}

class CommunityApi extends ApiBase implements CommunityRepository {
  CommunityApi(super.api);
  @override
  Future<Page<Dedication>> dedications(String sessionId, {String? cursor}) async {
    final (rows, next) = await getPage('/v1/sessions/$sessionId/dedications', query: {if (cursor != null) 'cursor': cursor});
    return Page(rows.map(Dedication.fromJson).toList(), next);
  }

  @override
  Future<PostResult> post({required String meditationId, required String text}) async {
    final j = await call('POST', '/v1/dedications', body: {'meditationId': meditationId, 'text': text});
    return PostResult(id: j['id'] as String, status: (j['status'] ?? 'visible') as String, showHelp: j['showHelp'] == true, leftToday: asInt(j['dedicationsLeftToday']));
  }

  @override
  Future<int> hold(String id, bool on) async => asInt((await call(on ? 'PUT' : 'DELETE', '/v1/dedications/$id/hold'))['holdingCount']);
  @override
  Future<void> report(String id, {required String reason, bool block = false}) async {
    await call('POST', '/v1/dedications/$id/report', body: {'reason': reason, if (block) 'block': true});
  }
}

class RecipeApi extends ApiBase implements RecipeRepository {
  RecipeApi(super.api);
  @override
  Future<List<Recipe>> list() async {
    final r = await api.dio.get('/v1/recipes');
    final d = (r.data as Map)['data'];
    return asJsonList(d is Map ? d['items'] ?? d['recipes'] : d).map(Recipe.fromJson).toList();
  }

  @override
  Future<Recipe> create(Recipe r) async => Recipe.fromJson(await call('POST', '/v1/recipes', body: r.toJson()));
  @override
  Future<Recipe> update(String id, Json changes) async => Recipe.fromJson(await call('PATCH', '/v1/recipes/$id', body: changes));
  @override
  Future<void> delete(String id) async {
    await call('DELETE', '/v1/recipes/$id');
  }

  @override
  Future<String> share(String id) async => (await call('POST', '/v1/recipes/$id/share'))['shareUrl'] as String;
  @override
  Future<Recipe> shared(String slug) async => Recipe.fromJson(await getJson('/v1/recipes/shared/$slug'));
}

class ProgramApi extends ApiBase implements ProgramRepository {
  ProgramApi(super.api);
  @override
  Future<Program> start(String id) async {
    await call('POST', '/v1/programs/$id/start');
    return Program.fromJson(await getJson('/v1/programs/$id'));
  }

  @override
  Future<Program> completeDay(String id, int day) async {
    await call('POST', '/v1/programs/$id/days/$day/complete');
    return Program.fromJson(await getJson('/v1/programs/$id'));
  }
}

class AnalyticsApi extends ApiBase implements AnalyticsRepository {
  AnalyticsApi(super.api);
  @override
  Future<void> send(List<Json> events) async {
    await call('POST', '/v1/analytics/events', body: {'events': events});
  }
}

class ComingSoonApi extends ApiBase implements ComingSoonRepository {
  ComingSoonApi(super.api);
  @override
  Future<ChallengesData> challenges() async => ChallengesData.fromJson(await getJson('/v1/challenges'));
  @override
  Future<void> joinChallenge(String id) async {
    await call('POST', '/v1/challenges/$id/join');
  }

  @override
  Future<void> leaveChallenge(String id) async {
    await call('DELETE', '/v1/challenges/$id/join');
  }

  @override
  Future<Page<GratitudePost>> gratitude(String kind, {String? cursor}) async {
    final (rows, next) = await getPage('/v1/gratitude', query: {'kind': kind, if (cursor != null) 'cursor': cursor});
    return Page(rows.map(GratitudePost.fromJson).toList(), next);
  }

  @override
  Future<PostResult> shareGratitude(String kind, String text) async {
    final j = await call('POST', '/v1/gratitude', body: {'kind': kind, 'text': text});
    return PostResult(id: j['id'] as String, status: (j['status'] ?? 'visible') as String, showHelp: j['showHelp'] == true, leftToday: asInt(j['postsLeftToday']));
  }

  @override
  Future<void> reportGratitude(String id, {required String reason, bool block = false}) async {
    await call('POST', '/v1/gratitude/$id/report', body: {'reason': reason, if (block) 'block': true});
  }

  @override
  Future<BreathworkData> breathwork() async => BreathworkData.fromJson(await getJson('/v1/breathwork'));
  @override
  Future<List<BreathPattern>> myPatterns() async {
    final r = await api.dio.get('/v1/me/breath-patterns');
    return asJsonList((r.data as Map)['data']).map(BreathPattern.fromJson).toList();
  }

  @override
  Future<BreathPattern> savePattern(BreathPattern p) async => BreathPattern.fromJson(await call('POST', '/v1/me/breath-patterns', body: p.toJson()));
  @override
  Future<void> deletePattern(String id) async {
    await call('DELETE', '/v1/me/breath-patterns/$id');
  }

  @override
  Future<MilestonesData> milestones() async => MilestonesData.fromJson(await getJson('/v1/me/milestones'));
}
