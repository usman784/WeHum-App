import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../data/contracts/repositories.dart';
import '../widgets/location_prompt.dart';

/// Where the "meditating now" map puts you: your country and your city. We ask for approximate location, turn it into a
/// country code and a city name ON THE PHONE and send only those plus a position rounded to ~10 km (the server rounds it
/// again). The exact position never leaves the device. Without permission the phone's region is used for the country, so
/// nobody is missing from the map. Nothing is sent for someone who hides their country.
class LocationService extends GetxService {
  LocationService(this._me);
  final MeRepository _me;

  DateTime? _lastSync;
  String? _lastPos;
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

  /// A position rounded to 0.1° (~10 km): a city, never a street.
  static double round1(double v) => (v * 10).round() / 10;

  /// The city of a placemark: the town, else the district, else the region (Android often has no town for villages).
  static String? cityOf(Placemark m) {
    for (final v in [m.locality, m.subAdministrativeArea, m.administrativeArea]) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty && t.length <= 80) return t.replaceAll('|', '');
    }
    return null;
  }

  /// Silent: never shows anything. Granted → country and city from the approximate position; otherwise → the phone's
  /// region (only when the profile has no country yet). Throttled to once per 6 h unless [force]. The geocoder is only
  /// asked when the rounded position moved or the profile has no city yet, so the usual call costs one cached position.
  Future<void> sync({bool force = false}) async {
    final last = _lastSync;
    if (!force && last != null && DateTime.now().difference(last) < const Duration(hours: 6)) return;
    _lastSync = DateTime.now();
    try {
      final profile = await _me.me();
      if (!profile.showCountry) return; // hidden on purpose: nothing to send
      String? code;
      Map<String, Object>? city;
      if (granted(await status())) {
        final pos = await Geolocator.getLastKnownPosition() ??
            await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 8)));
        final lat = round1(pos.latitude), lng = round1(pos.longitude), key = '$lat,$lng';
        final same = _lastPos == key && profile.city != null && profile.country != null;
        if (same) return; // not moved, already on the map: nothing to look up or send
        final marks = await Geocoding().placemarkFromCoordinates(lat, lng);
        code = marks.map((m) => m.isoCountryCode).whereType<String>().firstOrNull;
        final name = marks.map(cityOf).whereType<String>().firstOrNull;
        if (name != null) city = {'name': name, 'lat': lat, 'lng': lng};
        _lastPos = key;
      }
      code ??= profile.country == null ? PlatformDispatcher.instance.locale.countryCode : null;
      code = code?.toUpperCase();
      final body = <String, Object>{
        if (code != null && RegExp(r'^[A-Z]{2}$').hasMatch(code) && code != profile.country) 'country': code,
        if (city != null && city['name'] != profile.city) 'city': city,
      };
      if (body.isNotEmpty) await _me.patch(body);
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
      final yes = await _dialog(title: 'Join the world map', body: 'See where people are meditating with you right now. We use your approximate location to find your country and your city. Your exact position is never saved or shared, and you can turn this off any time in You → Privacy.', ok: 'Allow location and continue', cancel: 'Not now');
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
    final yes = await _dialog(title: 'Location is off', body: 'Turn location on for WeHum in Settings so your country and city can light up on the map.', ok: 'Open Settings', cancel: 'Not now', icon: Icons.location_off_outlined);
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
