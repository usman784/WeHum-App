import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/local/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.memory());
  tearDown(() => db.close());

  test('catalog snapshot round-trips and FTS5 finds prefixes, tags and accents', () async {
    await db.saveCatalog(version: 7, json: '{"v":7}', etag: 'e1', index: [
      (id: 'a', title: 'Steady Under Pressure', tags: 'stress grounding', description: 'A calm start'),
      (id: 'b', title: 'Sink Into Sleep', tags: 'sleep', description: 'Let the day dissolve'),
      (id: 'c', title: 'Müde Nächte', tags: 'schlaf', description: 'Deutsch'),
    ]);
    final c = await db.loadCatalog();
    expect(c!.version, 7);
    expect(c.json, '{"v":7}');
    expect(await db.searchIds('pres'), ['a']); // prefix
    expect(await db.searchIds('SLEEP'), ['b']); // case + tag
    expect(await db.searchIds('dissolve day'), ['b']); // description, two words
    expect(await db.searchIds('mude'), ['c']); // diacritics
    expect(await db.searchIds('   '), isEmpty);
    expect(await db.searchIds('zzz'), isEmpty);
    // a new snapshot replaces the index
    await db.saveCatalog(version: 8, json: '{}', index: [(id: 'z', title: 'Only One', tags: '', description: '')]);
    expect(await db.searchIds('steady'), isEmpty);
    expect(await db.searchIds('only'), ['z']);
  });

  test('outbox is FIFO, idempotent per id, counts attempts', () async {
    await db.enqueueMeditation('m1', '{"id":"m1"}');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await db.enqueueMeditation('m2', '{"id":"m2"}');
    await db.enqueueMeditation('m1', '{"id":"m1","again":true}'); // same id → one row
    expect(await db.outboxCount(), 2);
    expect((await db.outboxBatch()).map((r) => r.id), ['m1', 'm2']);
    await db.outboxFailed('m1', 'NETWORK');
    expect((await db.outboxBatch()).first.attempts, 1);
    await db.outboxDone(['m1']);
    expect((await db.outboxBatch()).map((r) => r.id), ['m2']);
  });

  test('downloads are per variant; pending actions keep order; cache and wipe', () async {
    await db.upsertDownload(DownloadsCompanion.insert(sessionId: 's1', createdAt: DateTime.now(), variant: const Value(10)));
    await db.upsertDownload(DownloadsCompanion.insert(sessionId: 's1', createdAt: DateTime.now(), variant: const Value(30), status: const Value('done')));
    expect((await db.downloadFor('s1', 10))!.status, 'queued');
    expect((await db.downloadFor('s1', 30))!.status, 'done');
    await db.removeDownload('s1', 10);
    expect(await db.downloadFor('s1', 10), isNull);
    await db.addPending('hold', '{"id":"d1"}');
    await db.addPending('report', '{"id":"d2"}');
    expect((await db.pending()).map((p) => p.type), ['hold', 'report']);
    await db.putCache('today:2026-10-07', '{}');
    expect(await db.getCache('today:2026-10-07'), '{}');
    await db.clearAllUserData();
    expect(await db.getCache('today:2026-10-07'), isNull);
    expect(await db.pending(), isEmpty);
    expect((await db.downloadFor('s1', 30)), isNotNull); // downloads survive a sign-out (spec §10)
  });
}
