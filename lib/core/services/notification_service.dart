import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../data/contracts/repositories.dart';
import '../network/session_store.dart';
import 'crash_service.dart';
import 'logger.dart';

enum PushPermission { unknown, granted, denied }

/// Push (spec §6, §10, §12 #8/#29/#57): FCM token + permission, local reminders as fallback, foreground display,
/// deep links on tap. The server subscribes the user's topic when the token is registered and leaves it on logout.
class NotificationService extends GetxService {
  NotificationService(this._me, this._session, this._crash, {required this.onOpenLink, this.onInbox});
  final MeRepository _me;
  final SessionStore _session;
  final CrashService _crash;
  /// Called with a push `deepLink` (or null) when the user taps a notification.
  final void Function(String? link, {String? notificationId}) onOpenLink;
  final void Function()? onInbox;

  final permission = PushPermission.unknown.obs;
  final _local = FlutterLocalNotificationsPlugin();
  String? deviceId;
  String? _token;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _fgSub, _openSub;
  bool _ready = false;

  static const _reminderId = 7001;
  static const _groupId = 7002;
  static const bellId = 7003;
  static const _channel = AndroidNotificationDetails('wehum_default', 'WeHum', channelDescription: 'Reminders and group meditations', importance: Importance.high, priority: Priority.high);
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true));

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (e) {
      logd('push', 'timezone init failed: $e');
    }
    await _local.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_wehum'), iOS: DarwinInitializationSettings(requestAlertPermission: false, requestBadgePermission: false, requestSoundPermission: false)),
      onDidReceiveNotificationResponse: (r) => _open(r.payload),
    );
    await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        const AndroidNotificationChannel('wehum_default', 'WeHum', description: 'Reminders and group meditations', importance: Importance.high)); // background pushes name this channel
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    logd('push', 'permission ${settings.authorizationStatus}');
    permission.value = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.granted,
      AuthorizationStatus.denied => PushPermission.denied,
      _ => PushPermission.unknown,
    };
    _fgSub = FirebaseMessaging.onMessage.listen((m) {
      logd('push', 'foreground message ${m.messageId} link=${m.data['deepLink']}');
      final n = m.notification;
      if (n != null) {
        _local
            .show(id: m.hashCode & 0x7fffffff, title: n.title, body: n.body, notificationDetails: _details, payload: jsonEncode({'l': m.data['deepLink'], 'n': m.data['notificationId']}))
            .then((_) => logd('push', 'shown in the foreground'), onError: (Object e) => logd('push', 'show failed: $e'));
      }
      onInbox?.call();
    });
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => onOpenLink(m.data['deepLink'] as String?, notificationId: m.data['notificationId'] as String?));
    final launch = await _local.getNotificationAppLaunchDetails(); // a local reminder tapped while the app was closed
    if (launch?.didNotificationLaunchApp == true) _open(launch!.notificationResponse?.payload);
    final initial = await FirebaseMessaging.instance.getInitialMessage(); // app opened from a terminated state by a push
    if (initial != null) onOpenLink(initial.data['deepLink'] as String?, notificationId: initial.data['notificationId'] as String?);
    _tokenSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      _token = t;
      registerDevice();
    });
  }

  /// Payloads are either a plain deep link (local reminders) or `{"l": link, "n": notificationId}` (shown pushes).
  void _open(String? payload) {
    logd('push', 'opened from notification: $payload');
    if (payload != null && payload.startsWith('{')) {
      try {
        final m = jsonDecode(payload) as Map;
        return onOpenLink(m['l'] as String?, notificationId: m['n'] as String?);
      } catch (_) {}
    }
    onOpenLink(payload);
  }

  /// Shows the OS dialog (iOS) / Android 13 permission. Never blocks the flow when denied (spec #08).
  Future<bool> requestPermission() async {
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      final ok = s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
      permission.value = ok ? PushPermission.granted : PushPermission.denied;
      if (ok) await registerDevice();
      return ok;
    } catch (e) {
      _crash.capture(e);
      permission.value = PushPermission.denied;
      return false;
    }
  }

  /// `POST /v1/me/devices` with the FCM token (the server joins the user's topic). Safe to call repeatedly.
  Future<void> registerDevice() async {
    try {
      if (permission.value == PushPermission.granted) _token ??= await FirebaseMessaging.instance.getToken();
      final info = await PackageInfo.fromPlatform();
      final dev = DeviceInfoPlugin();
      final os = Platform.isIOS ? (await dev.iosInfo).systemVersion : (await dev.androidInfo).version.release;
      final model = Platform.isIOS ? (await dev.iosInfo).utsname.machine : (await dev.androidInfo).model;
      deviceId = await _me.registerDevice(DeviceRegistration(
        installId: await _session.installId(), platform: Platform.isIOS ? 'ios' : 'android', appVersion: info.version, pushToken: _token, osVersion: os, model: model));
    } catch (e) {
      logd('push', 'registerDevice failed: $e'); // retried on next launch / token refresh
    }
  }

  /// Logout / account switch: the server has already dropped the token and topic; also give this phone a new token
  /// so the next person who signs in here never inherits the old one.
  Future<void> onSignedOut() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
    deviceId = null;
    await cancelAllLocal();
  }

  // ───────────── local notifications (fallback when push is off or offline)
  tz.TZDateTime _nextAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Daily "Time to meditate, {name}" at the chosen local time. Repeats at the same wall-clock time across DST.
  Future<void> scheduleDailyReminder(String hhmm, {String? name}) async {
    final parts = hhmm.split(':');
    await _local.cancel(id: _reminderId);
    await _local.zonedSchedule(
      id: _reminderId, scheduledDate: _nextAt(int.parse(parts[0]), int.parse(parts[1])), notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: DateTimeComponents.time,
      title: name == null || name.isEmpty ? 'Time to meditate' : 'Time to meditate, $name.', body: "Today's meditation with Raphael is ready.", payload: 'wehum://today');
  }

  Future<void> cancelDailyReminder() => _local.cancel(id: _reminderId);

  /// 10 minutes before the group starts (local fallback for the server push).
  Future<void> scheduleGroupReminder(DateTime startsAtUtc, {int minutesBefore = 10}) async {
    final at = tz.TZDateTime.from(startsAtUtc.subtract(Duration(minutes: minutesBefore)), tz.local);
    if (!at.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _local.zonedSchedule(
      id: _groupId, scheduledDate: at, notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Group meditation in $minutesBefore minutes', body: 'Join the lobby and start together.', payload: 'wehum://group');
  }

  Future<void> cancelGroupReminder() => _local.cancel(id: _groupId);

  /// Silence Room end bell fallback (spec §10): fires even if the app is suspended.
  Future<void> scheduleEndBell(DateTime atUtc) async {
    await _local.zonedSchedule(
      id: bellId, scheduledDate: tz.TZDateTime.from(atUtc, tz.local), notificationDetails: _details, androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, // no exact-alarm permission (Play policy); the in-app bell is the precise one
      title: 'Your meditation is complete', body: 'Take a moment before you go on.');
  }

  Future<void> cancelEndBell() => _local.cancel(id: bellId);
  Future<void> cancelAllLocal() => _local.cancelAll();

  @override
  void onClose() {
    _tokenSub?.cancel();
    _fgSub?.cancel();
    _openSub?.cancel();
    super.onClose();
  }

  @visibleForTesting
  static String describe(PushPermission p) => p.name;
}
