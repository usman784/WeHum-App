import '../../realtime/socket_events.dart';
import '../contracts/auth_repository.dart';
import '../contracts/bootstrap_repository.dart';
import '../contracts/repositories.dart';
import '../models/activity.dart';
import '../models/bootstrap.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../models/session.dart';
import '../models/today.dart';
import 'mock_data.dart';

/// Mocks return the payloads from backend spec §5.4 (spec §0 rule 6). Used with USE_MOCKS=true and in widget tests.
class MockAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> guest(DeviceInfoDto d) async => const AuthSession(
        accessToken: 'mock-access', refreshToken: 'mock-refresh-token-0000000000', me: Me(id: 'mock-user', isGuest: true));

  @override
  Future<AuthSession> social(String provider, String firebaseIdToken, {String? firstName}) async => AuthSession(
        accessToken: 'mock-access', refreshToken: 'mock-refresh-token-0000000000', me: Me(id: 'mock-user', isGuest: false, firstName: firstName));

  @override
  Future<void> logout() async {}
}

class MockBootstrapRepository implements BootstrapRepository {
  MockBootstrapRepository({this.member = false});
  final bool member;
  @override
  Future<Bootstrap> bootstrap() async => Bootstrap.fromJson({
        'serverTime': DateTime.now().toUtc().millisecondsSinceEpoch,
        'updateRequired': false,
        'maintenance': false,
        'features': {'intent': false, 'challenges': false, 'gratitude': false, 'breathwork': false, 'milestones': false},
        'catalogVersion': 1,
        'founding': {'left': 588, 'cap': 1000, 'open': true},
        'me': {'id': 'mock-user', 'isGuest': true, 'theme': 'system'},
        'entitlement': {'active': member},
      });
}

class MockTodayRepository implements TodayRepository {
  MockTodayRepository({this.member = true});
  bool member;
  bool groupReminder = false;
  @override
  Future<TodayData> today(String date) async => MockData.today(date, member: member);
  @override
  Future<MotdInfo> motd(String date) async => MockData.motd(date);
  @override
  Future<GroupInfo> groupNext() async => MockData.group(DateTime.now().toIso8601String().substring(0, 10));
  @override
  Future<DailyMessage> dailyMessage(String date) async => DailyMessage(date: date, type: 'text', title: 'Releasing Cognitive Friction', text: 'You do not have to solve your mind. Let it settle.', themeTag: 'Focus');
  @override
  Future<Page<DailyMessage>> archive({String? q, String? theme, String? cursor}) async =>
      Page([for (var i = 0; i < 6; i++) DailyMessage(date: '2026-10-0${i + 1}', type: i.isEven ? 'text' : 'audio', title: 'Message ${i + 1}', text: 'Text ${i + 1}')], null);
  @override
  Future<LiveAgg?> live() async => LiveAgg.fromJson({'total': 412, 'countries': 37, 'quiet': false, 'meditatedToday': 1280, 'vibration': 62, 'at': 0, 'top': []});
  @override
  Future<void> setGroupReminder(bool on) async => groupReminder = on;
}

class MockCatalogRepository implements CatalogRepository {
  @override
  Future<Catalog?> catalog({int? knownVersion}) async => knownVersion == MockData.catalog.version ? null : MockData.catalog;
  @override
  Future<SessionDetail> session(String id) async => SessionDetail(
      summary: MockData.sessions.firstWhere((s) => s.id == id, orElse: () => MockData.sessions.first), teacher: MockData.raphael, theme: MockData.themes.first,
      practicedToday: 1280, dedications: MockData.dedications);
  @override
  Future<Program> program(String id) async => MockData.catalog.programs.first;
  @override
  Future<Teacher> teacher(String id) async => Teacher(id: MockData.raphael.id, name: MockData.raphael.name, bio: MockData.raphael.bio, photoUrl: MockData.raphael.photoUrl, sessions: MockData.sessions);
  @override
  Future<SosInfo> sos() async => MockData.catalog.sos;
  @override
  Future<List<SessionSummary>> search({required String q, String? themeId, String? type}) async =>
      MockData.sessions.where((s) => s.title.toLowerCase().contains(q.toLowerCase())).toList();
}

class MockMediaRepository implements MediaRepository {
  @override
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false}) async =>
      PlayUrl(type: 'audio', url: 'https://example.com/mock.mp3', durationSec: 600, expiresAt: DateTime.now().toUtc().add(const Duration(hours: 6)));
}

class MockMeditationRepository implements MeditationRepository {
  final recorded = <MeditationRecord>[];
  @override
  Future<MeditationResult> record(MeditationRecord m) async {
    recorded.add(m);
    return MeditationResult(id: m.id, counted: m.durationSec >= 180, canDedicate: m.completed, dedicationsLeftToday: 3, togetherPeople: 412, togetherCountries: 37);
  }

  @override
  Future<List<MeditationResult>> batch(List<MeditationRecord> items) async => [for (final m in items) await record(m)];
  @override
  Future<Page<Json>> history({String? cursor}) async => const Page([], null);
}

class MockMeRepository implements MeRepository {
  MeProfile profile = const MeProfile(id: 'mock-user', firstName: 'Marcus');
  @override
  Future<MeProfile> me() async => profile;
  @override
  Future<MeProfile> patch(Json changes) async => profile = MeProfile(
      id: profile.id, firstName: (changes['firstName'] as String?) ?? profile.firstName, email: profile.email, isGuest: profile.isGuest,
      theme: (changes['theme'] as String?) ?? profile.theme, reminderEnabled: (changes['reminderEnabled'] as bool?) ?? profile.reminderEnabled,
      reminderTime: (changes['reminderTime'] as String?) ?? profile.reminderTime, groupWarning: (changes['groupWarning'] as bool?) ?? profile.groupWarning,
      dailyMessagePush: (changes['dailyMessagePush'] as bool?) ?? profile.dailyMessagePush, showCountry: (changes['showCountry'] as bool?) ?? profile.showCountry, entitlement: profile.entitlement);
  final devices = <DeviceRegistration>[];
  @override
  Future<String> registerDevice(DeviceRegistration d) async {
    devices.add(d);
    return 'dev-${devices.length}';
  }

  @override
  Future<void> unregisterDevice(String deviceId) async {}
  @override
  Future<ProgressData> progress(Period p) async => MockData.progress(p);
  final read = <String>{};
  @override
  Future<Page<InboxItem>> inbox({String? cursor}) async => Page([
        InboxItem(id: 'i1', type: 'group', title: 'Group meditation starts in 10 minutes', createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 1)), read: read.contains('i1')),
        InboxItem(id: 'i2', type: 'daily', title: 'Today\'s message is ready', createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 5)), read: read.contains('i2')),
      ], null);
  @override
  Future<void> markRead({List<String>? ids, bool all = false}) async => read.addAll(all ? ['i1', 'i2'] : ids ?? const []);
  @override
  Future<void> syncEntitlement() async {}
  @override
  Future<String> startExport() async => 'job-1';
  @override
  Future<({String status, String? jsonUrl, String? csvUrl})> exportStatus(String jobId) async => (status: 'done', jsonUrl: 'https://example.com/e.json', csvUrl: 'https://example.com/e.csv');
  bool deleted = false;
  @override
  Future<void> deleteAccount() async => deleted = true;
}

class MockCommunityRepository implements CommunityRepository {
  final held = <String>{};
  int left = 3;
  @override
  Future<Page<Dedication>> dedications(String sessionId, {String? cursor}) async => Page(MockData.dedications, null);
  @override
  Future<PostResult> post({required String meditationId, required String text}) async => PostResult(id: 'new', status: 'visible', leftToday: --left);
  @override
  Future<int> hold(String id, bool on) async {
    on ? held.add(id) : held.remove(id);
    return MockData.dedications.firstWhere((d) => d.id == id).holdingCount + (on ? 1 : 0);
  }

  @override
  Future<void> report(String id, {required String reason, bool block = false}) async {}
}

class MockRecipeRepository implements RecipeRepository {
  final items = <Recipe>[];
  @override
  Future<List<Recipe>> list() async => List.of(items);
  @override
  Future<Recipe> create(Recipe r) async {
    final n = Recipe(id: 'r${items.length + 1}', name: r.name, lengthMin: r.lengthMin, openingId: r.openingId, soundId: r.soundId, soundLevel: r.soundLevel, texture: r.texture, bells: r.bells, blocks: r.blocks);
    items.add(n);
    return n;
  }

  @override
  Future<Recipe> update(String id, Json changes) async => items.firstWhere((r) => r.id == id);
  @override
  Future<void> delete(String id) async => items.removeWhere((r) => r.id == id);
  @override
  Future<String> share(String id) async => 'https://wehum.app/r/abc23';
  @override
  Future<Recipe> shared(String slug) async => items.first;
}

class MockProgramRepository implements ProgramRepository {
  @override
  Future<Program> start(String id) async => MockData.catalog.programs.first;
  @override
  Future<Program> completeDay(String id, int day) async => MockData.catalog.programs.first;
}

class MockAnalyticsRepository implements AnalyticsRepository {
  final sent = <Json>[];
  @override
  Future<void> send(List<Json> events) async => sent.addAll(events);
}
