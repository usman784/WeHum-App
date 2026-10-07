import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/local/app_database.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/json.dart';
import '../../../core/data/models/today.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/realtime/socket_events.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/services/perf_service.dart';
import '../../../core/services/time_service.dart';
import '../../../core/widgets/states.dart';
import '../../player/player_args.dart';

String localDate([DateTime? now]) => DateFormat('yyyy-MM-dd').format(now ?? DateTime.now());

String greetingFor(DateTime now, String name) {
  final h = now.hour;
  final part = h < 5 ? 'Good evening' : (h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening'));
  return name.isEmpty ? part : '$part, $name';
}

String groupNumber(int v) => NumberFormat.decimalPattern('en').format(v);

/// The one line that says how many people are meditating (spec §13 empty-room rule). `null` means "do not show".
/// Numbers are never presented as live when the socket is paused.
String? liveLineText({LiveAgg? agg, LiveLine? snapshot, required bool paused}) {
  if (paused) return 'Live counts paused';
  // quiet room with nobody yet today: say so honestly instead of showing "0 meditated today"
  String quiet(int today) => today == 0 ? 'Be the first to meditate today' : '${groupNumber(today)} meditated today';
  if (agg != null) return agg.quiet ? quiet(agg.meditatedToday) : '${groupNumber(agg.total)} meditating now · ${agg.countries} countries';
  if (snapshot != null) return snapshot.quiet ? quiet(snapshot.meditatedToday) : '${groupNumber(snapshot.total)} meditating now · ${snapshot.countries} countries';
  return null;
}

/// 22 Today (member) and 24 Today (free). Reads cache first, then the network; live numbers come from the socket.
class TodayController extends GetxController {
  late final TodayRepository _repo = Get.find();
  late final LiveService live = Get.find();
  late final SocketService socket = Get.find();
  late final TimeService time = Get.find();
  late final AccessService access = Get.find();
  late final AppDatabase _db = Get.find();

  final state = ViewState.loading.obs;
  final data = Rxn<TodayData>();
  final length = 10.obs;
  final offline = false.obs;
  Worker? _lengths;
  String _date = localDate();

  String get date => _date;
  String get name => Get.find<OnboardingStore>().name.isNotEmpty ? Get.find<OnboardingStore>().name : (access.isGuest.value ? '' : '');

  String? get liveText => liveLineText(agg: live.agg.value, snapshot: data.value?.live, paused: live.paused);
  bool get liveQuiet => live.agg.value?.quiet ?? data.value?.live?.quiet ?? false;
  int get practiced => live.motdPracticed[_date] ?? data.value?.motd?.practicedToday ?? 0;

  @override
  void onInit() {
    super.onInit();
    Perf.start('today_first_content');
    load();
  }

  /// Screen shown: join the `today` room and (when there is an MOTD) `motd:{date}`.
  @override
  void onReady() {
    super.onReady();
    live.acquireToday();
    live.acquireMotd(_date);
    _lengths = ever(data, (_) => _pickLength());
  }

  void _pickLength() {
    final ls = data.value?.motd?.lengths ?? const [];
    if (ls.isNotEmpty && !ls.contains(length.value)) length.value = ls.first;
  }

  @override
  void onClose() {
    live.releaseToday();
    live.releaseMotd(_date);
    _lengths?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    _date = localDate();
    // cache first: Today content appears at once, then refreshes (spec §6.2: first content < 300 ms from cache)
    final cached = await _db.getCache('today:${access.isMember ? 'm' : 'f'}:$_date');
    if (cached != null) {
      try {
        data.value = TodayData.fromJson(asJson(jsonDecode(cached)));
        state.value = ViewState.content;
      } catch (_) {}
    }
    try {
      final fresh = await _repo.today(_date);
      data.value = fresh;
      offline.value = false;
      state.value = (fresh.motd == null && !access.isMember && fresh.freePick == null) ? ViewState.empty : ViewState.content;
      _pickLength();
      Perf.finish('today_first_content');
      _db.putCache('today:${access.isMember ? 'm' : 'f'}:$_date', jsonEncode(_toJson(fresh)));
    } catch (e) {
      final failure = ViewState.fromError(e);
      if (data.value != null) {
        offline.value = failure.kind == ViewKind.offline; // keep the cached Today and show the banner
        state.value = ViewState.content;
      } else {
        state.value = failure;
      }
    }
  }

  Future<void> refreshAll() => load();

  // ───────────── actions
  GroupInfo? get group => data.value?.group;

  /// "16:00" in the phone's time zone.
  String get groupTime => group == null ? '' : DateFormat('HH:mm').format(group!.startsAt.toLocal());

  bool get groupOpen => group != null && group!.state != GroupPhase.ended;

  /// Remaining time to the group start, by the server-synced clock.
  Duration get untilGroup => group == null ? Duration.zero : group!.startsAt.difference(time.now());

  void meditateNow() {
    final m = data.value?.motd;
    if (m == null) return;
    Get.find<AnalyticsService>().track('motd_length_selected', {'length': length.value});
    Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'motd', title: m.title, subtitle: 'with ${m.teacher ?? 'Raphael'}', sessionId: m.sessionId, coverUrl: m.cover?.url, date: _date, lengthMin: length.value,
      target: PlayMotd(_date, length.value), durationSec: length.value * 60));
  }

  void openRoom() {
    Get.find<AnalyticsService>().track('motd_view', {'date': _date, 'room': liveQuiet ? 'quiet' : 'busy'});
    Get.toNamed(AppRoutes.motdRoom);
  }

  void waitForGroup() => Get.toNamed(AppRoutes.groupMeditationLobby);

  static Map<String, dynamic> _toJson(TodayData d) => {
        'date': d.date,
        'motd': d.motd == null
            ? null
            : {
                'date': d.motd!.date, 'sessionId': d.motd!.sessionId, 'title': d.motd!.title, 'teacher': d.motd!.teacher, 'theme': d.motd!.theme,
                'cover': d.motd!.cover == null ? null : {'url': d.motd!.cover!.url, 'blurhash': d.motd!.cover!.blurhash}, 'lengths': d.motd!.lengths,
                'practicedToday': d.motd!.practicedToday, 'fallback': d.motd!.fallback
              },
        'live': d.live == null ? null : {'total': d.live!.total, 'countries': d.live!.countries, 'quiet': d.live!.quiet, 'meditatedToday': d.live!.meditatedToday},
        'group': d.group == null
            ? null
            : {
                'date': d.group!.date, 'startsAt': d.group!.startsAt.toIso8601String(), 'endsAt': d.group!.endsAt.toIso8601String(), 'lobbyOpensAt': d.group!.lobbyOpensAt.toIso8601String(),
                'lengthMin': d.group!.lengthMin, 'reminderMin': d.group!.reminderMin, 'state': d.group!.state.name, 'waiting': d.group!.waiting, 'sessionId': d.group!.sessionId, 'title': d.group!.title
              },
        'freePick': d.freePick == null ? null : {'sessionId': d.freePick!.sessionId, 'title': d.freePick!.title, 'youtubeId': d.freePick!.youtubeId, 'durationSec': d.freePick!.durationSec},
        'program': d.program == null ? null : {'id': d.program!.id, 'title': d.program!.title, 'day': d.program!.day, 'days': d.program!.days, 'unlockAt': d.program!.unlockAt?.toIso8601String()},
        'progress': {'minutesWeek': d.progress.minutes, 'meditationsWeek': d.progress.meditations, 'daysThisWeek': d.progress.daysThisWeek},
        'dailyMessage': d.dailyMessage == null ? null : {'date': d.dailyMessage!.date, 'title': d.dailyMessage!.title, 'type': d.dailyMessage!.type},
      };
}
