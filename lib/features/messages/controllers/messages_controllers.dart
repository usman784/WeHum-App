import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../app/app_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/inbox_service.dart';
import '../../../core/widgets/states.dart';
import '../../player/player_args.dart';
import '../../today/controllers/today_controller.dart';

/// 26 Daily message (members). Falls back to the latest earlier message with its date.
class DailyMessageController extends GetxController {
  DailyMessageController(this.date);
  final String date;
  late final TodayRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final message = Rxn<DailyMessage>();
  final locked = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    if (!Get.find<AccessService>().isMember) {
      locked.value = true;
      state.value = ViewState.content;
      return;
    }
    try {
      message.value = await _repo.dailyMessage(date.isEmpty ? localDate() : date);
      state.value = ViewState.content;
    } catch (e) {
      final f = ViewState.fromError(e);
      if (f.error?.code == ErrorCode.notFound) {
        state.value = ViewState.empty;
      } else if (f.error?.code == ErrorCode.premiumRequired) {
        locked.value = true;
        state.value = ViewState.content;
      } else {
        state.value = f;
      }
    }
  }

  /// "Monday, October 5 · from Raphael" — or the real date when it is an earlier message.
  String get dateLine {
    final m = message.value;
    if (m == null) return '';
    final d = DateTime.tryParse(m.date);
    return '${d == null ? m.date : DateFormat('EEEE, MMMM d').format(d)} · from Raphael';
  }

  bool get isOlder => message.value != null && message.value!.date != (date.isEmpty ? localDate() : date);

  /// Audio and video play in the shared player; text is read here. Daily messages never count as meditations.
  void play() {
    final m = message.value!;
    Get.toNamed(m.type == 'video' ? AppRoutes.videoPlayer : AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'free', title: m.title, subtitle: 'Daily message', date: m.date, target: PlayDailyMessage(m.date), isVideo: m.type == 'video', record: false, mode: 'solo', durationSec: m.durationSec));
  }
}

/// 27 Explore archive: search by word, theme chips, month groups, paginated.
class ArchiveController extends GetxController {
  late final TodayRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final items = <DailyMessage>[].obs;
  final q = ''.obs;
  final theme = RxnString();
  final loadingMore = false.obs;
  String? _cursor;
  bool get hasMore => _cursor != null;
  Worker? _debounce;

  @override
  void onInit() {
    super.onInit();
    load();
    _debounce = debounce(q, (_) => load(), time: const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    _debounce?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    try {
      final p = await _repo.archive(q: q.value, theme: theme.value);
      items.assignAll(p.items);
      _cursor = p.nextCursor;
      state.value = items.isEmpty ? ViewState.empty : ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  Future<void> more() async {
    if (_cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      final p = await _repo.archive(q: q.value, theme: theme.value, cursor: _cursor);
      items.addAll(p.items);
      _cursor = p.nextCursor;
    } finally {
      loadingMore.value = false;
    }
  }

  /// Distinct theme tags found so far, for the chips.
  List<String> get themes => {for (final m in items) if (m.themeTag != null) m.themeTag!}.toList()..sort();

  /// "OCTOBER 2026" → messages.
  Map<String, List<DailyMessage>> get byMonth {
    final out = <String, List<DailyMessage>>{};
    for (final m in items) {
      final d = DateTime.tryParse(m.date);
      final k = d == null ? m.date : DateFormat('MMMM y').format(d).toUpperCase();
      (out[k] ??= []).add(m);
    }
    return out;
  }
}

/// 28 Notifications (inbox).
class NotificationsController extends GetxController {
  late final InboxService inbox = Get.find();

  @override
  void onReady() {
    super.onReady();
    inbox.load();
  }

  Future<void> open(InboxItem i) async {
    await inbox.markRead(i);
    Get.find<AnalyticsService>().track('push_open', {'key': i.type, 'notification_id': i.id});
    final link = i.deepLink;
    if (link != null && link.isNotEmpty) Get.find<AppController>().openLink(link, notificationId: i.id); // same router as push taps
  }
}
