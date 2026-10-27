import 'dart:async';
import 'dart:io' show Platform;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:health/health.dart';
import '../services/logger.dart';
import 'hr_summary.dart';

enum HealthConnectResult { connected, denied, unavailable }

/// Reads heart rate (and HRV) for the time of a sit from Apple Health (iOS) or Health Connect (Android), with the
/// person's permission. Read-only: nothing is written to Health and nothing but the summary numbers is sent anywhere.
/// This one source covers Apple Watch, Garmin, Whoop, Samsung, Fitbit and every other wearable that syncs to Health.
class HealthService extends GetxService {
  HealthService({Health? health}) : _health = health ?? Health();
  final Health _health;

  static const _key = 'health.connected';
  final connected = false.obs;
  bool _configured = false;

  /// iOS cannot tell us whether read access was granted (a privacy rule), so "connected" means the person went through
  /// the permission sheet; no readings then simply means no summary.
  static List<HealthDataType> get _types => [HealthDataType.HEART_RATE, if (Platform.isIOS) HealthDataType.HEART_RATE_VARIABILITY_SDNN else HealthDataType.HEART_RATE_VARIABILITY_RMSSD];

  String get platformName => Platform.isIOS ? 'Apple Health' : 'Health Connect';

  @override
  void onInit() {
    super.onInit();
    try {
      connected.value = GetStorage().read<bool>(_key) ?? false;
    } catch (_) {/* storage not ready (tests): not connected */}
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Android only: Health Connect is a separate app on Android 13 and older.
  Future<bool> get available async {
    if (!Platform.isAndroid) return true;
    try {
      await _configure();
      return await _health.getHealthConnectSdkStatus() == HealthConnectSdkStatus.sdkAvailable;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system permission sheet.
  Future<HealthConnectResult> connect() async {
    try {
      await _configure();
      if (!await available) return HealthConnectResult.unavailable;
      final ok = await _health.requestAuthorization(_types, permissions: [for (final _ in _types) HealthDataAccess.READ]);
      // Android answers truthfully, and heart rate alone is enough (HRV may be refused); on iOS `true` only means the sheet was shown
      final granted = Platform.isAndroid ? await _health.hasPermissions([HealthDataType.HEART_RATE]) == true : ok;
      _set(granted);
      return granted ? HealthConnectResult.connected : HealthConnectResult.denied;
    } catch (e) {
      logd('health', 'connect failed: $e');
      return HealthConnectResult.denied;
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (_) {/* the store may be missing: nothing to do */}
  }

  Future<void> disconnect() async {
    _set(false);
    if (Platform.isAndroid) {
      try {
        await _health.revokePermissions();
      } catch (_) {/* best effort */}
    }
  }

  void _set(bool v) {
    connected.value = v;
    try {
      GetStorage().write(_key, v);
    } catch (_) {/* not persisted: the person connects again next launch */}
  }

  /// Heart rate in [from]..[to]. The window starts a few minutes early so a sparse wearable (one reading every few
  /// minutes) still gives a "before" value. Null when there is nothing, on any error, or after [timeout]: the payoff never waits long.
  Future<HrSummary?> readSit(DateTime from, DateTime to, {Duration timeout = const Duration(seconds: 3)}) async {
    if (!connected.value) return null;
    try {
      return await _read(from, to).timeout(timeout);
    } catch (e) {
      logd('health', 'read failed: $e');
      return null;
    }
  }

  Future<HrSummary?> _read(DateTime from, DateTime to) async {
    await _configure();
    final start = from.subtract(const Duration(minutes: 3)), end = to.add(const Duration(minutes: 1));
    final points = await _health.getHealthDataFromTypes(types: _types, startTime: start, endTime: end);
    final hr = <HrSample>[];
    final hrv = <double>[];
    String? name;
    for (final p in points) {
      final v = p.value;
      if (v is! NumericHealthValue) continue;
      if (p.type == HealthDataType.HEART_RATE) {
        hr.add(HrSample(p.dateFrom, v.numericValue.round()));
        name ??= p.sourceName.isEmpty ? null : p.sourceName;
      } else if (v.numericValue > 0 && v.numericValue < 300) {
        hrv.add(v.numericValue.toDouble());
      }
    }
    final s = summarizeSit(hr, source: HrSource.health, sourceName: name ?? platformName);
    if (s == null) return null;
    return hrv.isEmpty ? s : s.withHrv(hrv.reduce((a, b) => a + b) / hrv.length);
  }
}
