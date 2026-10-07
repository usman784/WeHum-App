import 'dart:convert';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/local/app_database.dart';
import '../data/models/activity.dart';
import '../data/models/json.dart';

/// In-app inbox (spec §12 #28): REST list, live `inbox:new`, cached in drift. The bell badge reads [unread].
class InboxService extends GetxService {
  InboxService(this._repo, this._db);
  final MeRepository _repo;
  final AppDatabase _db;

  final items = <InboxItem>[].obs;
  final loading = false.obs;
  final failed = false.obs;
  final unread = 0.obs;
  String? _cursor;
  bool get hasMore => _cursor != null;

  void _recount() => unread.value = items.where((i) => !i.read).length;

  Future<void> load() async {
    loading.value = true;
    failed.value = false;
    // cache first
    final cached = await _db.getCache('inbox');
    if (cached != null && items.isEmpty) {
      try {
        items.assignAll([for (final j in (jsonDecode(cached) as List)) InboxItem.fromJson(asJson(j))]);
        _recount();
      } catch (_) {}
    }
    try {
      final p = await _repo.inbox();
      items.assignAll(p.items);
      _cursor = p.nextCursor;
      _recount();
      await _db.putCache('inbox', jsonEncode([for (final i in p.items) {'id': i.id, 'type': i.type, 'title': i.title, 'body': i.body, 'deepLink': i.deepLink, 'createdAt': i.createdAt.toIso8601String(), 'read': i.read}]));
    } catch (_) {
      failed.value = items.isEmpty;
    } finally {
      loading.value = false;
    }
  }

  Future<void> more() async {
    if (_cursor == null) return;
    final p = await _repo.inbox(cursor: _cursor);
    items.addAll(p.items);
    _cursor = p.nextCursor;
    _recount();
  }

  /// Socket `inbox:new`.
  void onSocket(Map<String, dynamic> item) {
    try {
      final n = InboxItem.fromJson(item);
      if (items.any((i) => i.id == n.id)) return;
      items.insert(0, n);
      _recount();
    } catch (_) {}
  }

  Future<void> markRead(InboxItem i) async {
    if (i.read) return;
    final idx = items.indexWhere((x) => x.id == i.id);
    if (idx >= 0) items[idx] = i.asRead();
    _recount();
    try {
      await _repo.markRead(ids: [i.id]);
    } catch (_) {/* shown as read here; the server catches up on the next open */}
  }

  Future<void> markAllRead() async {
    for (var k = 0; k < items.length; k++) {
      items[k] = items[k].asRead();
    }
    _recount();
    try {
      await _repo.markRead(all: true);
    } catch (_) {}
  }
}
