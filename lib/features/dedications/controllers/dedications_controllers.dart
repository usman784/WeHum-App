import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/local/app_database.dart';
import '../../../core/data/models/content.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/realtime/socket_events.dart';
import '../../../core/realtime/socket_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/widgets/states.dart';

/// Links are blocked client-side too (the server rejects them with DEDICATION_LINKS).
final _linkRe = RegExp(r'(https?:\/\/|www\.|\b[a-z0-9-]+\.(com|net|org|io|app|me|co|de|ly|gl)\b|@\w{2,})', caseSensitive: false);
bool hasLink(String t) => _linkRe.hasMatch(t);

const dedicationSuggestions = ['For my family', 'For someone who is unwell', 'For peace in the world', 'For a hard week ahead'];

enum PostOutcome { posted, pending, accountRequired, premiumRequired, limit, links, failed }

/// 47 Write a dedication (only from the finished meditation, with its `meditationId`).
class DedicationComposerController extends GetxController {
  DedicationComposerController({required this.meditationId, required this.sessionId, required this.leftToday});
  final String meditationId, sessionId;
  final text = ''.obs;
  final int leftToday;
  final busy = false.obs;
  final error = RxnString();
  final showHelp = false.obs;
  late final left = leftToday.obs;

  int get count => text.value.trim().length;
  bool get valid => count > 0 && count <= 200 && !hasLink(text.value) && left.value > 0;

  String? get inlineError {
    if (error.value != null) return error.value;
    if (count > 200) return 'At most 200 characters';
    if (hasLink(text.value)) return 'Text only, no links';
    if (left.value <= 0) return 'You’ve used today’s dedications. Come back tomorrow.';
    return null;
  }

  void suggest(String s) => text.value = s;

  Future<PostOutcome> post() async {
    if (!valid || busy.value) return PostOutcome.failed;
    busy.value = true;
    error.value = null;
    try {
      final r = await Get.find<CommunityRepository>().post(meditationId: meditationId, text: text.value.trim());
      left.value = r.leftToday;
      showHelp.value = r.showHelp;
      Get.find<AnalyticsService>().track('dedication_post', {'session_id': sessionId});
      return r.status == 'visible' ? PostOutcome.posted : PostOutcome.pending;
    } on ApiException catch (e) {
      switch (e.code) {
        case ErrorCode.accountRequired:
          return PostOutcome.accountRequired;
        case ErrorCode.premiumRequired:
          return PostOutcome.premiumRequired;
        case ErrorCode.dedicationLimit:
          error.value = 'You’ve used today’s dedications. Come back tomorrow.';
          left.value = 0;
          return PostOutcome.limit;
        case ErrorCode.dedicationLinks:
          error.value = 'Text only, no links';
          return PostOutcome.links;
        case ErrorCode.muted:
          error.value = 'You can’t post right now.';
          return PostOutcome.failed;
        default:
          error.value = e.code == ErrorCode.network || e.code == ErrorCode.timeout ? 'You’re offline. Posting needs a connection.' : 'Couldn’t post. Please try again.';
          return PostOutcome.failed;
      }
    } finally {
      busy.value = false;
    }
  }
}

/// 48 Session dedications: everyone reads; live new ones (< 2 s), holding counts, removals; hold/report/block.
class DedicationsController extends GetxController {
  DedicationsController(this.sessionId, {this.canCompose = false});
  final String sessionId;
  final bool canCompose;
  late final CommunityRepository _repo = Get.find();
  late final SocketService _socket = Get.find();
  late final LiveService live = Get.find();
  late final AppDatabase _db = Get.find();

  final state = ViewState.loading.obs;
  final items = <Dedication>[].obs;
  final loadingMore = false.obs;
  final total = 0.obs;
  String? _cursor;
  final _subs = <StreamSubscription<dynamic>>[];
  final _holdTimers = <String, Timer>{};
  final _blocked = <String>{};

  bool get hasMore => _cursor != null;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onReady() {
    super.onReady();
    live.acquireSession(sessionId); // `session:{id}` room → dedication:new/holding/removed
    _subs.add(_socket.on(SocketEvents.dedicationNew, (j) => j).listen(_onNew));
    _subs.add(_socket.on(SocketEvents.dedicationHolding, (j) => j).listen((j) => _setHolding(j['id'] as String, (j['holdingCount'] as num).toInt())));
    _subs.add(_socket.on(SocketEvents.dedicationRemoved, (j) => j).listen((j) {
      items.removeWhere((d) => d.id == j['id']);
      total.value = items.length;
      if (items.isEmpty) state.value = ViewState.empty; // the last one was taken down: the empty state, not "0 dedications"
    }));
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final t in _holdTimers.values) {
      t.cancel();
    }
    live.releaseSession(sessionId);
    super.onClose();
  }

  Future<void> load() async {
    state.value = ViewState.loading;
    try {
      final p = await _repo.dedications(sessionId);
      items.assignAll(p.items);
      _cursor = p.nextCursor;
      total.value = items.length;
      state.value = items.isEmpty ? ViewState.empty : ViewState.content;
      unawaited(Get.find<SyncService>().flush()); // holds / reports queued while offline
    } catch (e) {
      state.value = ViewState.fromError(e); // "Dedications will load when you're back"
    }
  }

  Future<void> more() async {
    if (_cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    try {
      final p = await _repo.dedications(sessionId, cursor: _cursor);
      items.addAll(p.items);
      _cursor = p.nextCursor;
    } finally {
      loadingMore.value = false;
    }
  }

  /// `dedication:new { sessionId, items: [...] }` (throttled and batched by the server).
  void _onNew(Map<String, dynamic> j) {
    if (j['sessionId'] != sessionId) return;
    for (final raw in (j['items'] as List? ?? const [])) {
      final d = Dedication.fromJson((raw as Map).cast<String, dynamic>());
      if (items.any((x) => x.id == d.id) || _blocked.contains(d.id)) continue;
      items.insert(0, d);
    }
    total.value = items.length;
    if (state.value.kind != ViewKind.content) state.value = ViewState.content;
  }

  void _setHolding(String id, int n) {
    final i = items.indexWhere((d) => d.id == id);
    if (i >= 0) items[i] = items[i].copyWith(holdingCount: n);
  }

  /// "Holding this · N": tap toggles at once; the request is debounced (a double tap sends one) and queued when offline.
  void toggleHold(Dedication d) {
    final i = items.indexWhere((x) => x.id == d.id);
    if (i < 0) return;
    final on = !items[i].heldByMe;
    items[i] = items[i].copyWith(heldByMe: on, holdingCount: items[i].holdingCount + (on ? 1 : -1));
    _holdTimers[d.id]?.cancel();
    _holdTimers[d.id] = Timer(const Duration(milliseconds: 400), () async {
      try {
        final n = await _repo.hold(d.id, on);
        _setHolding(d.id, n);
      } catch (_) {
        await _db.addPending('hold', jsonEncode({'id': d.id, 'on': on})); // sent when the connection is back (SyncService)
      }
    });
  }

  Future<bool> report(Dedication d, String reason, {bool block = false}) async {
    try {
      try {
        await _repo.report(d.id, reason: reason, block: block);
      } on ApiException catch (e) {
        if (e.code != ErrorCode.network && e.code != ErrorCode.timeout) rethrow;
        await _db.addPending('report', jsonEncode({'id': d.id, 'reason': reason, 'block': block})); // offline: queued, hidden at once
      }
      items.removeWhere((x) => x.id == d.id); // "You won't see this post again"
      _blocked.add(d.id);
      total.value = items.length;
      Get.find<AnalyticsService>()
        ..track('dedication_report', {'session_id': sessionId})
        ..track(block ? 'user_block' : 'dedication_report', {'session_id': sessionId});
      return true;
    } catch (_) {
      return false;
    }
  }
}

const reportReasons = <(String, String)>[('spam', 'Spam or advertising'), ('abusive', 'Abusive or hateful'), ('self_harm', 'Someone may be in danger'), ('personal_info', 'Personal information'), ('other', 'Something else')];
