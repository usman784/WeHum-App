import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/routes/app_routes.dart';
import '../../core/audio/recipe_plan.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/activity.dart';
import '../../core/data/models/content.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/widgets/states.dart';
import '../player/player_args.dart';

/// 39 Build your own (and 40 advanced): four choices, a timeline summary, Build it / Save. Sounds come from the catalog's
/// sound blocks; an option whose sound is missing is disabled (spec §12 #39).
class ByoController extends GetxController {
  late final CatalogService catalog = Get.find();
  late final RecipeRepository _repo = Get.find();

  final length = 15.obs;
  final openingId = RxnString();
  final soundId = RxnString();
  final soundLevel = 50.obs;
  final texture = 'simple'.obs;
  final bellStart = true.obs;
  final bellEnd = true.obs;
  final bellInterval = 0.obs;
  final name = ''.obs;
  final blocks = <Map<String, dynamic>>[].obs; // advanced: {type: block, blockId, count} | {type: silence}
  final shareUrl = RxnString();
  final busy = false.obs;
  final message = RxnString();
  final state = ViewState.content.obs;
  String? editingId;

  static const lengths = [5, 10, 15, 20, 30, 45, 60];
  static const intervals = [0, 5, 10, 15, 30];

  Catalog? get c => catalog.catalog.value;
  List<SoundBlock> get openings => c?.soundBlocks.where((b) => b.kind == 'opening').toList() ?? const [];
  List<SoundBlock> get sounds => c?.soundBlocks.where((b) => b.kind == 'sound').toList() ?? const [];
  List<SoundBlock> get advancedBlocks => c?.soundBlocks.where((b) => b.kind != 'opening' && b.kind != 'sound').toList() ?? const [];
  SoundBlock? block(String? id) => id == null ? null : c?.soundBlocks.where((b) => b.id == id).firstOrNull;

  Recipe get recipe => Recipe(
        id: editingId ?? '', name: name.value.trim().isEmpty ? 'My meditation' : name.value.trim(), lengthMin: length.value, openingId: openingId.value, soundId: soundId.value,
        soundLevel: soundLevel.value, texture: texture.value, bells: RecipeBells(start: bellStart.value, end: bellEnd.value, intervalMin: bellInterval.value), blocks: List.of(blocks), shareSlug: null);

  String get summary => RecipePlan.summary(recipe, c);

  /// The timeline for the sticky summary: seconds of voice vs silence.
  RecipePlan? get plan => c == null ? null : RecipePlan.build(recipe, c!);

  /// Prefills from a shared link (`wehum.app/r/{slug}`) or a saved recipe.
  void load(Recipe r) {
    editingId = r.id.isEmpty ? null : r.id;
    name.value = r.name;
    length.value = r.lengthMin;
    openingId.value = r.openingId;
    soundId.value = r.soundId;
    soundLevel.value = r.soundLevel;
    texture.value = r.texture;
    bellStart.value = r.bells.start;
    bellEnd.value = r.bells.end;
    bellInterval.value = r.bells.intervalMin;
    blocks.assignAll(r.blocks);
    shareUrl.value = r.shareUrl;
  }

  Future<void> loadShared(String slug) async {
    state.value = ViewState.loading;
    try {
      load(await _repo.shared(slug));
      editingId = null; // a copy
      state.value = ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  // advanced block list
  void addBlock(String blockId) => blocks.add({'type': 'block', 'blockId': blockId, 'count': 1});
  void addSilence() => blocks.add({'type': 'silence'});
  void removeAt(int i) => blocks.removeAt(i);
  /// [to] is already adjusted for the removed item (ReorderableListView.onReorderItem).
  void reorder(int from, int to) {
    final x = blocks.removeAt(from);
    blocks.insert(to, x);
  }

  void setCount(int i, int n) {
    final e = Map<String, dynamic>.of(blocks[i]);
    e['count'] = n.clamp(1, 21);
    blocks[i] = e;
  }

  void build() {
    Get.find<AnalyticsService>().track('byo_build', {'length': length.value, 'blocks': blocks.length});
    play(recipe);
  }

  static void play(Recipe r) => Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'custom', title: r.name, subtitle: 'Your own meditation', recipe: r, durationSec: r.lengthMin * 60, lengthMin: r.lengthMin));

  /// Saves (or updates) the recipe on the server so it appears in My Meditations on every device.
  Future<bool> save(String recipeName) async {
    busy.value = true;
    message.value = null;
    name.value = recipeName;
    try {
      final r = recipe;
      final saved = editingId == null ? await _repo.create(r) : await _repo.update(editingId!, r.toJson());
      editingId = saved.id;
      Get.find<AnalyticsService>().track('byo_save', {'length': length.value, 'blocks': blocks.length});
      return true;
    } catch (_) {
      message.value = 'Couldn’t save. Check your connection and try again.';
      return false;
    } finally {
      busy.value = false;
    }
  }

  Future<void> share() async {
    if (editingId == null && !await save(name.value.isEmpty ? 'My meditation' : name.value)) return;
    try {
      shareUrl.value = await _repo.share(editingId!);
      Get.find<AnalyticsService>().track('byo_share');
      await SharePlus.instance.share(ShareParams(text: shareUrl.value!));
    } catch (_) {
      message.value = 'Couldn’t create the link. Try again later.';
    }
  }
}

/// 38 My Meditations.
class MyMeditationsController extends GetxController {
  late final RecipeRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final items = <Recipe>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      items.assignAll(await _repo.list());
      state.value = items.isEmpty ? ViewState.empty : ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  Future<void> delete(Recipe r) async {
    items.removeWhere((x) => x.id == r.id);
    if (items.isEmpty) state.value = ViewState.empty;
    try {
      await _repo.delete(r.id);
    } catch (_) {
      await load(); // not deleted on the server: show it again
    }
  }

  void play(Recipe r) {
    Get.find<AnalyticsService>().track('byo_play', {'length': r.lengthMin, 'blocks': r.blocks.length});
    ByoController.play(r);
  }
}
