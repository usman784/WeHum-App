import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/activity.dart';
import '../../core/data/models/content.dart';
import '../../core/realtime/live_service.dart';
import '../../core/services/access_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/sync_service.dart';
import '../../core/utils/uuid7.dart';
import '../player/controllers/player_controller.dart';
import '../player/player_args.dart';
import '../dedications/controllers/dedications_controllers.dart';

enum DedicateAccess { allowed, needsAccount, needsMembership }

/// 45 Meditation complete · payoff. Shows what was just done at once (from the local record) and fills in the server's
/// numbers when they arrive; the screen never waits on the network (spec §6.2).
class CompleteController extends GetxController {
  CompleteController(this.args);
  final CompleteArgs args;
  late final SyncService sync = Get.find();
  late final LiveService live = Get.find();
  late final AccessService access = Get.find();
  final progress = Rxn<ProgressData>();
  final lifetime = Rxn<ProgressData>();

  PlayerArgs get player => args.player;
  String get meditationId => args.record?.id ?? uuid7();
  int get minutes => ((args.record?.durationSec ?? 0) / 60).round().clamp(1, 1 << 20);

  MeditationResult? get result => sync.byId[args.record?.id];

  /// "You meditated with 412 people in 37 countries." — from the server's answer, else the last live numbers; omitted when quiet or unknown.
  String? get togetherLine {
    final r = result;
    if (r != null && r.togetherPeople > 1) return 'You meditated with ${groupNumberOf(r.togetherPeople)} people in ${r.togetherCountries} countries.';
    final a = live.agg.value;
    if (a != null && !a.quiet && a.total > 1 && !live.paused) return 'You meditated with ${groupNumberOf(a.total)} people in ${a.countries} countries.';
    return null;
  }

  /// Who may dedicate: members with an account, only for a counted meditation of a catalog session.
  DedicateAccess get dedicate => access.isGuest.value && access.isMember
      ? DedicateAccess.needsAccount
      : (access.isMember ? DedicateAccess.allowed : DedicateAccess.needsMembership);

  /// Only once the server has recorded this meditation and says yes (it checks membership, the account and today's limit).
  bool get canDedicate => (player.sessionId != null) && (result?.canDedicate ?? false) && args.counted;
  int get leftToday => result?.dedicationsLeftToday ?? 3;

  /// Why the dedicate button is not there (the server decides: a finished, counted meditation and today's limit).
  String get dedicateNote {
    if (player.sessionId == null) return 'Dedications belong to the guided meditations in the library.';
    if (!args.counted) return 'Dedications open after a meditation of three minutes or more.';
    if (args.record?.completed == false) return 'Dedications open when you stay to the end of a meditation.';
    if (result == null) return 'Saving your meditation… dedications open in a moment.';
    if (result != null && leftToday <= 0) return 'You have used today’s dedications. More tomorrow.';
    return 'Dedications are not open for this meditation.';
  }

  /// Live country counts for the small map (socket `live:agg`): empty while paused or when nobody is meditating.
  Map<String, int> get hot => live.paused ? const {} : (live.agg.value?.where ?? const {});

  Worker? _answered;

  @override
  void onReady() {
    super.onReady();
    live.acquireWorld(); // country counts for the map
    _loadStats();
    // the numbers on this screen include this meditation once the server has recorded it (outbox → answer)
    _answered = ever(sync.byId, (_) {
      if (result != null) {
        _answered?.dispose();
        _answered = null;
        _loadStats();
      }
    });
    // a finished program day moves the program forward (no rest days, no streaks)
    final pid = player.programId, day = player.programDay;
    if (pid != null && day != null && args.counted) {
      Get.find<ProgramRepository>().completeDay(pid, day).catchError((_) => const Program(id: '', slug: '', title: '', access: Access.free));
    }
    Get.find<AnalyticsService>().track('dedication_open', {'session_id': player.sessionId ?? ''});
  }

  Future<void> _loadStats() async {
    final me = Get.find<MeRepository>();
    try {
      progress.value = await me.progress(Period.week);
      lifetime.value = await me.progress(Period.all);
    } catch (_) {/* offline: the screen keeps the local numbers */}
  }

  @override
  void onClose() {
    _answered?.dispose();
    live.releaseWorld();
    super.onClose();
  }

  void done() => Get.offAllNamed(access.isMember ? AppRoutes.todayMember : AppRoutes.todayFree);
  void readDedications() => Get.toNamed('/dedications/${player.sessionId}', arguments: {'sessionId': player.sessionId, 'compose': false});
  void share() => Get.toNamed(AppRoutes.shareYourMeditation, arguments: this);
}

String groupNumberOf(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// Shared by 45 and 46 for the stats shown on the card.
extension CompleteStats on CompleteController {
  int get daysThisWeek => progress.value?.daysThisWeek.where((d) => d).length ?? 0;
  int get totalMinutes => lifetime.value?.minutes ?? minutes;
  String firstDedication() => '';
}

DedicationComposerController composerFor(CompleteController c) =>
    DedicationComposerController(meditationId: c.meditationId, sessionId: c.player.sessionId ?? '', leftToday: c.leftToday);
