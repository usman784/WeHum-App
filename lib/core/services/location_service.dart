import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../data/contracts/repositories.dart';
import '../widgets/location_prompt.dart';

/// Where the "meditating now" map puts you. The map is country level only (spec: no GPS): we ask for approximate
/// location once, turn it into a 2-letter country code ON THE PHONE and send only that code. Coordinates never leave
/// the device. Without permission the phone's region setting is used, so nobody is missing from the map.
class LocationService extends GetxService {
  LocationService(this._me);
  final MeRepository _me;

  DateTime? _lastSync;
  bool _promptedThisSession = false;

  static const _snoozeKey = 'location_snooze_until_v2';

  /// After "Not now" we stay quiet for 3 days (the next meditation / the You toggle can still ask when forced).
  bool get _snoozed {
    try {
      final until = GetStorage().read<int>(_snoozeKey);
      return until != null && DateTime.now().millisecondsSinceEpoch < until;
    } catch (_) {
      return false;
    }
  }

  void _snooze() {
    try {
      GetStorage().write(_snoozeKey, DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch);
    } catch (_) {/* no storage: session guard only */}
  }

  Future<LocationPermission> status() => Geolocator.checkPermission();

  static bool granted(LocationPermission p) => p == LocationPermission.whileInUse || p == LocationPermission.always;

  /// Silent: never shows anything. Granted → country from the approximate position; otherwise → the phone's region
  /// (only when the profile has no country yet). Throttled to once per 6 h unless [force].
  Future<void> sync({bool force = false}) async {
    final last = _lastSync;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    _lastSync = DateTime.now();
    try {
      final profile = await _me.me();
      if (!profile.showCountry) return; // hidden on purpose: nothing to send
      String? code;
      if (granted(await status())) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)));
        final marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
        code = marks.map((m) => m.isoCountryCode).whereType<String>().firstOrNull;
      }
      code ??= profile.country == null ? PlatformDispatcher.instance.locale.countryCode : null;
      code = code?.toUpperCase();
      if (code != null && RegExp(r'^[A-Z]{2}$').hasMatch(code) && code != profile.country) await _me.patch({'country': code});
    } catch (_) {
      _lastSync = null; // offline / no fix: the next resume tries again
    }
  }

  /// The OS dialog (call only after our own explanation). Returns whether location is now allowed.
  Future<bool> requestOs() async {
    final p = await Geolocator.requestPermission();
    final ok = granted(p);
    unawaited(sync(force: true)); // allowed → real country; refused → phone region
    return ok;
  }

  /// At the moment the map needs it: explain first, ask once; after a refusal offer the phone's Settings.
  /// At most once per app session, and never for someone who hides their country.
  Future<void> promptIfNeeded({bool force = false}) async {
    if ((_promptedThisSession || _snoozed) && !force) return;
    final p = await status();
    if (granted(p)) return unawaited(sync());
    _promptedThisSession = true;
    if (p == LocationPermission.denied) {
      final yes = await _dialog(title: 'Join the world map', body: 'See where people are meditating with you right now. We use your approximate location once, only to find your country. Your exact position is never saved or shared.', ok: 'Allow location and continue', cancel: 'Not now');
      if (yes == true) {
        // refused (or the phone would not ask again) → offer Settings right away, never a dead end
        if (!await requestOs()) await _settingsDialog();
      } else {
        if (yes == false) _snooze(); // only a real "Not now"; a dismissed dialog asks again next launch
        unawaited(sync()); // phone-region fallback
      }
    } else if (p == LocationPermission.deniedForever) {
      await _settingsDialog();
    }
  }

  Future<void> _settingsDialog() async {
    final yes = await _dialog(title: 'Location is off', body: 'Turn location on for WeHum in Settings so your country can light up on the map.', ok: 'Open Settings', cancel: 'Not now', icon: Icons.location_off_outlined);
    if (yes == true) {
      await Geolocator.openAppSettings();
    } else {
      if (yes == false) _snooze();
      unawaited(sync());
    }
  }

  Future<bool?> _dialog({required String title, required String body, required String ok, required String cancel, IconData icon = Icons.public_rounded}) => Get.dialog<bool>(
        LocationPromptCard(title: title, body: body, ok: ok, cancel: cancel, icon: icon, onOk: () => Get.back(result: true), onCancel: () => Get.back(result: false)),
        barrierColor: Colors.black.withValues(alpha: .72),
      );
}
