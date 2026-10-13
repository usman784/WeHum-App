import '../../realtime/socket_events.dart';
import '../models/activity.dart';
import '../models/content.dart';
import '../models/json.dart';
import '../models/soon.dart';
import '../models/stitch.dart';
import '../models/today.dart';

/// Controllers talk to these interfaces only (spec §6.1). `api/` and `mock/` implement them.
abstract class TodayRepository {
  Future<TodayData> today(String date);
  Future<MotdInfo> motd(String date);
  Future<GroupInfo> groupNext();
  Future<DailyMessage> dailyMessage(String date);
  Future<Page<DailyMessage>> archive({String? q, String? theme, String? cursor});

  /// REST fallback for live counts (`GET /v1/live`).
  Future<LiveAgg?> live();
  Future<void> setGroupReminder(bool on);

  /// Saves the intention for a sit; [slot] is `GroupInfo.date`.
  Future<void> setIntention(String slot, String intention);
  Future<void> completeMessage(String date);
  Future<void> saveMessage(String date, {required bool on});
  Future<WorldGauge> world();
  Future<SilenceInfo> silence();
  Future<LibrarySummary> librarySummary();
}

abstract class CatalogRepository {
  /// Whole library. Pass [knownVersion] to skip the download when nothing changed (returns null).
  Future<Catalog?> catalog({int? knownVersion});
  Future<SessionDetail> session(String id);
  Future<Program> program(String id);
  Future<Teacher> teacher(String id);
  Future<SosInfo> sos();
  Future<CrisisDirectory> crisisDirectory({String? country});
  Future<List<SessionSummary>> search({required String q, String? themeId, String? type});
}

abstract class MediaRepository {
  /// [fresh] skips any prefetched URL (used after an expired URL).
  Future<PlayUrl> playUrl(PlayTarget target, {bool download = false, bool fresh = false});

  /// 30-second preview of a locked premium meditation (free users).
  Future<PreviewUrl> previewUrl(String sessionId);
}

abstract class MeditationRepository {
  Future<MeditationResult> record(MeditationRecord m);
  Future<List<MeditationResult>> batch(List<MeditationRecord> items);
  Future<Page<Json>> history({String? cursor});

  /// "Send kudos to all" after finishing a meditation.
  Future<int> kudos(String sessionId);
}

class DeviceRegistration {
  const DeviceRegistration({required this.installId, required this.platform, required this.appVersion, this.pushToken, this.osVersion, this.model});
  final String installId, platform, appVersion;
  final String? pushToken, osVersion, model;
}

class UsernameCheck {
  const UsernameCheck({required this.available, this.reason, this.suggestions = const []});
  final bool available;
  final String? reason;
  final List<String> suggestions;
}

abstract class MeRepository {
  Future<MeProfile> me();
  Future<MeProfile> patch(Json changes);

  /// Live check while typing a username: free and allowed? Always comes with a few alternatives.
  Future<UsernameCheck> checkUsername(String username);

  /// Instagram-style suggestions from a first name or e-mail.
  Future<List<String>> suggestUsernames(String seed);

  /// Uploads a profile photo (JPEG/PNG/WebP, about 512 px) and returns the new profile.
  Future<MeProfile> setAvatar(List<int> bytes, String contentType);
  Future<MeProfile> removeAvatar();

  /// Returns the device id; registering a token also subscribes the user topic on the server.
  Future<String> registerDevice(DeviceRegistration d);
  Future<void> unregisterDevice(String deviceId);
  Future<ProgressData> progress(Period p);
  Future<Page<InboxItem>> inbox({String? cursor});
  Future<void> markRead({List<String>? ids, bool all = false});

  /// Swipe-to-delete: removes one notification of this person.
  Future<void> deleteInbox(String id);
  Future<void> syncEntitlement();
  Future<String> startExport();
  Future<({String status, String? jsonUrl, String? csvUrl, String? zipUrl})> exportStatus(String jobId);
  Future<void> deleteAccount();
}

class PostResult {
  const PostResult({required this.id, required this.status, this.showHelp = false, this.leftToday = 0});
  final String id, status;
  final bool showHelp;
  final int leftToday;
}

abstract class CommunityRepository {
  Future<Page<Dedication>> dedications(String sessionId, {String? cursor});
  Future<PostResult> post({required String meditationId, required String text, bool showPlace = false});
  Future<Page<FeedItem>> feed({String? cursor});
  Future<int> membersAt(String time);
  Future<int> anonymize();
  Future<int> hold(String id, bool on);
  Future<void> report(String id, {required String reason, bool block = false});
}

abstract class RecipeRepository {
  Future<List<Recipe>> list();
  Future<Recipe> create(Recipe r);
  Future<Recipe> update(String id, Json changes);
  Future<void> delete(String id);
  Future<String> share(String id);
  Future<Recipe> shared(String slug);
}

abstract class ProgramRepository {
  Future<Program> start(String id);
  Future<Program> completeDay(String id, int day);
}

abstract class AnalyticsRepository {
  Future<void> send(List<Json> events);
}

/// P12 "coming soon" features. Every call throws `FEATURE_OFF` while its flag is off.
abstract class ComingSoonRepository {
  Future<ChallengesData> challenges();
  Future<ChallengeDetail> challengeDetail(String id);
  Future<void> joinChallenge(String id);
  Future<void> leaveChallenge(String id);
  Future<Page<GratitudePost>> gratitude(String kind, {String? cursor});
  Future<PostResult> shareGratitude(String kind, String text);
  Future<void> reportGratitude(String id, {required String reason, bool block = false});
  Future<BreathworkData> breathwork();
  Future<List<BreathPattern>> myPatterns();
  Future<BreathPattern> savePattern(BreathPattern p);
  Future<void> deletePattern(String id);
  Future<MilestonesData> milestones();
}
