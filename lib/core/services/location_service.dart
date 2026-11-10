import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../data/contracts/repositories.dart';

/// Where the "meditating now" map puts you. The map is country level only (spec: no GPS): we ask for approximate
/// location once, turn it into a 2-letter country code ON THE PHONE and send only that code. Coordinates never leave
/// the device. Without permission the phone's region setting is used, so nobody is missing from the map.
class LocationService extends GetxService {
  LocationService(this._me);
  final MeRepository _me;

  DateTime? _lastSync;
  bool _promptedThisSession = false;

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
    if (_promptedThisSession && !force) return;
    final p = await status();
    if (granted(p)) return unawaited(sync());
    _promptedThisSession = true;
    if (p == LocationPermission.denied) {
      if (await _dialog(title: 'Show your country on the map', body: 'WeHum places you on the world map of people meditating now, by country only. We use your approximate location once to find your country. Your exact position is never saved or shared.', ok: 'Allow location and continue', cancel: 'Not now') == true) {
        await requestOs();
      } else {
        unawaited(sync()); // phone-region fallback
      }
    } else if (p == LocationPermission.deniedForever) {
      if (await _dialog(title: 'Location is off', body: 'Location is turned off for WeHum, so your country cannot appear on the map. You can turn it on in Settings → WeHum → Location.', ok: 'Open Settings', cancel: 'Not now') == true) {
        await Geolocator.openAppSettings();
      } else {
        unawaited(sync());
      }
    }
  }

  Future<bool?> _dialog({required String title, required String body, required String ok, required String cancel}) => Get.dialog<bool>(
        AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(key: const Key('location-not-now'), onPressed: () => Get.back(result: false), child: Text(cancel)),
            TextButton(key: const Key('location-allow'), onPressed: () => Get.back(result: true), child: Text(ok)),
          ],
        ),
      );
}
