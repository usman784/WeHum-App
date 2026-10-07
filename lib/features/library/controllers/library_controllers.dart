import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/local/app_database.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/content.dart';
import '../../../core/data/models/today.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/play_launcher.dart';
import '../../../core/widgets/states.dart';
import '../../today/controllers/today_controller.dart';

/// Filter choices (sheet 33). Applied locally to the catalog snapshot.
class LibraryFilters {
  const LibraryFilters({this.lengths = const {}, this.teacherId, this.type = 'all', this.downloadedOnly = false});
  final Set<int> lengths; // buckets: 10 (≤10), 20 (11–20), 30 (21–30), 45 (> 30)
  final String? teacherId;
  final String type; // all | audio | video | free
  final bool downloadedOnly;
  bool get active => lengths.isNotEmpty || teacherId != null || type != 'all' || downloadedOnly;
  LibraryFilters copyWith({Set<int>? lengths, Object? teacherId = _keep, String? type, bool? downloadedOnly}) =>
      LibraryFilters(lengths: lengths ?? this.lengths, teacherId: identical(teacherId, _keep) ? this.teacherId : teacherId as String?, type: type ?? this.type, downloadedOnly: downloadedOnly ?? this.downloadedOnly);
  static const _keep = Object();
}

/// 31 Library, 32 Theme page, 33 filters — all read the local catalog.
class LibraryController extends GetxController {
  late final CatalogService catalog = Get.find();
  late final DownloadService downloads = Get.find();
  late final AccessService access = Get.find();

  final state = ViewState.loading.obs;
  final filters = const LibraryFilters().obs;
  final programCard = Rxn<ProgramCard>();
  final recipeCount = 0.obs;

  Catalog? get c => catalog.catalog.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    state.value = c == null ? ViewState.loading : ViewState.content;
    await catalog.load();
    state.value = c == null ? (catalog.lastError != null ? ViewState.fromError(catalog.lastError!) : ViewState.empty) : ViewState.content;
    try {
      programCard.value = (await Get.find<TodayRepository>().today(localDate())).program;
    } catch (_) {}
    try {
      recipeCount.value = (await Get.find<RecipeRepository>().list()).length;
    } catch (_) {}
  }

  Set<String> get downloadedIds => downloads.downloadedIds;

  List<SessionSummary> get filtered => catalog.filter(
        lengthBuckets: filters.value.lengths, teacherId: filters.value.teacherId, type: filters.value.type, downloadedOnly: filters.value.downloadedOnly, downloadedIds: downloadedIds);

  /// "Show N meditations" in the filter sheet, live as choices change.
  int countFor(LibraryFilters f) => catalog.filter(lengthBuckets: f.lengths, teacherId: f.teacherId, type: f.type, downloadedOnly: f.downloadedOnly, downloadedIds: downloadedIds).length;

  /// Free users: the free items are "Free for you"; members see them without a label (spec §1.3).
  List<SessionSummary> get freeItems => c?.sessions.where((s) => !s.isPremium).toList() ?? const [];
  List<SessionSummary> get premiumItems => c?.sessions.where((s) => s.isPremium).toList() ?? const [];

  void applyFilters(LibraryFilters f) {
    filters.value = f;
    Get.find<AnalyticsService>().track('library_filter_apply', {'filters': [if (f.lengths.isNotEmpty) 'length', if (f.teacherId != null) 'teacher', if (f.type != 'all') 'type', if (f.downloadedOnly) 'downloaded'].join(',')});
  }

  void resetFilters() => filters.value = const LibraryFilters();
  void open(SessionSummary s) => openSession(s.id);
  void play(SessionSummary s) => launchSession(s);
  void goSilence() => access.isMember ? Get.toNamed(AppRoutes.silenceRoomSetup) : Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'lock'});
}

/// 32 Theme page: All / Premium / Online library / Video.
class ThemeScreenController extends GetxController {
  ThemeScreenController(this.themeId);
  final String themeId;
  late final CatalogService catalog = Get.find();
  final tab = 'all'.obs;

  ThemeInfo? get theme => catalog.catalog.value?.theme(themeId);
  List<SessionSummary> get items {
    final all = catalog.catalog.value?.inTheme(themeId) ?? const <SessionSummary>[];
    return switch (tab.value) {
      'premium' => all.where((s) => s.isPremium).toList(),
      'online' => all.where((s) => !s.isPremium).toList(),
      'video' => all.where((s) => s.isVideo).toList(),
      _ => all,
    };
  }

  String get subtitle => '${theme?.subtitle ?? ''}${theme?.subtitle == null ? '' : ' · '}${catalog.catalog.value?.inTheme(themeId).length ?? 0} meditations';
}

/// 34 Search: debounced 300 ms, local FTS5, recent searches.
class LibrarySearchController extends GetxController {
  late final CatalogService catalog = Get.find();
  late final AppDatabase _db = Get.find();
  final q = ''.obs;
  final results = <SessionSummary>[].obs;
  final messages = <DailyMessage>[].obs;
  final recent = <String>[].obs;
  /// The query the shown results belong to; the page shows nothing until the debounce has produced them.
  final doneFor = ''.obs;
  final lengths = <int>{}.obs;
  final type = 'all'.obs;
  Worker? _d;

  @override
  void onInit() {
    super.onInit();
    _loadRecent();
    _d = debounce(q, _run, time: const Duration(milliseconds: 300));
  }

  @override
  void onClose() {
    _d?.dispose();
    super.onClose();
  }

  Future<void> _loadRecent() async {
    final raw = await _db.getCache('search_recent');
    if (raw != null) recent.assignAll((jsonDecode(raw) as List).cast<String>());
  }

  Future<void> _run(String text) async {
    final query = text.trim();
    if (query.isEmpty) {
      results.clear();
      messages.clear();
      doneFor.value = '';
      return;
    }
    var r = await catalog.search(query);
    r = r.where((s) => lengths.isEmpty || lengths.any((b) => switch (b) { 10 => s.minutes <= 10, 20 => s.minutes > 10 && s.minutes <= 20, 30 => s.minutes > 20 && s.minutes <= 30, _ => s.minutes > 30 })).toList();
    r = r.where((s) => type.value == 'all' || (type.value == 'video' ? s.isVideo : (type.value == 'free' ? !s.isPremium : !s.isVideo && !s.isYoutube))).toList();
    results.assignAll(r);
    Get.find<AnalyticsService>().track('search', {'query_len': query.length, 'results': r.length});
    // daily messages (members): the archive search
    if (Get.find<AccessService>().isMember) {
      try {
        messages.assignAll((await Get.find<TodayRepository>().archive(q: query)).items);
      } catch (_) {
        messages.clear();
      }
    }
    doneFor.value = query;
  }

  Future<void> remember() async {
    final t = q.value.trim();
    if (t.isEmpty) return;
    recent.remove(t);
    recent.insert(0, t);
    if (recent.length > 8) recent.removeRange(8, recent.length);
    await _db.putCache('search_recent', jsonEncode(recent));
  }

  Future<void> clearRecent() async {
    recent.clear();
    await _db.putCache('search_recent', '[]');
  }

  Future<void> refilter() => _run(q.value);
}

/// 35 All programs / 36 Program detail.
class ProgramsController extends GetxController {
  late final CatalogService catalog = Get.find();
  final progress = <String, Program>{}.obs;

  @override
  void onReady() {
    super.onReady();
    for (final p in catalog.catalog.value?.programs ?? const <Program>[]) {
      Get.find<CatalogRepository>().program(p.id).then((d) => progress[p.id] = d).catchError((_) => p);
    }
  }

  List<Program> get inProgress => [for (final p in catalog.catalog.value?.programs ?? const <Program>[]) if (progress[p.id]?.started ?? false) progress[p.id]!];
  List<Program> get available => [for (final p in catalog.catalog.value?.programs ?? const <Program>[]) if (!(progress[p.id]?.started ?? false)) p];
}

class ProgramDetailController extends GetxController {
  ProgramDetailController(this.id);
  final String id;
  final state = ViewState.loading.obs;
  final program = Rxn<Program>();
  final busy = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      program.value = await Get.find<CatalogRepository>().program(id);
      state.value = ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  /// Day statuses: done / today (the current day) / locked. No rest days.
  String statusOf(int day) {
    final p = program.value?.progress;
    if (p == null) return day == 1 ? 'today' : 'locked';
    if (p.completedDays.contains(day)) return 'done';
    return day == p.currentDay ? 'today' : (day < p.currentDay ? 'open' : 'locked');
  }

  int get currentDay => program.value?.progress?.currentDay ?? 1;
  int get doneCount => program.value?.progress?.completedDays.length ?? 0;
  double get fraction => (program.value == null || program.value!.days.isEmpty) ? 0 : doneCount / program.value!.days.length;

  Future<void> startDay() async {
    final p = program.value;
    if (p == null) return;
    if (p.access == Access.premium && !Get.find<AccessService>().isMember) {
      Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'lock'});
      return;
    }
    busy.value = true;
    try {
      if (!p.started) program.value = await Get.find<ProgramRepository>().start(id);
    } catch (_) {/* playing still works; the next open syncs */}
    busy.value = false;
    final day = program.value?.days.where((d) => d.day == currentDay).firstOrNull;
    final s = day?.session;
    if (s != null) launchSession(s, kind: 'program', programId: id, programDay: day!.day);
  }
}
