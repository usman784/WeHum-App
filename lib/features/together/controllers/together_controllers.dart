import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/content.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/stitch.dart';
import '../../../core/data/models/today.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/realtime/lobby_service.dart';
import '../../../core/realtime/socket_events.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/time_service.dart';
import '../../../core/utils/countries.dart';
import '../../../core/widgets/states.dart';
import '../../player/player_args.dart';
import '../../today/controllers/today_controller.dart';

/// 25 World map & World Vibration (`world` room → `live:agg`), plus the Stitch gauge numbers from `GET /v1/live/world`.
class WorldController extends GetxController {
  late final LiveService live = Get.find();
  late final TodayRepository _repo = Get.find();
  final gauge = Rxn<WorldGauge>();
  Timer? _poll;

  @override
  void onReady() {
    super.onReady();
    live.acquireWorld();
    Get.find<AnalyticsService>().track('world_map_view');
    _loadGauge();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _loadGauge());
  }

  Future<void> _loadGauge() async {
    try {
      gauge.value = await _repo.world();
    } catch (_) {/* the live numbers from the socket still show */}
  }

  @override
  void onClose() {
    _poll?.cancel();
    live.releaseWorld();
    super.onClose();
  }

  /// Minutes sat so far today (the "volume" line); null until the server answers.
  int? get minutesToday => gauge.value?.minutesToday;
  int? get trendPct => gauge.value?.trendPct;
  List<WorldBelt> get regions => gauge.value?.regions ?? const [];
  List<WorldBelt> get belts => gauge.value?.belts ?? const [];

  /// Country rows: the live socket list first (named from the country codes), enriched with the server's minutes and
  /// group-sit share; the server's list alone when the socket has nothing.
  List<WorldBelt> get countryRows {
    final top = paused ? const <({String country, int n})>[] : (agg?.top ?? const <({String country, int n})>[]);
    if (top.isEmpty) return belts;
    final byCode = {for (final b in belts) b.key: b};
    return [
      for (final t in top)
        WorldBelt(key: t.country, name: countryName(t.country), sittingNow: t.n, minutesToday: byCode[t.country]?.minutesToday ?? 0, syncShare: byCode[t.country]?.syncShare ?? 0),
    ];
  }

  LiveAgg? get agg => live.agg.value;
  bool get paused => live.paused;
  bool get quiet => agg?.quiet ?? true;

  String get kicker => paused ? 'LIVE COUNTS PAUSED' : (agg == null ? 'LOADING' : (quiet ? 'QUIET RIGHT NOW' : 'LIVE'));
  String get big => agg == null ? '–' : groupNumber(agg!.headline);
  String get sub => paused || agg == null ? 'We don’t show old numbers as if they were live.' : (quiet ? 'people meditated today' : 'people meditating now · ${agg!.countries} countries');
  int get vibration => agg?.vibration ?? 0;
  String get vibrationWord => vibration >= 66 ? 'Strong' : (vibration >= 33 ? 'Rising' : 'Quiet');
  Map<String, int> get hot => agg?.where ?? const {};

  void openInfo() => Get.find<AnalyticsService>().track('vibration_info_open');
}

/// 23 Meditation of the Day room.
class MotdRoomController extends GetxController {
  late final TodayRepository _repo = Get.find();
  late final CatalogRepository _catalog = Get.find();
  late final LiveService live = Get.find();
  late final TimeService time = Get.find();

  final state = ViewState.loading.obs;
  final data = Rxn<TodayData>();
  final dedications = <Dedication>[].obs;
  final dedicationTotal = 0.obs;
  final length = 10.obs;
  final reminder = false.obs;
  late final String date = localDate();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onReady() {
    super.onReady();
    live.acquireToday();
    live.acquireMotd(date);
  }

  @override
  void onClose() {
    live.releaseToday();
    live.releaseMotd(date);
    super.onClose();
  }

  Future<void> load() async {
    try {
      final d = await _repo.today(date);
      data.value = d;
      final m = d.motd;
      if (m == null) {
        state.value = ViewState.empty;
        return;
      }
      if (m.lengths.isNotEmpty) length.value = m.lengths.first;
      state.value = ViewState.content;
      try {
        final detail = await _catalog.session(m.sessionId);
        dedications.assignAll(detail.dedications);
        dedicationTotal.value = detail.dedications.length;
      } catch (_) {/* "Dedications will load when you're back" */}
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  String? get liveText => liveLineText(agg: live.agg.value, snapshot: data.value?.live, paused: live.paused);
  int get practiced => live.motdPracticed[date] ?? data.value?.motd?.practicedToday ?? 0;
  GroupInfo? get group => data.value?.group;
  bool get groupOpen => group != null && group!.state != GroupPhase.ended;
  String get groupTime => group == null ? '' : DateFormat('HH:mm').format(group!.startsAt.toLocal());

  bool get isMember => Get.find<AccessService>().isMember;

  void meditateNow() {
    // the Meditation of the Day is part of membership (spec §1.2): a free user gets the paywall, never a failing player
    if (!isMember) {
      Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'lock'});
      return;
    }
    final m = data.value!.motd!;
    Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'motd', title: m.title, subtitle: 'with ${m.teacher ?? 'Raphael'}', sessionId: m.sessionId, coverUrl: m.cover?.url, date: date, lengthMin: length.value,
      target: PlayMotd(date, length.value), durationSec: length.value * 60));
  }

  /// "Remind me": a server push 10 min before (PUT /v1/group/remind) plus a local notification as the fallback.
  Future<void> toggleReminder() async {
    final on = !reminder.value;
    reminder.value = on;
    try {
      await _repo.setGroupReminder(on);
    } catch (_) {}
    final n = Get.find<NotificationService>();
    final g = group;
    if (on && g != null) {
      await n.scheduleGroupReminder(g.startsAt);
    } else {
      await n.cancelGroupReminder();
    }
  }
}

/// 53 Group meditation lobby. Joins `lobby:{date}` (members only), shows live counts from `lobby:state`,
/// and at T0 starts the player for everyone — from `group:start` or the server-synced local timer, whichever is first.
class LobbyController extends GetxController {
  late final LobbyService lobby = Get.find();
  late final TodayRepository _repo = Get.find();
  late final TimeService time = Get.find();
  late final AccessService access = Get.find();

  final state = ViewState.loading.obs;
  final group = Rxn<GroupInfo>();
  final reminder = false.obs;
  final denied = false.obs; // PREMIUM_REQUIRED
  Worker? _started;

  /// The slot id of this sit (`2026-10-12`, or `2026-10-12T08` for an hourly sit).
  String get date => group.value?.date ?? localDate();

  /// The calendar day of the slot: what the Meditation of the Day is keyed by.
  String get day => date.length >= 10 ? date.substring(0, 10) : date;

  /// "The lobby opens 15 minutes before." from the server's group config (never a fixed number in the app).
  String get doorsLine {
    final g = group.value;
    if (g == null) return '';
    final min = g.startsAt.difference(g.lobbyOpensAt).inMinutes;
    return min <= 0 ? '' : 'The lobby opens $min ${min == 1 ? 'minute' : 'minutes'} before. ';
  }

  @override
  void onReady() {
    super.onReady();
    _started = ever(lobby.started, (g) {
      if (g != null) _begin();
    });
    load();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    try {
      final g = await _repo.groupNext();
      group.value = g;
      if (!access.isMember) {
        denied.value = true;
        state.value = ViewState.content;
        return;
      }
      final err = await lobby.join(g.date);
      if (err == 'PREMIUM_REQUIRED') denied.value = true;
      state.value = ViewState.content;
      Get.find<AnalyticsService>().track('lobby_join', {'date': g.date, 'waiting': g.waiting});
      // group already running: late joiners start where the group is
      if (g.state == GroupPhase.live) _begin();
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  int get waiting => lobby.state.value?.waiting ?? group.value?.waiting ?? 0;
  int get countries => lobby.state.value?.countries ?? 0;
  List<({String region, int n})> get regions => lobby.state.value?.regions ?? const [];
  Belts get belts {
    final l = lobby.state.value;
    if (l != null && (l.americas + l.emea + l.apac) > 0) return Belts(americas: l.americas, emea: l.emea, apac: l.apac);
    return group.value?.waitingByBelt ?? const Belts();
  }
  DateTime? get startsAt => lobby.startsAt.value ?? group.value?.startsAt;
  Duration get left => (startsAt ?? time.now()).difference(time.now());
  String get startLabel => startsAt == null ? '' : DateFormat('HH:mm').format(startsAt!.toLocal());

  bool _launched = false;

  /// Opens the player in group mode. A late joiner seeks to `now − T0`.
  void _begin() {
    if (_launched) return;
    _launched = true;
    final g = group.value;
    final s = lobby.started.value;
    final startAt = lobby.lateOffset();
    Get.find<AnalyticsService>().track('group_start', {'date': date, 'waiting': waiting});
    Get.offNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'group', mode: 'group', title: g?.title ?? 'Group meditation', subtitle: 'Meditation of the Day · Raphael', sessionId: (s?.sessionId.isNotEmpty ?? false) ? s!.sessionId : g?.sessionId,
      date: day, lengthMin: (s?.lengthMin ?? 0) > 0 ? s!.lengthMin : g?.lengthMin, target: PlayMotd(day, (s?.lengthMin ?? 0) > 0 ? s!.lengthMin : (g?.lengthMin ?? 30)),
      durationSec: ((s?.lengthMin ?? 0) > 0 ? s!.lengthMin : (g?.lengthMin ?? 30)) * 60, startAt: startAt, live: true));
  }

  Future<void> toggleReminder() async {
    final on = !reminder.value;
    reminder.value = on;
    try {
      await _repo.setGroupReminder(on);
    } catch (_) {}
    final n = Get.find<NotificationService>();
    if (on && group.value != null) {
      await n.scheduleGroupReminder(group.value!.startsAt);
    } else {
      await n.cancelGroupReminder();
    }
  }

  void leave() => lobby.leave();

  @override
  void onClose() {
    _started?.dispose();
    if (!_launched) lobby.leave(); // stay "in the lobby" only while this screen is open
    super.onClose();
  }
}

/// 52 Together.
class TogetherController extends GetxController {
  late final TodayRepository _repo = Get.find();
  late final LiveService live = Get.find();
  late final CatalogRepository _catalog = Get.find();
  late final TimeService time = Get.find();
  late final SocketService socket = Get.find();

  final state = ViewState.loading.obs;
  final group = Rxn<GroupInfo>();
  final dedications = <Dedication>[].obs;
  final gratitudeOn = false.obs;
  /// "Shared intent": the newest dedications across meditations.
  final feed = <FeedItem>[].obs;
  final silenceNow = 0.obs;
  /// Durations offered in the Silence Room (from the CMS); the first four are shown on Together.
  final silenceDurations = <int>[].obs;
  final reminder = false.obs;

  @override
  void onReady() {
    super.onReady();
    live.acquireWorld();
    live.acquireSilence();
    load();
  }

  @override
  void onClose() {
    live.releaseWorld();
    live.releaseSilence();
    super.onClose();
  }

  int get silenceCount => live.silence.value?.people ?? silenceNow.value;

  /// "Holding this with you": toggles and shows the server's count.
  Future<void> hold(FeedItem it) async {
    final d = it.dedication;
    final on = !d.heldByMe;
    final i = feed.indexWhere((x) => x.dedication.id == d.id);
    if (i < 0) return;
    feed[i] = FeedItem(dedication: d.copyWith(heldByMe: on, holdingCount: d.holdingCount + (on ? 1 : -1)), place: it.place, isTeacher: it.isTeacher, sessionId: it.sessionId, sessionTitle: it.sessionTitle);
    try {
      final n = await Get.find<CommunityRepository>().hold(d.id, on);
      feed[i] = FeedItem(dedication: d.copyWith(heldByMe: on, holdingCount: n), place: it.place, isTeacher: it.isTeacher, sessionId: it.sessionId, sessionTitle: it.sessionTitle);
    } catch (_) {
      feed[i] = it; // the server said no (offline, a guest): put it back
    }
  }

  Future<void> toggleReminder() async {
    final on = !reminder.value;
    reminder.value = on;
    try {
      await _repo.setGroupReminder(on);
    } catch (_) {}
    final g = group.value;
    final n = Get.find<NotificationService>();
    if (on && g != null) {
      await n.scheduleGroupReminder(g.startsAt);
    } else {
      await n.cancelGroupReminder();
    }
  }

  Future<void> load() async {
    try {
      group.value = await _repo.groupNext();
      state.value = ViewState.content;
      try {
        feed.assignAll((await Get.find<CommunityRepository>().feed()).items);
      } catch (_) {/* the feed fills in when the connection is back */}
      try {
        final si = await _repo.silence();
        silenceNow.value = si.sittingNow;
        silenceDurations.assignAll(si.durations);
      } catch (_) {}
      final sid = group.value?.sessionId;
      if (sid != null) {
        try {
          dedications.assignAll((await _catalog.session(sid)).dedications);
        } catch (_) {}
      }
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  String? get liveText => liveLineText(agg: live.agg.value, paused: live.paused);
  bool get quiet => live.agg.value?.quiet ?? true;
  int get vibration => live.agg.value?.vibration ?? 0;
  String get vibrationWord => vibration >= 66 ? 'Strong and rising' : (vibration >= 33 ? 'Rising' : 'Quiet');
  String get groupTime => group.value == null ? '' : DateFormat('HH:mm').format(group.value!.startsAt.toLocal());
  Duration get untilGroup => group.value == null ? Duration.zero : group.value!.startsAt.difference(time.now());
}


/// Next synchronised sit (Stitch "Next sit in X minutes"): countdown, who is waiting, intention, reminder, calendar.
class NextSitController extends GetxController {
  late final TodayRepository _repo = Get.find();
  late final TimeService time = Get.find();
  late final LobbyService lobby = Get.find();
  final state = ViewState.loading.obs;
  final group = Rxn<GroupInfo>();
  final intention = RxnString();
  final reminder = false.obs;
  Timer? _poll;

  @override
  void onInit() {
    super.onInit();
    load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void onClose() {
    _poll?.cancel();
    super.onClose();
  }

  Future<void> load() async {
    try {
      final g = await _repo.groupNext();
      group.value = g;
      intention.value = g.myIntention;
      state.value = ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  Future<void> _refresh() async {
    try {
      final g = await _repo.groupNext();
      if (g.date != group.value?.date) intention.value = g.myIntention;
      group.value = g;
    } catch (_) {}
  }

  Belts get waiting {
    final l = lobby.state.value;
    if (l != null && l.date == group.value?.date && (l.americas + l.emea + l.apac) > 0) return Belts(americas: l.americas, emea: l.emea, apac: l.apac);
    return group.value?.waitingByBelt ?? const Belts();
  }

  DateTime? get startsAt => group.value?.startsAt;
  String get startLabel => startsAt == null ? '' : DateFormat('hh:mm a').format(startsAt!.toLocal());
  Duration get left => (startsAt ?? time.now()).difference(time.now());

  Future<void> pick(String text) async {
    final g = group.value;
    if (g == null) return;
    intention.value = text;
    Get.find<AnalyticsService>().track('sit_intention_set', {'intention': text});
    try {
      await _repo.setIntention(g.date, text);
    } catch (_) {}
  }

  Future<void> toggleReminder() async {
    final on = !reminder.value;
    reminder.value = on;
    Get.find<AnalyticsService>().track('sit_notify_toggle', {'minutes_before': group.value?.reminderMin ?? 10});
    try {
      await _repo.setGroupReminder(on);
    } catch (_) {}
    final n = Get.find<NotificationService>();
    final g = group.value;
    if (on && g != null) {
      await n.scheduleGroupReminder(g.startsAt);
    } else {
      await n.cancelGroupReminder();
    }
  }
}
