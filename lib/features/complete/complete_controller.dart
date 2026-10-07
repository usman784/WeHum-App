import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/activity.dart';
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

  bool get canDedicate => (player.sessionId != null) && (result?.canDedicate ?? true) && args.counted;
  int get leftToday => result?.dedicationsLeftToday ?? 3;

  @override
  void onReady() {
    super.onReady();
    _loadStats();
    Get.find<AnalyticsService>().track('dedication_open', {'session_id': player.sessionId ?? ''});
  }

  Future<void> _loadStats() async {
    final me = Get.find<MeRepository>();
    try {
      progress.value = await me.progress(Period.week);
      lifetime.value = await me.progress(Period.all);
    } catch (_) {/* offline: the screen keeps the local numbers */}
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
