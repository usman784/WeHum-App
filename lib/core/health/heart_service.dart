import 'dart:async';
import 'package:get/get.dart';
import '../services/config_service.dart';
import 'health_service.dart';
import 'hr_sensor_service.dart';
import 'hr_summary.dart';

/// What the player needs from heart-rate tracking. Injectable so the controller is testable without Bluetooth or Health.
abstract class HeartPort {
  /// The reading to show during the sit (a live sensor only); null when there is none.
  Rxn<int> get live;
  /// Whether any source is set up (and the feature is on): the player shows the live pill only then.
  bool get enabled;
  Future<void> begin();
  /// Closes the sit and returns its numbers (null when nothing usable). Never throws, never waits long.
  Future<HrSummary?> end(DateTime from, DateTime to);
  void cancel();
}

class NoHeart implements HeartPort {
  const NoHeart();
  @override
  Rxn<int> get live => Rxn<int>();
  @override
  bool get enabled => false;
  @override
  Future<void> begin() async {}
  @override
  Future<HrSummary?> end(DateTime from, DateTime to) async => null;
  @override
  void cancel() {}
}

/// A live Bluetooth sensor wins (it has every beat of the sit); otherwise whatever Apple Health / Health Connect has
/// for the time of the sit. Behind the CMS flag `features.heartRate`.
class HeartService extends GetxService implements HeartPort {
  HeartService(this.health, this.sensor, this._config);
  final HealthService health;
  final HrSensorService sensor;
  final ConfigService _config;

  bool get featureOn => _config.feature('heartRate');
  bool get anySource => health.connected.value || sensor.paired;

  @override
  Rxn<int> get live => sensor.bpm;
  @override
  bool get enabled => featureOn && anySource;

  @override
  Future<void> begin() async {
    if (!enabled || !sensor.paired) return;
    unawaited(sensor.beginSit().catchError((_) {})); // connects in the background; the sit never waits
  }

  @override
  Future<HrSummary?> end(DateTime from, DateTime to) async {
    if (!enabled) {
      sensor.cancelSit();
      return null;
    }
    HrSummary? s;
    try {
      s = await sensor.endSit();
    } catch (_) {/* fall through to Health */}
    // with a sensor summary Health only adds HRV: don't hold the payoff for it
    final h = await health.readSit(from, to, timeout: s == null ? const Duration(seconds: 3) : const Duration(seconds: 1));
    if (s == null) return h;
    return s.hrvMs == null && h?.hrvMs != null ? s.withHrv(h!.hrvMs) : s;
  }

  @override
  void cancel() => sensor.cancelSit();
}
