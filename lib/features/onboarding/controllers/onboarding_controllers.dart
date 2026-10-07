import 'package:get/get.dart';
import '../../../app/app_controller.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/bootstrap.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/config_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/services/perf_service.dart';
import '../../../core/services/purchase_service.dart';

/// 01 Splash: session + bootstrap in parallel, then decide the first screen (spec §12 row 1).
class SplashController extends GetxController {
  final failure = Rxn<ErrorCode>();

  @override
  void onReady() {
    super.onReady();
    start();
  }

  /// Where to go once the app is ready: first run → intro; returning → Today (member) / Today free.
  static String firstRoute({required bool onboardingDone, required bool member}) =>
      !onboardingDone ? AppRoutes.intro1Welcome : (member ? AppRoutes.todayMember : AppRoutes.todayFree);

  Future<void> start() async {
    failure.value = null;
    final app = Get.find<AppController>();
    try {
      await app.startup();
    } catch (e) {
      failure.value = ApiClient.map(e).code;
      return;
    }
    final b = app.lastBootstrap;
    if (b != null && b.updateRequired) {
      Get.offAllNamed(AppRoutes.updateRequired);
    } else if (b != null && b.maintenance) {
      Get.offAllNamed(AppRoutes.maintenance);
    } else {
      Get.find<AnalyticsService>().track('app_open', {'source': 'cold'});
      Get.offAllNamed(firstRoute(onboardingDone: Get.find<OnboardingStore>().done, member: Get.find<AccessService>().isMember));
      Get.find<PerfService>().results['cold_start'] = appStartWatch.elapsed; // target < 2.0 s on a mid Android
    }
  }
}

/// 02–05: the four intro slides. Screen 03 shows the live pill from socket `live:agg` (hidden when offline).
class IntroController extends GetxController {
  IntroController(this.step);
  final int step; // 1..4

  static const lastStep = 4;
  late final LiveService live = Get.find<LiveService>();

  @override
  void onReady() {
    super.onReady();
    Get.find<AnalyticsService>().track('onboarding_step_view', {'step': 'intro$step'});
    if (step == 2) live.acquireToday();
  }

  @override
  void onClose() {
    if (step == 2) live.releaseToday();
    super.onClose();
  }

  /// "412 meditating now"; null (pill hidden) while the socket is paused or nothing has arrived. Never shows stale numbers as live.
  String? get livePill {
    final a = live.agg.value;
    if (a == null || live.paused) return null;
    return a.quiet ? '${_n(a.meditatedToday)} meditated today' : '${_n(a.total)} meditating now';
  }

  void next() => Get.toNamed(step >= lastStep ? AppRoutes.setup1YourName : '/intro/${step + 1}');
  void skip() => Get.toNamed(AppRoutes.howDoYouWantToStart);
}

String _n(int v) => v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

/// 06 Your name.
class NameController extends GetxController {
  final name = ''.obs;
  final touched = false.obs;

  static final _allowed = RegExp(r"^[\p{L}\p{M}' -]+$", unicode: true);

  @override
  void onInit() {
    super.onInit();
    name.value = Get.find<OnboardingStore>().name;
    Get.find<AnalyticsService>().track('onboarding_step_view', {'step': 'name'});
  }

  String get trimmed => name.value.trim();

  /// null = valid. Same rule as the server: 1–30 letters, spaces, apostrophes, hyphens.
  String? get error {
    if (!touched.value && trimmed.isEmpty) return null;
    if (trimmed.isEmpty) return 'Please enter your first name';
    if (trimmed.length > 30) return 'At most 30 characters';
    if (!_allowed.hasMatch(trimmed)) return 'Letters and spaces only';
    return null;
  }

  bool get valid => trimmed.isNotEmpty && trimmed.length <= 30 && _allowed.hasMatch(trimmed);

  /// Preview chip ("Good morning, Marcus"), from the phone's local time.
  String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    final part = h < 12 ? 'Good morning' : (h < 18 ? 'Good afternoon' : 'Good evening');
    return trimmed.isEmpty ? part : '$part, $trimmed';
  }

  void submit() {
    touched.value = true;
    if (!valid) return;
    Get.find<OnboardingStore>().name = trimmed;
    _next();
  }

  void skip() => _next();

  /// Step 74 "What brings you here?" is only in the flow while `features.intent` is on (off for V1).
  void _next() => Get.toNamed(Get.find<ConfigService>().feature('intent') ? AppRoutes.intent : AppRoutes.setup2MeditationReminder);
}

/// 07 Meditation reminder (24-hour wheel).
class TimeController extends GetxController {
  final hour = 7.obs;
  final minute = 0.obs;

  @override
  void onInit() {
    super.onInit();
    final p = Get.find<OnboardingStore>().reminderTime.split(':');
    hour.value = int.tryParse(p[0]) ?? 7;
    minute.value = int.tryParse(p[1]) ?? 0;
    Get.find<AnalyticsService>().track('onboarding_step_view', {'step': 'time'});
  }

  String get hhmm => '${hour.value.toString().padLeft(2, '0')}:${minute.value.toString().padLeft(2, '0')}';

  void submit() {
    Get.find<OnboardingStore>().reminderTime = hhmm;
    Get.toNamed(AppRoutes.setup3Reminder);
  }
}

/// 08 Reminder permission: the OS dialog; "Not now" and "Don't allow" both continue.
class ReminderPermissionController extends GetxController {
  final busy = false.obs;

  String get timeLabel {
    final p = Get.find<OnboardingStore>().reminderTime.split(':');
    return '${int.parse(p[0])}:${p[1]}';
  }

  Future<void> allow() async {
    busy.value = true;
    final n = Get.find<NotificationService>();
    await n.init();
    final ok = await n.requestPermission();
    Get.find<OnboardingStore>().notificationChoice = ok ? 'granted' : 'denied';
    Get.find<AnalyticsService>().track('notification_permission', {'result': ok ? 'granted' : 'denied'});
    await _finish(ok);
  }

  Future<void> _finish(bool granted) async {
    final store = Get.find<OnboardingStore>();
    final analytics = Get.find<AnalyticsService>();
    // name + reminder go to the server (it schedules the push); a local reminder is the fallback
    try {
      await Get.find<MeRepository>().patch({
        if (store.name.isNotEmpty) 'firstName': store.name,
        'reminderTime': store.reminderTime,
        'reminderEnabled': granted,
      });
    } catch (_) {/* retried when the profile screen next saves */}
    analytics.track('reminder_set', {'time': store.reminderTime, 'enabled': granted});
    if (granted) await Get.find<NotificationService>().scheduleDailyReminder(store.reminderTime, name: store.name);
    busy.value = false;
    Get.toNamed(AppRoutes.howDoYouWantToStart);
  }
}

/// 09 How do you want to start: Founding banner (live), annual trial, monthly, continue free, log in, restore.
class StartController extends GetxController {
  late final PurchaseService purchases = Get.find<PurchaseService>();
  late final ConfigService config = Get.find<ConfigService>();
  final busy = false.obs;
  final message = RxnString();
  final selected = 'annual'.obs;

  Founding get founding => config.current.value?.founding ?? const Founding();
  Offer? get offer => purchases.offer.value;

  @override
  void onReady() {
    super.onReady();
    Get.find<AnalyticsService>()
      ..track('onboarding_step_view', {'step': 'start'})
      ..track('paywall_view', {'source': 'start', 'offering': offer?.offeringId ?? ''});
    purchases.loadOffer();
  }

  Future<void> startTrial(PlanOption plan) async {
    if (busy.value) return;
    busy.value = true;
    message.value = null;
    Get.find<AnalyticsService>().track('plan_selected', {'product_id': plan.productId});
    final out = await purchases.buy(plan);
    busy.value = false;
    switch (out) {
      case PurchaseOutcome.success:
        _complete();
        Get.offAllNamed(AppRoutes.trialStarted);
      case PurchaseOutcome.cancelled:
        break; // back here with the offer intact
      case PurchaseOutcome.pending:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'pending'});
      case PurchaseOutcome.alreadySubscribed:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'already'});
      case PurchaseOutcome.failed:
        Get.toNamed(AppRoutes.purchaseStates, arguments: {'state': 'failed', 'planId': plan.packageId});
      case PurchaseOutcome.unavailable:
        message.value = 'That plan changed. Please check the updated options.';
    }
  }

  void continueFree() {
    _complete();
    Get.offAllNamed(AppRoutes.todayFree);
  }

  void _complete() {
    Get.find<OnboardingStore>().done = true;
    Get.find<AnalyticsService>().track('onboarding_complete', {'step': 'start'});
  }
}
