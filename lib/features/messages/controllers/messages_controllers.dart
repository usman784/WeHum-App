import 'dart:async';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../app/app_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/audio/audio_engine.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/inbox_service.dart';
import '../../../core/widgets/states.dart';
import '../../player/player_args.dart';
import '../../today/controllers/today_controller.dart';

/// 26 Daily message + transcript (Stitch). Free messages open for everyone; premium ones need a membership.
/// Falls back to the latest earlier message with its date. Audio plays inline so the transcript can follow it.
class DailyMessageController extends GetxController {
  DailyMessageController(this.date);
  final String date;
  late final TodayRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final message = Rxn<DailyMessage>();
  final locked = false.obs;

  /// Audio | Video (video only when the message has one).
  final videoMode = false.obs;
  final position = Duration.zero.obs;
  final duration = Duration.zero.obs;
  final playing = false.obs;
  final audioLoading = false.obs;
  final audioError = false.obs;
  final search = ''.obs;
  AudioEngine? _engine;
  final _subs = <StreamSubscription<dynamic>>[];
  bool _completeSent = false;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    _engine?.dispose();
    super.onClose();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    try {
      message.value = await _repo.dailyMessage(date.isEmpty ? localDate() : date);
      locked.value = message.value!.locked;
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
  bool get hasVideoMode => message.value != null && (message.value!.hasVideo || message.value!.type == 'video');
  bool get hasAudioMode => message.value != null && message.value!.hasMedia && message.value!.type != 'video';

  /// The transcript line the playhead is in (the last one that started), -1 before the first.
  int get currentLine {
    final t = message.value?.transcript ?? const [];
    var cur = -1;
    for (var i = 0; i < t.length; i++) {
      if (position.value.inSeconds >= t[i].t) cur = i;
    }
    return cur;
  }

  /// Lines that match the transcript search (all of them when it is empty).
  List<int> get visibleLines {
    final t = message.value?.transcript ?? const [];
    final q = search.value.trim().toLowerCase();
    return [for (var i = 0; i < t.length; i++) if (q.isEmpty || t[i].text.toLowerCase().contains(q)) i];
  }

  Future<void> _ensureAudio() async {
    if (_engine != null) return;
    final m = message.value!;
    audioLoading.value = true;
    audioError.value = false;
    try {
      final url = await Get.find<MediaRepository>().playUrl(PlayDailyMessage(m.date));
      final u = url.url ?? url.hlsUrl;
      if (u == null) throw StateError('no url');
      final e = Get.find<PlayerEngines>().audio();
      _engine = e;
      _subs
        ..add(e.position.listen((p) {
          position.value = p;
          final total = duration.value;
          if (!_completeSent && total.inSeconds > 0 && p.inSeconds >= total.inSeconds * .9) _markListened();
        }))
        ..add(e.duration.listen((d) {
          if (d != null) duration.value = d;
        }))
        ..add(e.playing.listen((v) => playing.value = v));
      final d = await e.open(UrlSource(u));
      duration.value = d ?? Duration(seconds: m.durationSec ?? 0);
    } catch (_) {
      _engine = null;
      audioError.value = true;
    } finally {
      audioLoading.value = false;
    }
  }

  void _markListened() {
    _completeSent = true;
    Get.find<AnalyticsService>().track('message_listened', {'date': message.value?.date ?? date});
    _repo.completeMessage(message.value!.date).catchError((_) {});
  }

  /// Play / pause the audio inline. Video opens the video player (a message is never counted as a meditation).
  Future<void> toggle() async {
    final m = message.value;
    if (m == null) return;
    if (videoMode.value && hasVideoMode) {
      Get.toNamed(AppRoutes.videoPlayer, arguments: PlayerArgs(
        kind: 'free', title: m.title, subtitle: 'Daily message', date: m.date, target: PlayDailyMessage(m.date, video: true), isVideo: true, record: false, mode: 'solo', durationSec: m.durationSec));
      return;
    }
    await _ensureAudio();
    final e = _engine;
    if (e == null) return;
    e.isPlaying ? await e.pause() : await e.play();
  }

  Future<void> seekTo(int sec) async {
    await _ensureAudio();
    final e = _engine;
    if (e == null) return;
    Get.find<AnalyticsService>().track('transcript_seek', {'date': message.value?.date ?? date, 't': sec});
    await e.seek(Duration(seconds: sec));
    if (!e.isPlaying) await e.play();
  }

  Future<void> skip(int sec) async {
    final e = _engine;
    if (e == null) return;
    final to = position.value + Duration(seconds: sec);
    await e.seek(to < Duration.zero ? Duration.zero : to);
  }

  Future<void> toggleSave() async {
    final m = message.value;
    if (m == null) return;
    final on = !m.saved;
    message.value = m.copyWith(saved: on);
    Get.find<AnalyticsService>().track('message_save', {'date': m.date, 't': 0});
    try {
      await _repo.saveMessage(m.date, on: on);
    } catch (_) {
      message.value = m; // not saved: put it back
    }
  }

  void share() {
    final m = message.value;
    if (m == null) return;
    SharePlus.instance.share(ShareParams(text: '${m.title} · a daily message from Raphael on WeHum. https://wehum.app'));
  }

  /// Old audio/video route, kept for deep links that open the full-screen player.
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
