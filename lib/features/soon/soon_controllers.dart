import 'dart:async';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/soon.dart';
import '../../core/errors/error_code.dart';
import '../../core/realtime/socket_events.dart';
import '../../core/realtime/socket_service.dart';
import '../../core/services/access_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/config_service.dart';
import '../../core/services/onboarding_store.dart';
import '../../core/widgets/states.dart';

/// Screens 69–74 are built behind flags (`features.*`, live through `config:changed`): off → a "coming soon" teaser,
/// on → the real screen. A `FEATURE_OFF` answer from the API (flag flipped meanwhile) shows the teaser too.
mixin FeatureGate on GetxController {
  String get flag;
  bool get featureOn => Get.find<ConfigService>().feature(flag);
  final off = false.obs;

  ViewState stateFor(Object e) {
    final f = ViewState.fromError(e);
    if (f.error?.code == ErrorCode.featureOff) {
      off.value = true;
      return ViewState.content;
    }
    return f;
  }

  void tapped() => Get.find<AnalyticsService>().track('coming_soon_tap', {'feature': flag});
}

/// 69 Challenges.
class ChallengesController extends GetxController with FeatureGate {
  @override
  String get flag => 'challenges';
  late final ComingSoonRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final data = const ChallengesData().obs;
  final busy = RxnString();
  final message = RxnString();

  @override
  void onInit() {
    super.onInit();
    tapped();
    load();
  }

  Future<void> load() async {
    if (!featureOn) {
      off.value = true;
      state.value = ViewState.content;
      return;
    }
    try {
      data.value = await _repo.challenges();
      off.value = false;
      state.value = ViewState.content;
    } catch (e) {
      state.value = stateFor(e);
    }
  }

  Future<void> join(Challenge c) async {
    busy.value = c.id;
    message.value = null;
    try {
      await _repo.joinChallenge(c.id);
      await load();
    } on ApiException catch (e) {
      if (e.code == ErrorCode.premiumRequired) {
        Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'lock'});
      } else {
        message.value = 'Couldn’t join. Please try again.';
      }
    } finally {
      busy.value = null;
    }
  }

  Future<void> leave(Challenge c) async {
    await _repo.leaveChallenge(c.id);
    await load();
  }

  /// "Meditate today": any meditation counts, once a day. Progress = days meditated since joining; no streaks, no grace.
  static String note(Challenge c) => c.me == null ? '' : '${c.me!.completedDays} of ${c.days} days';
}

/// 70 Gratitude feed. Live: posts arrive over the socket room `gratitude:{kind}`.
class GratitudeController extends GetxController with FeatureGate {
  @override
  String get flag => 'gratitude';
  late final ComingSoonRepository _repo = Get.find();
  late final SocketService _socket = Get.find();
  final state = ViewState.loading.obs;
  final kind = 'gratitude'.obs;
  final posts = <GratitudePost>[].obs;
  final text = ''.obs;
  final busy = false.obs;
  final message = RxnString();
  String? _cursor;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _room;

  static const kinds = ['gratitude', 'affirmation', 'love'];
  static String label(String k) => switch (k) { 'gratitude' => 'Gratitude', 'affirmation' => 'Affirmations', _ => 'Sending love' };

  @override
  void onInit() {
    super.onInit();
    tapped();
    load();
  }

  @override
  void onReady() {
    super.onReady();
    _subs.add(_socket.on(SocketEvents.gratitudeNew, (j) => j).listen((j) {
      if (j['kind'] != kind.value) return;
      final p = GratitudePost.fromJson(((j['item'] ?? j) as Map).cast<String, dynamic>());
      if (posts.every((x) => x.id != p.id)) posts.insert(0, p);
    }));
    _subs.add(_socket.on(SocketEvents.gratitudeRemoved, (j) => j).listen((j) => posts.removeWhere((p) => p.id == j['id'])));
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    if (_room != null) _socket.leaveRoom(_room!);
    super.onClose();
  }

  Future<void> select(String k) async {
    kind.value = k;
    await load();
  }

  Future<void> load() async {
    if (!featureOn) {
      off.value = true;
      state.value = ViewState.content;
      return;
    }
    try {
      final p = await _repo.gratitude(kind.value);
      posts.assignAll(p.items);
      _cursor = p.nextCursor;
      off.value = false;
      state.value = posts.isEmpty ? ViewState.empty : ViewState.content;
      if (_room != null) _socket.leaveRoom(_room!);
      _room = 'gratitude:${kind.value}';
      await _socket.joinRoom(_room!);
    } catch (e) {
      state.value = stateFor(e);
    }
  }

  Future<void> more() async {
    if (_cursor == null) return;
    final p = await _repo.gratitude(kind.value, cursor: _cursor);
    posts.addAll(p.items);
    _cursor = p.nextCursor;
  }

  bool get valid => text.value.trim().isNotEmpty && text.value.trim().length <= 200;

  /// Posting needs an account + membership (the API enforces it; the UI explains).
  Future<PostOutcomeG> share() async {
    final a = Get.find<AccessService>();
    if (!a.isMember) return PostOutcomeG.membership;
    if (a.isGuest.value) return PostOutcomeG.account;
    if (!valid) return PostOutcomeG.invalid;
    busy.value = true;
    try {
      await _repo.shareGratitude(kind.value, text.value.trim());
      text.value = '';
      await load();
      return PostOutcomeG.posted;
    } on ApiException catch (e) {
      message.value = e.code == ErrorCode.dedicationLinks || e.code == ErrorCode.validationFailed ? 'Text only, no links, up to 200 characters.' : 'Couldn’t post. Please try again.';
      return PostOutcomeG.failed;
    } finally {
      busy.value = false;
    }
  }

  Future<void> report(GratitudePost p, String reason, {bool block = false}) async {
    await _repo.reportGratitude(p.id, reason: reason, block: block);
    posts.removeWhere((x) => x.id == p.id);
  }
}

enum PostOutcomeG { posted, membership, account, invalid, failed }

/// 71 Breathwork.
class BreathworkController extends GetxController with FeatureGate {
  @override
  String get flag => 'breathwork';
  late final ComingSoonRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final data = const BreathworkData().obs;
  final mine = <BreathPattern>[].obs;

  @override
  void onInit() {
    super.onInit();
    tapped();
    load();
  }

  Future<void> load() async {
    if (!featureOn) {
      off.value = true;
      state.value = ViewState.content;
      return;
    }
    try {
      data.value = await _repo.breathwork();
      mine.assignAll(await _repo.myPatterns());
      off.value = false;
      state.value = ViewState.content;
    } catch (e) {
      state.value = stateFor(e);
    }
  }

  Future<void> deleteMine(BreathPattern p) async {
    mine.removeWhere((x) => x.id == p.id);
    try {
      await _repo.deletePattern(p.id!);
    } catch (_) {
      await load();
    }
  }
}

/// 72 Breath pattern designer. The server's rules, checked before saving: each beat 0–20 s, in/out ≥ 1 s, a round ≤ 60 s, 1–100 rounds.
class PatternDesignerController extends GetxController with FeatureGate {
  @override
  String get flag => 'breathwork';
  late final ComingSoonRepository _repo = Get.find();
  final name = 'My pattern'.obs;
  final inhale = 4.obs, hold1 = 4.obs, exhale = 4.obs, hold2 = 4.obs, rounds = 10.obs;
  final busy = false.obs;
  final message = RxnString();

  BreathPattern get pattern => BreathPattern(name: name.value.trim().isEmpty ? 'My pattern' : name.value.trim(), inhaleSec: inhale.value, hold1Sec: hold1.value, exhaleSec: exhale.value, hold2Sec: hold2.value, rounds: rounds.value);
  String get summary => '${pattern.beats} · ${pattern.rounds} rounds · ${(pattern.totalSec / 60).toStringAsFixed(1)} min';

  static String? problem(BreathPattern p) {
    final beats = [p.inhaleSec, p.hold1Sec, p.exhaleSec, p.hold2Sec];
    if (beats.any((b) => b < 0 || b > 20)) return 'Each beat is 0–20 seconds';
    if (p.inhaleSec < 1 || p.exhaleSec < 1) return 'Breathe in and out for at least 1 second';
    if (p.roundSec > 60) return 'One round is at most 60 seconds';
    if (p.rounds < 1 || p.rounds > 100) return 'Rounds are 1–100';
    return null;
  }

  String? get error => problem(pattern);

  void adjust(RxInt v, int by, {int min = 0, int max = 20}) => v.value = (v.value + by).clamp(min, max);

  Future<bool> save() async {
    if (error != null) {
      message.value = error;
      return false;
    }
    busy.value = true;
    try {
      await _repo.savePattern(pattern);
      return true;
    } on ApiException catch (e) {
      message.value = e.message ?? 'Couldn’t save.';
      return false;
    } finally {
      busy.value = false;
    }
  }

  void start() => Get.toNamed(AppRoutes.breathRun, arguments: pattern);
}

enum BreathPhase { inhale, hold1, exhale, hold2, done }

/// Runs a pattern: one tick per second, phases in order, rounds counted. Used by the animated breathing screen.
class BreathSession {
  BreathSession(this.pattern);
  final BreathPattern pattern;
  BreathPhase phase = BreathPhase.inhale;
  int left = 0, round = 1;
  bool get done => phase == BreathPhase.done;

  int _len(BreathPhase p) => switch (p) { BreathPhase.inhale => pattern.inhaleSec, BreathPhase.hold1 => pattern.hold1Sec, BreathPhase.exhale => pattern.exhaleSec, BreathPhase.hold2 => pattern.hold2Sec, BreathPhase.done => 0 };

  void start() {
    phase = BreathPhase.inhale;
    round = 1;
    left = _len(phase);
  }

  /// One second passes.
  void tick() {
    if (done) return;
    left--;
    if (left > 0) return;
    _next();
  }

  void _next() {
    var p = phase;
    do {
      switch (p) {
        case BreathPhase.inhale:
          p = BreathPhase.hold1;
        case BreathPhase.hold1:
          p = BreathPhase.exhale;
        case BreathPhase.exhale:
          p = BreathPhase.hold2;
        case BreathPhase.hold2:
          if (round >= pattern.rounds) {
            phase = BreathPhase.done;
            left = 0;
            return;
          }
          round++;
          p = BreathPhase.inhale;
        case BreathPhase.done:
          return;
      }
    } while (_len(p) == 0); // a 0-second hold is skipped
    phase = p;
    left = _len(p);
  }
}

/// 73 Milestones.
class MilestonesController extends GetxController with FeatureGate {
  @override
  String get flag => 'milestones';
  late final ComingSoonRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final data = const MilestonesData().obs;

  @override
  void onInit() {
    super.onInit();
    tapped();
    load();
  }

  Future<void> load() async {
    if (!featureOn) {
      off.value = true;
      state.value = ViewState.content;
      return;
    }
    try {
      data.value = await _repo.milestones();
      off.value = false;
      state.value = ViewState.content;
    } catch (e) {
      state.value = stateFor(e);
    }
  }
}

/// 74 Intent (setup, behind `features.intent`): "What brings you here?" sets the first recommendation.
class IntentController extends GetxController {
  static const choices = [('stress', 'Stress', 'Calm a busy nervous system'), ('focus', 'Focus', 'Clear, steady attention'), ('sleep', 'Sleep', 'Wind down and rest'), ('deep', 'Going deeper', 'Longer, quieter meditations')];
  final selected = RxnString();

  void pick(String k) => selected.value = k;

  void next() {
    if (selected.value != null) Get.find<OnboardingStore>().intent = selected.value;
    Get.toNamed(AppRoutes.setup2MeditationReminder);
  }

  void skip() => Get.toNamed(AppRoutes.setup2MeditationReminder);
}
