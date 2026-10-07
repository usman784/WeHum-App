import '../../errors/error_code.dart';
import '../../realtime/socket_events.dart';
import '../contracts/auth_repository.dart';
import '../contracts/bootstrap_repository.dart';
import '../contracts/repositories.dart';
import '../models/activity.dart';
import '../models/bootstrap.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../models/session.dart';
import '../models/soon.dart';
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

  /// Test controls: which emails already have an account, and what the calls received.
  final existingEmails = <String>{'taken@example.com'};
  final calls = <String>[];
  String? failNextWith;
  AuthSession _acct({String? first, String? merge}) => AuthSession(accessToken: 'acct-access', refreshToken: 'acct-refresh-token-000000000', me: Me(id: 'mock-user', isGuest: false, firstName: first), mergeToken: merge);

  Never _exists(String provider) => throw ApiException(ErrorCode.accountExists, status: 409, details: {'mergeToken': 'merge-token-0000000000000000', 'provider': provider});

  @override
  Future<AuthSession> linkSocial(String provider, String firebaseIdToken, {String? firstName}) async {
    calls.add('link:$provider');
    if (firebaseIdToken == 'exists') _exists(provider);
    return _acct(first: firstName);
  }

  @override
  Future<AuthSession> linkEmail({required String email, required String password, String? firstName}) async {
    calls.add('linkEmail:$email');
    if (existingEmails.contains(email)) _exists('email');
    return _acct(first: firstName);
  }

  @override
  Future<AuthSession> emailLogin({required String email, required String password}) async {
    calls.add('emailLogin:$email');
    if (password != 'correct-password') throw ApiException(ErrorCode.invalidCredentials, status: 401);
    return _acct(merge: 'merge-token-0000000000000000');
  }

  @override
  Future<void> forgotPassword(String email) async => calls.add('forgot:$email');
  @override
  Future<void> resetPassword({required String token, required String password}) async => calls.add('reset');
  @override
  Future<void> sendMagicLink(String email) async => calls.add('magic:$email');
  @override
  Future<AuthSession> verifyMagicLink(String token) async => _acct();
  @override
  Future<void> verifyEmail(String token) async => calls.add('verifyEmail');
  @override
  Future<void> merge(String mergeToken) async => calls.add('merge');

  @override
  Future<void> logout() async => calls.add('logout');
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
  Duration groupStartsIn = const Duration(minutes: 12);
  @override
  Future<TodayData> today(String date) async => MockData.today(date, member: member, groupStartsIn: groupStartsIn);
  @override
  Future<MotdInfo> motd(String date) async => MockData.motd(date);
  @override
  Future<GroupInfo> groupNext() async => MockData.group(DateTime.now().toIso8601String().substring(0, 10), startsIn: groupStartsIn);
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
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false}) async =>
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

class MockComingSoonRepository implements ComingSoonRepository {
  bool off = false;
  final joined = <String>{};
  final posts = <GratitudePost>[
    GratitudePost(id: 'g1', kind: 'gratitude', firstName: 'Lena', country: 'DE', text: 'For a quiet morning.', createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5))),
    GratitudePost(id: 'g2', kind: 'gratitude', firstName: 'Aiko', country: 'JP', text: 'My family is healthy.', createdAt: DateTime.now().toUtc().subtract(const Duration(hours: 1))),
  ];
  final patterns = <BreathPattern>[];
  void _check() {
    if (off) throw ApiException(ErrorCode.featureOff, status: 404);
  }

  @override
  Future<ChallengesData> challenges() async {
    _check();
    Challenge c(String id, String name, int days, {ChallengeMe? me}) => Challenge(id: id, name: name, days: days, peopleInIt: 1904, me: me);
    return ChallengesData(
      inProgress: [if (joined.contains('c7')) c('c7', '7 days of calm', 7, me: const ChallengeMe(completedDays: 3))],
      available: [if (!joined.contains('c7')) c('c7', '7 days of calm', 7), c('c21', '21-Day Resilience Arc', 21)],
      finished: [(id: 'cf', name: 'September: 7 days', days: 7, finishedAt: DateTime.utc(2026, 9, 21))]);
  }

  @override
  Future<void> joinChallenge(String id) async {
    _check();
    joined.add(id);
  }

  @override
  Future<void> leaveChallenge(String id) async {
    _check();
    joined.remove(id);
  }

  @override
  Future<Page<GratitudePost>> gratitude(String kind, {String? cursor}) async {
    _check();
    return Page(posts.where((p) => p.kind == kind).toList(), null);
  }

  @override
  Future<PostResult> shareGratitude(String kind, String text) async {
    _check();
    posts.insert(0, GratitudePost(id: 'new${posts.length}', kind: kind, firstName: 'Marcus', country: 'US', text: text, createdAt: DateTime.now().toUtc()));
    return const PostResult(id: 'new', status: 'visible', leftToday: 2);
  }

  @override
  Future<void> reportGratitude(String id, {required String reason, bool block = false}) async {
    _check();
    posts.removeWhere((p) => p.id == id);
  }

  @override
  Future<BreathworkData> breathwork() async {
    _check();
    return BreathworkData(templates: const [
      BreathPattern(name: 'Box breathing', subtitle: 'Calm and focus', inhaleSec: 4, hold1Sec: 4, exhaleSec: 4, hold2Sec: 4),
      BreathPattern(name: '4-7-8', subtitle: 'Wind down', inhaleSec: 4, hold1Sec: 7, exhaleSec: 8),
      BreathPattern(name: 'Coherent', subtitle: 'Even and slow', inhaleSec: 5, exhaleSec: 5),
    ], lessons: [(lesson: 1, session: MockData.sessions.first)]);
  }

  @override
  Future<List<BreathPattern>> myPatterns() async {
    _check();
    return List.of(patterns);
  }

  @override
  Future<BreathPattern> savePattern(BreathPattern p) async {
    _check();
    final n = BreathPattern(id: 'p${patterns.length + 1}', name: p.name, inhaleSec: p.inhaleSec, hold1Sec: p.hold1Sec, exhaleSec: p.exhaleSec, hold2Sec: p.hold2Sec, rounds: p.rounds);
    patterns.add(n);
    return n;
  }

  @override
  Future<void> deletePattern(String id) async {
    _check();
    patterns.removeWhere((p) => p.id == id);
  }

  @override
  Future<MilestonesData> milestones() async {
    _check();
    return const MilestonesData(reached: 4, total: 12, awards: [
      Award(key: 'first', label: 'First meditation', badge: '1', target: 1, value: 1, reached: true),
      Award(key: 'days7', label: '7 days meditated', badge: '7', target: 7, value: 7, reached: true),
      Award(key: 'minutes100', label: '100 minutes', badge: '100', target: 100, value: 100, reached: true),
      Award(key: 'group10', label: '10 group meditations', badge: '10', target: 10, value: 4, reached: false),
    ], world: {'minutes': 2400000, 'meditations': 186000, 'countries': 94, 'dedications': 41000});
  }
}
