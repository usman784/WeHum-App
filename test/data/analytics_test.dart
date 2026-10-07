import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/data/local/app_database.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/json.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/services/analytics_service.dart';

class FlakyRepo extends MockAnalyticsRepository {
  Object? fail;
  int calls = 0;
  @override
  Future<void> send(List<Json> events) async {
    calls++;
    if (fail != null) throw fail!;
    await super.send(events);
  }
}

void main() {
  setUp(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  test('flushes at 20 events, in batches of at most 50', () async {
    final repo = FlakyRepo();
    final a = AnalyticsService(repo: repo);
    for (var i = 0; i < 19; i++) {
      a.track('x_$i');
    }
    expect(repo.calls, 0);
    a.track('x_19'); // the 20th
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(repo.sent.length, 20);
    for (var i = 0; i < 120; i++) {
      a.track('y_$i');
    }
    await a.flush();
    expect(repo.sent.length, 140);
    expect(a.pending, 0);
  });

  test('every 30 s and when the app goes to the background', () {
    fakeAsync((fa) {
      final repo = FlakyRepo();
      final a = AnalyticsService(repo: repo);
      a.start();
      fa.flushMicrotasks();
      a.track('app_open');
      fa.elapse(const Duration(seconds: 29));
      expect(repo.sent, isEmpty);
      fa.elapse(const Duration(seconds: 2));
      expect(repo.sent.map((e) => e['name']), ['app_open']);
      a.track('paywall_view');
      a.onBackground();
      fa.flushMicrotasks();
      expect(repo.sent.length, 2);
    });
  });

  test('offline keeps the events; a rejected batch (validation) is dropped so it cannot block the queue', () async {
    final repo = FlakyRepo()..fail = ApiException(ErrorCode.network);
    final a = AnalyticsService(repo: repo);
    a.track('a');
    a.track('b');
    await a.flush();
    expect(a.pending, 2);
    repo.fail = ApiException(ErrorCode.validationFailed, status: 400);
    await a.flush();
    expect(a.pending, 0);
    repo.fail = null;
    a.track('c');
    await a.flush();
    expect(repo.sent.map((e) => e['name']), ['c']);
  });

  test('timestamps follow the server-synced clock; props are cleaned to what the API accepts; user_props has no personal data', () async {
    final repo = FlakyRepo();
    final a = AnalyticsService(repo: repo)..serverClock = (() => DateTime.utc(2026, 10, 7, 12, 0, 3));
    a.track('x', {'n': 3, 'ok': true, 'none': null, 'list': ['a', 'b'], 'long': 'z' * 500, 'obj': Object()});
    a.userProps(plan: 'trial', isGuest: false, country: 'DE', theme: 'dark', flavor: 'prod');
    await a.flush();
    final e = repo.sent.first;
    expect(e['at'], '2026-10-07T12:00:03.000Z');
    final p = e['props'] as Map;
    expect(p['list'], 'a,b');
    expect((p['long'] as String).length, 200);
    expect(p['n'], 3);
    expect(p['obj'], startsWith('Instance of'));
    final up = repo.sent.last;
    expect(up['name'], 'user_props');
    expect((up['props'] as Map).keys, unorderedEquals(['plan', 'is_guest', 'country', 'theme', 'flavor']));
  });

  test('the queue survives an app restart (drift) and is capped', () async {
    final db = AppDatabase.memory();
    final first = AnalyticsService(repo: FlakyRepo()..fail = ApiException(ErrorCode.network), db: db);
    first.track('before_restart');
    await first.flush(); // persists on the way out
    final repo = FlakyRepo();
    final second = AnalyticsService(repo: repo, db: db);
    await second.start();
    await second.flush();
    expect(repo.sent.map((e) => e['name']), ['before_restart']);
    final capped = AnalyticsService(maxQueue: 5, flushAt: 1000);
    for (var i = 0; i < 12; i++) {
      capped.track('e$i');
    }
    expect(capped.pending, 5);
    expect(capped.drain().first['name'], 'e7'); // the oldest are dropped
    await db.close();
  });
}
