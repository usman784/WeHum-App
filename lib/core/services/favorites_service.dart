import 'package:get/get.dart';
import '../data/contracts/repositories.dart';
import '../data/models/content.dart';
import '../errors/error_code.dart';
import 'access_service.dart';

enum FavoriteOutcome { added, removed, needsMembership, failed }

/// The member's favourite meditations (newest first): the heart on a meditation and the Favourites list in You.
///
/// Favourites are a membership feature. A free user never gets a favourite: [toggle] answers [FavoriteOutcome.needsMembership]
/// (the screen opens the paywall) and nothing is sent. The server enforces the same rule.
class FavoritesService extends GetxService {
  FavoritesService(this._repo, this._access);
  final FavoritesRepository _repo;
  final AccessService _access;

  /// Newest first. Reading this inside an `Obx` makes the widget follow every change.
  final items = <SessionSummary>[].obs;
  final loaded = false.obs;
  /// The last read failed (offline, server error): the Favourites screen offers a retry instead of waiting forever.
  final failed = false.obs;
  bool _loading = false;
  int _changes = 0; // bumped by every toggle, so a read that started earlier never overwrites a newer change
  final _workers = <Worker>[];

  @override
  void onInit() {
    super.onInit();
    // a membership that starts (or ends) while the app is open: read the list, or drop it
    _workers.add(ever(_access.entitlement, (_) => load()));
    _workers.add(ever(_access.sdkPremium, (_) => load()));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  bool isFavorite(String sessionId) => items.any((s) => s.id == sessionId);

  /// Reads the list from the server (members only; anyone else has none).
  Future<void> load() async {
    if (_loading) return;
    if (!_access.isMember) {
      items.clear();
      loaded.value = false;
      failed.value = false;
      return;
    }
    _loading = true;
    final started = _changes;
    try {
      final fresh = await _repo.list();
      if (started == _changes) items.assignAll(fresh);
      loaded.value = true;
      failed.value = false;
    } catch (_) {
      failed.value = true; // what is shown stays
    } finally {
      _loading = false;
    }
  }

  /// Favourite or un-favourite. The heart changes at once; if the server says no, it goes back.
  Future<FavoriteOutcome> toggle(SessionSummary s) async {
    if (!_access.isMember) return FavoriteOutcome.needsMembership;
    final was = isFavorite(s.id);
    _changes++;
    if (was) {
      items.removeWhere((x) => x.id == s.id);
    } else {
      items.insert(0, s);
    }
    try {
      await _repo.set(s.id, on: !was);
      return was ? FavoriteOutcome.removed : FavoriteOutcome.added;
    } on ApiException catch (e) {
      _undo(s, was);
      return e.code == ErrorCode.premiumRequired ? FavoriteOutcome.needsMembership : FavoriteOutcome.failed;
    } catch (_) {
      _undo(s, was);
      return FavoriteOutcome.failed;
    }
  }

  /// Puts back only this meditation (never the whole list, which a newer read or toggle may have changed meanwhile).
  void _undo(SessionSummary s, bool wasFavorite) {
    _changes++;
    if (wasFavorite) {
      if (!isFavorite(s.id)) items.insert(0, s);
    } else {
      items.removeWhere((x) => x.id == s.id);
    }
  }

  /// Sign-out or another account.
  void reset() {
    items.clear();
    loaded.value = false;
    failed.value = false;
  }
}
