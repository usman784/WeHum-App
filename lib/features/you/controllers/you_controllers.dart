import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show TextEditingController, ThemeMode;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/local/app_database.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/json.dart';
import '../../../core/data/models/stitch.dart';
import '../../../core/services/config_service.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/session_store.dart';
import '../../../core/services/crash_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/logger.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/services/practiced_service.dart';
import '../../../core/services/sync_service.dart';
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
  /// The last few meditations practiced (newest first) for the "Recently practiced" block.
  final recent = <MeditationLogEntry>[].obs;
  final _workers = <Worker>[];
  /// False until the first progress answer (or failure): the page shows placeholders in the same places meanwhile,
  /// so the streak block does not pop in above the week chart and push everything down.
  final loaded = false.obs;

  /// The last answers, kept across tab switches (the bottom nav rebuilds this controller every time), for the same user only.
  static ({String userId, MeProfile? profile, ProgressData? week, ProgressData? lifetime})? _last;

  String get name => profile.value?.firstName ?? Get.find<OnboardingStore>().name;
  String get initials => name.isEmpty ? '' : name.substring(0, 1).toUpperCase();

  @override
  void onInit() {
    super.onInit();
    final last = _last;
    if (last != null && last.userId == access.userId && !access.isGuest.value) {
      profile.value = last.profile;
      week.value = last.week;
      lifetime.value = last.lifetime;
      loaded.value = true; // shown at once, refreshed quietly below
    }
  }

  @override
  void onReady() {
    super.onReady();
    load();
    // live: a sit recorded on this phone, or finished on another device
    if (Get.isRegistered<SyncService>()) _workers.add(debounce(Get.find<SyncService>().byId, (_) => _sitChanged(), time: const Duration(milliseconds: 400)));
    if (Get.isRegistered<PracticedService>()) _workers.add(debounce(Get.find<PracticedService>().revision, (_) => _sitChanged(), time: const Duration(milliseconds: 400)));
  }

  Timer? _statsTimer;

  /// The list follows at once; the totals (meditations, time, streak) are worked out by the server a moment later, so read them again then.
  void _sitChanged() {
    loadRecent();
    _statsTimer?.cancel();
    _statsTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) load();
    });
  }

  @override
  void onClose() {
    _statsTimer?.cancel();
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  Future<void> loadRecent() async {
    if (access.isGuest.value || !Get.isRegistered<MeditationRepository>()) return;
    try {
      final p = await Get.find<MeditationRepository>().history();
      if (isClosed) return;
      recent.assignAll(MeditationHistoryController.counted(p).take(3));
    } catch (_) {/* the block keeps what it shows */}
  }

  Future<void> load() async {
    unawaited(loadRecent());
    try {
      profile.value = await _me.me();
      access.setFromProfile(profile.value!);
    } catch (_) {}
    if (access.isGuest.value) {
      week.value = lifetime.value = null; // no progress before an account
      _last = null;
      loaded.value = true;
      return;
    }
    final id = access.userId;
    ProgressData? w, all;
    try {
      (w, all) = await (_me.progress(Period.week), _me.progress(Period.all)).wait;
    } on ParallelWaitError<(ProgressData?, ProgressData?), (AsyncError?, AsyncError?)> catch (e) {
      (w, all) = e.values; // keep whichever answer did arrive
    } catch (_) {}
    if (isClosed || access.userId != id || access.isGuest.value) return; // signed out or switched account meanwhile: not this user's data
    if (w != null) week.value = w;
    if (all != null) lifetime.value = all;
    loaded.value = true;
    if (id != null) _last = (userId: id, profile: profile.value, week: week.value, lifetime: lifetime.value);
  }

  int get daysThisWeek => week.value?.daysThisWeek.where((d) => d).length ?? 0;

  /// The forgiving streak (null when the server has the streaks flag off).
  StreakInfo? get streak => week.value?.streak;
  bool get challengesOn => Get.isRegistered<ConfigService>() && Get.find<ConfigService>().feature('challenges');
  bool get heartRateOn => Get.isRegistered<ConfigService>() && Get.find<ConfigService>().feature('heartRate');

  Future<void> signOut() => runSignOut(signingOut);
}

/// Sign out, then back to the start screen whatever happens (the session is cleared locally anyway). Shared by You and Settings.
Future<void> runSignOut(RxBool busy) async {
  busy.value = true;
  try {
    await Get.find<AccountService>().signOut();
  } catch (e) {
    logd('you', 'sign-out step failed: $e');
  } finally {
    busy.value = false;
    Get.offAllNamed(AppRoutes.splash);
  }
}

/// Settings (top-right gear): the preferences list and Sign out.
class SettingsController extends GetxController {
  late final AccessService access = Get.find();
  final signingOut = false.obs;
  bool get challengesOn => Get.isRegistered<ConfigService>() && Get.find<ConfigService>().feature('challenges');
  bool get heartRateOn => Get.isRegistered<ConfigService>() && Get.find<ConfigService>().feature('heartRate');
  Future<void> signOut() => runSignOut(signingOut);
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

/// 56 Edit profile (accounts only): photo, first and last name, short bio, username (one per person, changed once every
/// 7 days). The e-mail is shown, never edited.
class EditProfileController extends GetxController {
  late final MeRepository _me = Get.find();
  final first = ''.obs, last = ''.obs, username = ''.obs, bio = ''.obs;
  final usernameOk = true.obs;
  final email = RxnString();
  final provider = RxnString();
  final avatarUrl = RxnString();
  final savedUsername = ''.obs;
  final nextUsernameChange = Rxn<DateTime>();
  final theme = 'system'.obs;
  final busy = false.obs;
  final photoBusy = false.obs;
  final error = RxnString();
  final photoError = RxnString();
  /// Field errors show only after the first Save, not while the profile is still loading.
  final triedSave = false.obs;
  final saved = false.obs;
  /// The server takes photos up to 700 KB; the app stays below that.
  static const maxPhotoBytes = 600 * 1024;
  static final _ok = RegExp(r"^[\p{L}\p{M}' .-]+$", unicode: true);

  /// The fields' text. Filled from the phone at once and from the server when it answers (an `initialValue` would
  /// be read before the profile arrives and leave the field empty).
  final firstField = TextEditingController(), lastField = TextEditingController(), bioField = TextEditingController();

  bool get usernameLocked => nextUsernameChange.value?.isAfter(DateTime.now()) ?? false;

  void _setFirst(String v) {
    first.value = v;
    if (firstField.text != v) firstField.text = v;
  }

  @override
  void onInit() {
    super.onInit();
    _setFirst(Get.find<OnboardingStore>().name);
    _load();
  }

  @override
  void onClose() {
    firstField.dispose();
    lastField.dispose();
    bioField.dispose();
    super.onClose();
  }

  void _apply(MeProfile p) {
    if ((p.firstName ?? '').isNotEmpty) _setFirst(p.firstName!);
    last.value = p.lastName ?? '';
    if (lastField.text != last.value) lastField.text = last.value;
    bio.value = p.bio ?? '';
    if (bioField.text != bio.value) bioField.text = bio.value;
    username.value = p.username ?? '';
    savedUsername.value = p.username ?? '';
    nextUsernameChange.value = p.usernameNextChangeAt;
    avatarUrl.value = p.avatarUrl;
    email.value = p.email;
    provider.value = p.providers.isEmpty ? null : p.providers.first;
  }

  Future<void> _load() async {
    try {
      _apply(await _me.me());
      theme.value = Get.find<ThemeController>().mode.value.name; // what this phone actually shows
    } catch (_) {/* offline: the name from this phone is already in the field */}
  }

  String? get firstError {
    final t = first.value.trim();
    if (t.isEmpty) return 'Please enter your first name';
    if (t.length > 30) return 'At most 30 characters';
    if (!_ok.hasMatch(t)) return 'Letters and spaces only';
    return null;
  }

  String? get lastError {
    final t = last.value.trim();
    if (t.isEmpty) return null;
    if (t.length > 30) return 'At most 30 characters';
    if (!_ok.hasMatch(t)) return 'Letters and spaces only';
    return null;
  }

  String? get emailNote => email.value == null ? null : (provider.value == 'apple' ? 'Signed in with Apple. Never shown to other people. It cannot be changed.' : (provider.value == 'google' ? 'Signed in with Google. Never shown to other people. It cannot be changed.' : 'Never shown to other people. It cannot be changed.'));

  /// Opens the library or the camera; the picture is cut to about 512 px before it is sent, whatever its original size.
  Future<void> pickPhoto(ImageSource source) async {
    photoError.value = null;
    try {
      final f = await ImagePicker().pickImage(source: source, maxWidth: 512, maxHeight: 512, imageQuality: 80);
      if (f == null) return;
      photoBusy.value = true;
      final (bytes, type) = await fitPhoto(await f.readAsBytes());
      final p = await _me.setAvatar(bytes, type);
      avatarUrl.value = p.avatarUrl;
      await Get.find<ConfigService>().refresh();
    } catch (e) {
      photoError.value = _photoMessage(e, 'Couldn’t update the photo. Please try again.');
    } finally {
      photoBusy.value = false;
    }
  }

  /// What the server takes: a JPEG or PNG under [maxPhotoBytes]. Anything else (HEIC, a very large PNG) is redrawn
  /// smaller as PNG until it fits.
  static Future<(Uint8List, String)> fitPhoto(Uint8List bytes) async {
    final jpeg = bytes.length > 3 && bytes[0] == 0xff && bytes[1] == 0xd8;
    final png = bytes.length > 8 && bytes[0] == 0x89 && bytes[1] == 0x50;
    if ((jpeg || png) && bytes.length <= maxPhotoBytes) return (bytes, jpeg ? 'image/jpeg' : 'image/png');
    for (final width in const [512, 384, 256]) {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      if (data != null && data.lengthInBytes <= maxPhotoBytes) return (data.buffer.asUint8List(), 'image/png');
    }
    throw const FormatException('The photo is too large');
  }

  String _photoMessage(Object e, String fallback) {
    if (e is FormatException) return 'That photo is too large. Please pick another one.';
    final err = ApiClient.map(e);
    return switch (err.code) {
      ErrorCode.network || ErrorCode.timeout => 'You’re offline. Try again when you’re back.',
      ErrorCode.accountRequired => 'Create an account to change your photo.',
      ErrorCode.validationFailed when (err.message ?? '').isNotEmpty => err.message!,
      _ => fallback,
    };
  }

  Future<void> removePhoto() async {
    photoError.value = null;
    photoBusy.value = true;
    try {
      final p = await _me.removeAvatar();
      avatarUrl.value = p.avatarUrl;
      await Get.find<ConfigService>().refresh();
    } catch (e) {
      photoError.value = _photoMessage(e, 'Couldn’t remove the photo. Please try again.');
    } finally {
      photoBusy.value = false;
    }
  }

  Future<bool> save() async {
    triedSave.value = true;
    error.value = null;
    if (firstError != null || lastError != null) return false; // shown on the field
    if (bio.value.trim().length > 200) {
      error.value = 'The bio can be 200 characters at most';
      return false;
    }
    if (savedUsername.value.isEmpty && username.value.isEmpty) {
      error.value = 'Pick a username. It is how other people will find you.';
      return false;
    }
    final changingUsername = !usernameLocked && username.value.isNotEmpty && username.value != savedUsername.value;
    if (changingUsername && !usernameOk.value) {
      error.value = 'Pick a username that is free.';
      return false;
    }
    busy.value = true;
    error.value = null;
    try {
      final p = await _me.patch({'firstName': first.value.trim(), 'lastName': last.value.trim().isEmpty ? null : last.value.trim(), 'bio': bio.value.trim().isEmpty ? null : bio.value.trim(), if (changingUsername) 'username': username.value});
      Get.find<OnboardingStore>().name = first.value.trim();
      _apply(p);
      await Get.find<ConfigService>().refresh();
      saved.value = true;
      return true;
    } catch (e) {
      final err = ApiClient.map(e);
      error.value = err.code == ErrorCode.network
          ? 'You’re offline. Try again when you’re back.'
          : ((err.message ?? '').isNotEmpty && (err.code == ErrorCode.rateLimited || err.code == ErrorCode.validationFailed || err.code == ErrorCode.alreadyExists) ? err.message! : 'Couldn’t save. Please try again.');
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

  /// Offline audio on this phone (MB) for the "Purge offline cache" row; refreshed after a purge.
  int get cacheBytes => Get.find<DownloadService>().usedBytes;

  final purged = false.obs;
  Future<void> purgeCache() async {
    Get.find<AnalyticsService>().track('privacy_purge_cache', {'bytes': cacheBytes});
    await Get.find<DownloadService>().clearAll();
    purged.value = true;
  }

  /// Removes the name and place from every dedication this person wrote. Returns how many posts changed (null = failed).
  final anonymized = RxnInt();
  final anonymizeFailed = false.obs;
  Future<void> anonymize() async {
    anonymizeFailed.value = false;
    try {
      anonymized.value = await Get.find<CommunityRepository>().anonymize();
      Get.find<AnalyticsService>().track('privacy_anonymize', {'count': anonymized.value ?? 0});
    } catch (_) {
      anonymizeFailed.value = true;
    }
  }

  Future<void> exportData() async {
    exportState.value = 'working';
    try {
      final id = await _me.startExport();
      for (var i = 0; i < 30; i++) {
        final s = await _me.exportStatus(id);
        if (s.status == 'done') {
          exportUrl.value = s.zipUrl ?? s.jsonUrl;
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

/// 29 What the notifications look like, built from the person's own settings and today's group time.
class PushPreviewController extends GetxController {
  final groupWarningAt = RxnString();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  Future<void> _load() async {
    try {
      final g = await Get.find<TodayRepository>().groupNext();
      groupWarningAt.value = DateFormat('HH:mm').format(g.startsAt.toLocal().subtract(Duration(minutes: g.reminderMin)));
    } catch (_) {/* no group time known: that card shows no time */}
  }

  List<(String, String, String)> get items {
    final store = Get.find<OnboardingStore>();
    final name = store.name.trim();
    return [
      (name.isEmpty ? 'Time to meditate.' : 'Time to meditate, $name.', 'Today’s meditation with Raphael is ready.', store.reminderTime),
      ('Group meditation in 10 minutes', 'Join the lobby and start together.', groupWarningAt.value ?? ''),
      ('Today’s message from Raphael', 'A short note for your day.', store.reminderTime),
    ];
  }
}

/// You → Meditations: every meditation the person practiced, newest first, with its date. Pages in as you scroll and
/// refreshes by itself when a sit is recorded here or finished on another device.
class MeditationHistoryController extends GetxController {
  late final MeditationRepository _repo = Get.find();
  final entries = <MeditationLogEntry>[].obs;
  final state = ViewState.loading.obs;
  final loadingMore = false.obs;
  String? _cursor;
  bool get hasMore => _cursor != null;
  final _workers = <Worker>[];
  int _gen = 0;

  @override
  void onInit() {
    super.onInit();
    load();
    // live: this phone recorded a sit (SyncService answer) or another device finished one (socket → PracticedService)
    if (Get.isRegistered<SyncService>()) _workers.add(debounce(Get.find<SyncService>().byId, (_) => load(), time: const Duration(milliseconds: 400)));
    if (Get.isRegistered<PracticedService>()) _workers.add(debounce(Get.find<PracticedService>().revision, (_) => load(), time: const Duration(milliseconds: 400)));
  }

  @override
  void onClose() {
    for (final w in _workers) {
      w.dispose();
    }
    super.onClose();
  }

  /// Only sits that counted: the same ones the MEDITATIONS number adds up.
  static List<MeditationLogEntry> counted(Page<Json> p) => [for (final j in p.items) MeditationLogEntry.fromJson(j)].where((e) => e.counted).toList();

  Future<void> load() async {
    final gen = ++_gen;
    if (entries.isEmpty) state.value = ViewState.loading;
    try {
      final p = await _repo.history();
      if (gen != _gen) return;
      entries.assignAll(counted(p));
      _cursor = p.nextCursor;
      state.value = entries.isEmpty && !hasMore ? ViewState.empty : ViewState.content;
      unawaited(_fill(gen));
    } catch (e) {
      if (gen != _gen) return;
      if (entries.isEmpty) state.value = ViewState.fromError(e); // a list that is already shown stays on a failed refresh
    }
  }

  /// The server's history also holds sits that did not count, so a page can hold few rows of ours: keep reading pages until the
  /// screen is full (a short list cannot be scrolled, so scrolling alone would never ask for the rest).
  Future<void> _fill(int gen) async {
    for (var i = 0; i < 8 && gen == _gen && hasMore && entries.length < 12; i++) {
      await more();
    }
  }

  Future<void> more() async {
    if (_cursor == null || loadingMore.value) return;
    loadingMore.value = true;
    final gen = _gen;
    try {
      final p = await _repo.history(cursor: _cursor);
      if (gen != _gen) return;
      final seen = entries.map((e) => e.id).toSet();
      entries.addAll(counted(p).where((e) => !seen.contains(e.id)));
      _cursor = p.nextCursor;
    } catch (_) {/* the next scroll tries again */} finally {
      loadingMore.value = false;
    }
  }

  /// Entries grouped by local day, newest first: `(day, entries)`.
  List<(DateTime, List<MeditationLogEntry>)> get days {
    final out = <(DateTime, List<MeditationLogEntry>)>[];
    for (final e in entries) {
      final t = e.startedAt.toLocal();
      final d = DateTime(t.year, t.month, t.day);
      if (out.isNotEmpty && out.last.$1 == d) {
        out.last.$2.add(e);
      } else {
        out.add((d, [e]));
      }
    }
    return out;
  }
}
