import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/local/app_database.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/json.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session_store.dart';
import '../../../core/services/crash_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/states.dart';

/// 54 You.
class YouController extends GetxController {
  late final MeRepository _me = Get.find();
  late final AccessService access = Get.find();
  final profile = Rxn<MeProfile>();
  final week = Rxn<ProgressData>();
  final lifetime = Rxn<ProgressData>();
  final signingOut = false.obs;

  String get name => profile.value?.firstName ?? Get.find<OnboardingStore>().name;
  String get initials => name.isEmpty ? '' : name.substring(0, 1).toUpperCase();

  @override
  void onReady() {
    super.onReady();
    load();
  }

  Future<void> load() async {
    try {
      profile.value = await _me.me();
      access.setFromProfile(profile.value!);
    } catch (_) {}
    try {
      week.value = await _me.progress(Period.week);
      lifetime.value = await _me.progress(Period.all);
    } catch (_) {}
  }

  int get daysThisWeek => week.value?.daysThisWeek.where((d) => d).length ?? 0;

  Future<void> signOut() async {
    signingOut.value = true;
    await Get.find<AccountService>().signOut();
    signingOut.value = false;
    Get.offAllNamed(AppRoutes.splash);
  }
}

/// 55 Your progress: week dots, Week/Month/Year/Lifetime tabs, cached so it works offline. No streaks.
class ProgressController extends GetxController {
  late final MeRepository _me = Get.find();
  late final AppDatabase _db = Get.find();
  final period = Period.week.obs;
  final data = Rxn<ProgressData>();
  final week = Rxn<ProgressData>();
  final state = ViewState.loading.obs;
  final offline = false.obs;

  @override
  void onInit() {
    super.onInit();
    load(Period.week);
  }

  Future<void> select(Period p) async {
    period.value = p;
    await load(p);
  }

  Future<void> load(Period p) async {
    final cached = await _db.getCache('progress:${p.name}');
    if (cached != null && data.value == null) {
      data.value = _parse(cached);
      state.value = ViewState.content;
    }
    try {
      final d = await _me.progress(p);
      if (period.value == p) data.value = d;
      if (p == Period.week) week.value = d;
      offline.value = false;
      state.value = ViewState.content;
      await _db.putCache('progress:${p.name}', jsonEncode(_toJson(d)));
    } catch (e) {
      if (data.value == null) {
        state.value = ViewState.fromError(e);
      } else {
        offline.value = true; // "Your progress works offline and syncs when you're back."
      }
    }
  }

  static Map<String, dynamic> _toJson(ProgressData d) => {
        'period': d.period.name, 'minutes': d.minutes, 'meditations': d.meditations, 'together': d.together, 'average': d.average, 'daysMeditated': d.daysMeditated,
        'daysThisWeek': d.daysThisWeek, 'bars': [for (final b in d.bars) {'label': b.label, 'minutes': b.minutes, 'current': b.current}],
      };
  static ProgressData? _parse(String s) {
    try {
      return ProgressData.fromJson(asJson(jsonDecode(s)));
    } catch (_) {
      return null;
    }
  }

  List<bool> get dots => week.value?.daysThisWeek ?? data.value?.daysThisWeek ?? List.filled(7, false);
  String get chartTitle => switch (period.value) { Period.week => 'Minutes per day', Period.month => 'Minutes per week', Period.year => 'Minutes per month', Period.all => 'Minutes per month' };
}

/// 56 Edit profile.
class EditProfileController extends GetxController {
  late final MeRepository _me = Get.find();
  final first = ''.obs;
  final email = RxnString();
  final provider = RxnString();
  final theme = 'system'.obs;
  final busy = false.obs;
  final error = RxnString();
  final saved = false.obs;
  static final _ok = RegExp(r"^[\p{L}\p{M}' -]+$", unicode: true);

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _me.me();
      first.value = p.firstName ?? '';
      email.value = p.email;
      provider.value = p.providers.isEmpty ? null : p.providers.first;
      theme.value = p.theme;
    } catch (_) {
      first.value = Get.find<OnboardingStore>().name;
    }
  }

  String? get firstError {
    final t = first.value.trim();
    if (t.isEmpty) return 'Please enter your first name';
    if (t.length > 30) return 'At most 30 characters';
    if (!_ok.hasMatch(t)) return 'Letters and spaces only';
    return null;
  }

  String? get emailNote => email.value == null ? null : (provider.value == 'apple' ? 'Signed in with Apple. Never shown to other people.' : (provider.value == 'google' ? 'Signed in with Google. Never shown to other people.' : 'Never shown to other people.'));

  Future<bool> save() async {
    if (firstError != null) {
      error.value = firstError;
      return false;
    }
    busy.value = true;
    error.value = null;
    try {
      await _me.patch({'firstName': first.value.trim()});
      Get.find<OnboardingStore>().name = first.value.trim();
      saved.value = true;
      return true;
    } catch (e) {
      error.value = ApiClient.map(e).code == ErrorCode.network ? 'You’re offline. Try again when you’re back.' : 'Couldn’t save. Please try again.';
      return false;
    } finally {
      busy.value = false;
    }
  }

  /// Dark / Light / System: applied at once, saved locally and on the server.
  Future<void> setTheme(String t) async {
    theme.value = t;
    Get.find<ThemeController>().set(switch (t) { 'dark' => ThemeMode.dark, 'light' => ThemeMode.light, _ => ThemeMode.system });
    try {
      await _me.patch({'theme': t});
    } catch (_) {}
  }
}

/// 57 Reminders & sounds.
class RemindersController extends GetxController {
  late final MeRepository _me = Get.find();
  late final NotificationService notifications = Get.find();
  late final OnboardingStore store = Get.find();
  final profile = Rxn<MeProfile>();

  bool get reminderOn => profile.value?.reminderEnabled ?? true;
  String get time => profile.value?.reminderTime ?? store.reminderTime;
  bool get groupWarning => profile.value?.groupWarning ?? false;
  bool get dailyMessage => profile.value?.dailyMessagePush ?? true;
  bool get notificationsOff => notifications.permission.value == PushPermission.denied;
  final wifiOnly = true.obs;

  @override
  void onInit() {
    super.onInit();
    wifiOnly.value = store.wifiOnlyDownloads;
    load();
  }

  Future<void> load() async {
    try {
      profile.value = await _me.me();
    } catch (_) {}
  }

  Future<void> _patch(Map<String, dynamic> m) async {
    try {
      profile.value = await _me.patch(m);
    } catch (_) {}
  }

  Future<void> setReminder(bool on) async {
    await _patch({'reminderEnabled': on});
    on ? await notifications.scheduleDailyReminder(time, name: store.name) : await notifications.cancelDailyReminder();
    Get.find<AnalyticsService>().track('reminder_set', {'time': time, 'enabled': on});
  }

  Future<void> setTime(String hhmm) async {
    store.reminderTime = hhmm;
    await _patch({'reminderTime': hhmm});
    if (reminderOn) await notifications.scheduleDailyReminder(hhmm, name: store.name);
    Get.find<AnalyticsService>().track('reminder_set', {'time': hhmm, 'enabled': reminderOn});
  }

  Future<void> setGroupWarning(bool on) => _patch({'groupWarning': on});
  Future<void> setDailyMessage(bool on) => _patch({'dailyMessagePush': on});
  void setWifiOnly(bool v) {
    wifiOnly.value = v;
    store.wifiOnlyDownloads = v;
  }

  /// Asks the OS again (only possible while "not determined"); otherwise the screen offers Open Settings.
  Future<void> enableNotifications() => notifications.requestPermission();
}

/// 59 Privacy & data: presence country, data export, account deletion.
class PrivacyController extends GetxController {
  late final MeRepository _me = Get.find();
  final profile = Rxn<MeProfile>();
  final exportState = 'idle'.obs; // idle | working | done | failed
  final exportUrl = RxnString();
  final deleting = false.obs;
  final deleteError = RxnString();

  bool get showCountry => profile.value?.showCountry ?? true;

  @override
  void onInit() {
    super.onInit();
    _me.me().then((p) => profile.value = p).catchError((_) => const MeProfile(id: ''));
  }

  Future<void> setShowCountry(bool v) async {
    try {
      profile.value = await _me.patch({'showCountry': v});
    } catch (_) {}
  }

  Future<void> exportData() async {
    exportState.value = 'working';
    try {
      final id = await _me.startExport();
      for (var i = 0; i < 30; i++) {
        final s = await _me.exportStatus(id);
        if (s.status == 'done') {
          exportUrl.value = s.jsonUrl;
          exportState.value = 'done';
          return;
        }
        if (s.status == 'failed') break;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      exportState.value = 'failed';
    } catch (_) {
      exportState.value = 'failed';
    }
  }

  /// Delete: server removes the account (RevenueCat, storage, database); then this phone is wiped and starts over.
  Future<bool> deleteAccount() async {
    deleting.value = true;
    deleteError.value = null;
    try {
      await _me.deleteAccount();
      Get.find<AnalyticsService>().track('account_delete');
      await _wipeLocal();
      return true;
    } catch (e) {
      deleteError.value = ApiClient.map(e).code == ErrorCode.network ? 'You’re offline. Deleting needs a connection.' : 'Couldn’t delete the account. Please try again.';
      return false;
    } finally {
      deleting.value = false;
    }
  }

  Future<void> _wipeLocal() async {
    await Get.find<DownloadService>().clearAll();
    await Get.find<AppDatabase>().clearAllUserData();
    await Get.find<OnboardingStore>().reset();
    await Get.find<SessionStore>().clear();
    await Get.find<AccountService>().signOutLocalOnly();
  }
}

/// 60 Help & about.
class HelpController extends GetxController {
  final version = ''.obs;
  var _taps = 0;

  /// Tapping the version 7 times sends a Sentry test event (spec P0 exit: "test crash received"). Nothing else changes.
  Future<bool> versionTapped() async {
    if (++_taps < 7) return false;
    _taps = 0;
    if (!Get.find<CrashService>().enabled) return false;
    await Get.find<CrashService>().capture(StateError('Sentry test event from Help → Version'), StackTrace.current);
    return true;
  }

  @override
  void onInit() {
    super.onInit();
    PackageInfo.fromPlatform().then((i) => version.value = 'Version ${i.version}');
  }
}
