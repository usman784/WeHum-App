import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/content.dart';
import '../data/models/json.dart';

/// The library (spec §6.2): stored in drift, refreshed only when `bootstrap.catalogVersion` changes or on socket
/// `catalog:changed`. Library, theme pages, filters and search run locally — no request per keystroke.
class CatalogService extends GetxService {
  CatalogService(this._repo, this._db);
  final CatalogRepository _repo;
  final AppDatabase _db;

  final catalog = Rxn<Catalog>();
  final syncing = false.obs;
  Object? lastError;

  int get version => catalog.value?.version ?? 0;

  /// Loads the stored snapshot first (instant, works offline), then the network if [serverVersion] is newer.
  Future<Catalog?> load({int? serverVersion}) async {
    if (catalog.value == null) {
      final stored = await _db.loadCatalog();
      if (stored != null) {
        try {
          catalog.value = Catalog.fromJson(asJson(jsonDecode(stored.json)));
        } catch (_) {/* corrupt snapshot: fall through to a fresh download */}
      }
    }
    if (serverVersion == null || serverVersion != version) await refresh();
    return catalog.value;
  }

  Future<void> refresh() async {
    if (syncing.value) return;
    syncing.value = true;
    try {
      final fresh = await _repo.catalog(knownVersion: catalog.value?.version);
      if (fresh != null) await _store(fresh);
      lastError = null;
    } catch (e) {
      lastError = e; // keep the stored copy; the library stays usable offline
    } finally {
      syncing.value = false;
    }
  }

  Future<void> _store(Catalog c) async {
    catalog.value = c;
    await _db.saveCatalog(
      version: c.version,
      json: jsonEncode(_toJson(c)),
      index: [for (final s in c.sessions) (id: s.id, title: s.title, tags: s.tags.join(' '), description: s.description ?? '')],
    );
  }

  /// Test/hydration hook.
  Future<void> seed(Catalog c) => _store(c);

  static Json _toJson(Catalog c) => {
        'version': c.version,
        'themes': [for (final t in c.themes) {'id': t.id, 'slug': t.slug, 'name': t.name, 'subtitle': t.subtitle, 'description': t.description, 'iconKey': t.iconKey, 'order': t.order}],
        'teachers': [
          for (final t in c.teachers)
            {'id': t.id, 'name': t.name, 'role': t.role, 'specialty': t.specialty, 'bio': t.bio, 'quote': t.quote, 'photoUrl': t.photoUrl, 'youtubeUrl': t.youtubeUrl, 'instagramUrl': t.instagramUrl, 'websiteUrl': t.websiteUrl}
        ],
        'sessions': [for (final s in c.sessions) s.toJson()],
        'programs': [
          for (final p in c.programs)
            {
              'id': p.id, 'slug': p.slug, 'title': p.title, 'description': p.description, 'access': p.access.name, 'unlockRule': p.unlockRule,
              'cover': p.cover == null ? null : {'url': p.cover!.url, 'blurhash': p.cover!.blurhash}, 'days': [for (final d in p.days) {'day': d.day, 'title': d.title, 'sessionId': d.sessionId}]
            }
        ],
        'soundBlocks': [for (final b in c.soundBlocks) {'id': b.id, 'kind': b.kind, 'name': b.name, 'durationSec': b.durationSec, 'loopable': b.loopable, 'access': b.access.name}],
        'sos': {
          'title': c.sos.title, 'subtitle': c.sos.subtitle, 'help': c.sos.help,
          'tiles': [
            for (final t in c.sos.tiles)
              {'sessionId': t.sessionId, 'feeling': t.feeling, 'subtitle': t.subtitle, 'durationSec': t.durationSec, 'access': t.access.name, 'cover': t.cover == null ? null : {'url': t.cover!.url, 'blurhash': t.cover!.blurhash}}
          ]
        },
      };

  // ───────────── local queries
  Future<List<SessionSummary>> search(String q) async {
    final c = catalog.value;
    if (c == null) return const [];
    final ids = await _db.searchIds(q);
    final byId = {for (final s in c.sessions) s.id: s};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  /// Filter by length (minutes ranges), teacher, type and theme — all local.
  List<SessionSummary> filter({String? themeId, Set<int> lengthBuckets = const {}, String? teacherId, String type = 'all', bool downloadedOnly = false, Set<String> downloadedIds = const {}}) {
    final c = catalog.value;
    if (c == null) return const [];
    bool lengthOk(SessionSummary s) {
      if (lengthBuckets.isEmpty) return true;
      final m = s.minutes;
      return lengthBuckets.any((b) => switch (b) { 10 => m <= 10, 20 => m > 10 && m <= 20, 30 => m > 20 && m <= 30, _ => m > 30 });
    }

    return c.sessions.where((s) {
      if (themeId != null && s.themeId != themeId) return false;
      if (teacherId != null && s.teacherId != teacherId) return false;
      if (!lengthOk(s)) return false;
      if (type == 'audio' && (s.isVideo || s.isYoutube)) return false;
      if (type == 'video' && !s.isVideo) return false;
      if (type == 'free' && s.isPremium) return false;
      if (downloadedOnly && !downloadedIds.contains(s.id)) return false;
      return true;
    }).toList();
  }

  /// "N meditations · 5–40 min" for a theme tile.
  String themeLine(ThemeInfo t) {
    final list = catalog.value?.inTheme(t.id) ?? const [];
    if (list.isEmpty) return 'Coming soon';
    final mins = list.map((s) => s.minutes).where((m) => m > 0).toList()..sort();
    final range = mins.isEmpty ? '' : (mins.first == mins.last ? ' · ${mins.first} min' : ' · ${mins.first}–${mins.last} min');
    return '${list.length} meditation${list.length == 1 ? '' : 's'}$range';
  }
}
