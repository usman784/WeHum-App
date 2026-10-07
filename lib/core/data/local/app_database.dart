import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// `catalog_meta`: version, etag, fetchedAt, and the snapshot itself as JSON (≈150 KB).
class CatalogMeta extends Table {
  IntColumn get id => integer()();
  IntColumn get version => integer()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();
  TextColumn get json => text()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Meditations finished while offline, sent FIFO by SyncService (uuid v7 ids, idempotent on the server).
class OutboxMeditations extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class Downloads extends Table {
  TextColumn get sessionId => text()();
  /// 0 for ordinary sessions, 10/30/45 for MOTD variants.
  IntColumn get variant => integer().withDefault(const Constant(0))();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get filePath => text().nullable()();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get expiresAt => dateTime().nullable()();
  /// queued | running | paused | done | failed
  TextColumn get status => text().withDefault(const Constant('queued'))();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {sessionId, variant};
}

/// Dedication holds/reports queued while offline (posting needs the server's eligibility check, so it is never queued).
class PendingActions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Generic JSON cache: `today:{date}`, `progress:{period}`, `inbox`, `recipes`, `sos`, `search_recent`.
class KvCache extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get savedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [CatalogMeta, OutboxMeditations, Downloads, PendingActions, KvCache])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  static Future<AppDatabase> open() async {
    final dir = await getApplicationDocumentsDirectory();
    return AppDatabase(NativeDatabase.createInBackground(File(p.join(dir.path, 'wehum.sqlite'))));
  }

  static AppDatabase memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _createFts();
        },
        beforeOpen: (d) async => _createFts(),
      );

  /// FTS5 over title/tags/description: library search runs locally, no request per keystroke (spec §6.2).
  Future<void> _createFts() => customStatement(
      "CREATE VIRTUAL TABLE IF NOT EXISTS session_fts USING fts5(id UNINDEXED, title, tags, description, tokenize = 'unicode61 remove_diacritics 2')");

  // ───────────── catalog snapshot
  Future<void> saveCatalog({required int version, required String json, String? etag, required List<({String id, String title, String tags, String description})> index}) async {
    await transaction(() async {
      await into(catalogMeta).insertOnConflictUpdate(CatalogMetaCompanion.insert(id: const Value(1), version: version, etag: Value(etag), fetchedAt: DateTime.now(), json: json));
      await customStatement('DELETE FROM session_fts');
      for (final r in index) {
        await customInsert('INSERT INTO session_fts (id, title, tags, description) VALUES (?, ?, ?, ?)',
            variables: [Variable(r.id), Variable(r.title), Variable(r.tags), Variable(r.description)]);
      }
    });
  }

  Future<CatalogMetaData?> loadCatalog() => (select(catalogMeta)..where((t) => t.id.equals(1))).getSingleOrNull();

  /// Ids matching [query] (prefix match on every word), best first.
  Future<List<String>> searchIds(String query, {int limit = 50}) async {
    final words = query.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final match = words.map((w) => '"$w"*').join(' ');
    final rows = await customSelect('SELECT id FROM session_fts WHERE session_fts MATCH ? ORDER BY rank LIMIT ?', variables: [Variable(match), Variable(limit)]).get();
    return [for (final r in rows) r.read<String>('id')];
  }

  // ───────────── outbox
  Future<void> enqueueMeditation(String id, String payload) => into(outboxMeditations).insertOnConflictUpdate(OutboxMeditationsCompanion.insert(id: id, payload: payload, createdAt: DateTime.now()));
  Future<List<OutboxMeditation>> outboxBatch({int limit = 50}) => (select(outboxMeditations)..orderBy([(t) => OrderingTerm.asc(t.createdAt)])..limit(limit)).get();
  Future<void> outboxDone(Iterable<String> ids) => (delete(outboxMeditations)..where((t) => t.id.isIn(ids))).go();
  Future<void> outboxFailed(String id, String error) =>
      (update(outboxMeditations)..where((t) => t.id.equals(id))).write(OutboxMeditationsCompanion.custom(attempts: outboxMeditations.attempts + const Constant(1), lastError: Variable(error)));
  Future<int> outboxCount() async => (await select(outboxMeditations).get()).length;

  // ───────────── downloads
  Future<void> upsertDownload(DownloadsCompanion d) => into(downloads).insertOnConflictUpdate(d);
  Future<List<Download>> allDownloads() => (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  Stream<List<Download>> watchDownloads() => (select(downloads)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  Future<Download?> downloadFor(String sessionId, [int variant = 0]) => (select(downloads)..where((t) => t.sessionId.equals(sessionId) & t.variant.equals(variant))).getSingleOrNull();
  Future<void> removeDownload(String sessionId, [int variant = 0]) => (delete(downloads)..where((t) => t.sessionId.equals(sessionId) & t.variant.equals(variant))).go();
  Future<void> clearDownloads() => delete(downloads).go();

  // ───────────── pending actions
  Future<void> addPending(String type, String payload) => into(pendingActions).insert(PendingActionsCompanion.insert(type: type, payload: payload, createdAt: DateTime.now()));
  Future<List<PendingAction>> pending() => (select(pendingActions)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
  Future<void> removePending(int id) => (delete(pendingActions)..where((t) => t.id.equals(id))).go();

  // ───────────── kv cache
  Future<void> putCache(String key, String json) => into(kvCache).insertOnConflictUpdate(KvCacheCompanion.insert(key: key, json: json, savedAt: DateTime.now()));
  Future<String?> getCache(String key) async => (await (select(kvCache)..where((t) => t.key.equals(key))).getSingleOrNull())?.json;
  Future<void> clearAllUserData() async {
    await transaction(() async {
      await delete(kvCache).go();
      await delete(outboxMeditations).go();
      await delete(pendingActions).go();
    });
  }
}
