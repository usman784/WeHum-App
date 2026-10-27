import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../services/logger.dart';
import 'hr_summary.dart';

enum SensorState { idle, scanning, connecting, live, lost }

class _Cancelled implements Exception {
  const _Cancelled();
}

/// A heart-rate sensor over Bluetooth LE using the standard Heart Rate Service (0x180D): chest straps (Polar, Wahoo,
/// Garmin HRM), and watches or bands that broadcast heart rate (Whoop "Heart Rate Broadcast", Garmin "Broadcast Heart
/// Rate", many others). No account, no vendor API. The link is open only while a sit is running (or while the person is
/// pairing), so a strap's battery is not drained and nothing is read in the background.
class HrSensorService extends GetxService {
  static final _service = Guid('180D'), _measurement = Guid('2A37');
  static const _idKey = 'hr.sensor.id', _nameKey = 'hr.sensor.name';

  final bpm = Rxn<int>();
  final state = SensorState.idle.obs;
  final pairedName = RxnString();
  final found = <ScanResult>[].obs;

  String? _pairedId;
  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _values;
  StreamSubscription<BluetoothConnectionState>? _link;
  StreamSubscription<List<ScanResult>>? _scan;
  Timer? _retry;
  bool _sitOn = false;
  DateTime? _lastSample;
  final _samples = <HrSample>[];
  final _rr = <double>[];
  int _retries = 0;

  bool get paired => _pairedId != null;
  bool get sitActive => _sitOn;

  @override
  void onInit() {
    super.onInit();
    try {
      final s = GetStorage();
      _pairedId = s.read<String>(_idKey);
      pairedName.value = s.read<String>(_nameKey);
    } catch (_) {/* storage not ready (tests): nothing paired */}
  }

  @override
  void onClose() {
    _scan?.cancel();
    _retry?.cancel();
    _drop();
    super.onClose();
  }

  Future<bool> get supported async => await FlutterBluePlus.isSupported;

  /// Bluetooth switched on (Android can ask to switch it on; iOS shows its own prompt on first use).
  Future<bool> ensureOn() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      var st = await FlutterBluePlus.adapterState.first;
      if (st == BluetoothAdapterState.unknown) st = await FlutterBluePlus.adapterState.firstWhere((s) => s != BluetoothAdapterState.unknown).timeout(const Duration(seconds: 3), onTimeout: () => BluetoothAdapterState.unknown);
      if (st == BluetoothAdapterState.on) return true;
      if (Platform.isAndroid) await FlutterBluePlus.turnOn();
      return (await FlutterBluePlus.adapterState.firstWhere((s) => s == BluetoothAdapterState.on).timeout(const Duration(seconds: 8))) == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  // ───────────── pairing (Heart rate settings page)

  Future<bool> startScan() async {
    if (!await ensureOn()) return false;
    found.clear();
    state.value = SensorState.scanning;
    await _scan?.cancel();
    _scan = FlutterBluePlus.onScanResults.listen((r) {
      for (final e in r) {
        if (found.indexWhere((x) => x.device.remoteId == e.device.remoteId) < 0) found.add(e);
      }
      found.sort((a, b) => b.rssi.compareTo(a.rssi)); // strongest (nearest) first
    });
    try {
      await FlutterBluePlus.startScan(withServices: [_service], timeout: const Duration(seconds: 15));
    } catch (e) {
      logd('hr', 'scan failed: $e');
    }
    if (state.value == SensorState.scanning) state.value = _device != null && _link != null ? SensorState.live : SensorState.idle;
    return true;
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {/* not scanning */}
    await _scan?.cancel();
    _scan = null;
    if (state.value == SensorState.scanning) state.value = SensorState.idle;
  }

  /// Connects, checks that it really sends heart rate, and remembers it. False when it can't be used.
  Future<bool> pair(BluetoothDevice d) async {
    await stopScan();
    final ok = await _connect(d);
    if (!ok) return false;
    _pairedId = d.remoteId.str;
    pairedName.value = d.platformName.isEmpty ? 'Heart-rate sensor' : d.platformName;
    try {
      GetStorage()
        ..write(_idKey, _pairedId)
        ..write(_nameKey, pairedName.value);
    } catch (_) {/* pair again next launch */}
    return true;
  }

  Future<void> forget() async {
    await _drop();
    _pairedId = null;
    pairedName.value = null;
    try {
      GetStorage()
        ..remove(_idKey)
        ..remove(_nameKey);
    } catch (_) {/* nothing stored */}
  }

  /// Leaves the pairing screen: closes the link unless a sit is using it.
  Future<void> releaseIfIdle() async {
    await stopScan();
    if (!_sitOn) await _drop();
  }

  // ───────────── a sit

  /// Starts collecting. Connects to the paired sensor in the background; the player never waits for it.
  Future<void> beginSit() async {
    _sitOn = true;
    _samples.clear();
    _rr.clear();
    _lastSample = null;
    _retries = 0;
    if (_pairedId == null || state.value == SensorState.live) return;
    await connectPaired();
    if (_sitOn && state.value != SensorState.live) _scheduleRetry();
  }

  /// Opens the link to the paired sensor (also used by "Test connection"). False when not paired, Bluetooth is off, or it can't be reached.
  Future<bool> connectPaired() async {
    final id = _pairedId;
    if (id == null || state.value == SensorState.live) return id != null;
    if (!await ensureOn()) return false;
    return _connect(BluetoothDevice.fromId(id));
  }

  /// Ends collecting and closes the link. Null when the sensor gave too little to say anything (under 10 readings).
  Future<HrSummary?> endSit() async {
    _sitOn = false;
    _retry?.cancel();
    final s = List<HrSample>.of(_samples);
    final rr = List<double>.of(_rr);
    _samples.clear();
    _rr.clear();
    unawaited(_drop());
    if (s.length < 10) return null;
    return summarizeSit(s, source: HrSource.sensor, sourceName: pairedName.value, hrvMs: rmssd(rr));
  }

  void cancelSit() {
    _sitOn = false;
    _retry?.cancel();
    _samples.clear();
    _rr.clear();
    unawaited(_drop());
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_sitOn || _pairedId == null || _retries >= 4) return;
    _retries++;
    _retry = Timer(const Duration(seconds: 6), () async {
      if (!_sitOn || state.value == SensorState.live) return;
      await _connect(BluetoothDevice.fromId(_pairedId!));
      if (_sitOn && state.value != SensorState.live) _scheduleRetry();
    });
  }

  // ───────────── link

  /// Bumped by every [_drop]; a connect that finds it changed was cancelled (the sit ended, or another connect started)
  /// and must close its own link instead of installing it.
  int _gen = 0;

  Future<bool> _connect(BluetoothDevice d) async {
    await _drop();
    final gen = _gen;
    bool stale() => gen != _gen;
    state.value = SensorState.connecting;
    try {
      await d.connect(timeout: const Duration(seconds: 10), mtu: null);
      if (stale()) throw const _Cancelled();
      final services = await d.discoverServices();
      if (stale()) throw const _Cancelled();
      BluetoothCharacteristic? ch;
      for (final s in services) {
        if (s.uuid != _service) continue;
        for (final c in s.characteristics) {
          if (c.uuid == _measurement) ch = c;
        }
      }
      if (ch == null) throw StateError('no heart-rate characteristic');
      _device = d;
      _link = d.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected && _device == d) {
          bpm.value = null;
          state.value = SensorState.lost;
          if (_sitOn) _scheduleRetry();
        }
      });
      _values = ch.onValueReceived.listen(_onValue);
      await ch.setNotifyValue(true);
      if (stale()) throw const _Cancelled();
      _retries = 0;
      state.value = SensorState.live;
      return true;
    } catch (e) {
      if (e is! _Cancelled) logd('hr', 'connect failed: $e');
      if (stale()) {
        try {
          await d.disconnect(); // our link, left over from a cancelled connect (the newer owner has its own)
        } catch (_) {/* already gone */}
      } else {
        await _drop();
      }
      return false;
    }
  }

  void _onValue(List<int> data) {
    final r = parseHeartRateMeasurement(data);
    if (r == null) {
      bpm.value = null; // no contact: show nothing rather than a stale number
      return;
    }
    bpm.value = r.bpm;
    if (!_sitOn) return;
    final now = DateTime.now();
    if (_lastSample == null || now.difference(_lastSample!) >= const Duration(milliseconds: 900)) {
      _lastSample = now;
      if (_samples.length < 4 * 3600) _samples.add(HrSample(now, r.bpm));
    }
    if (r.rrMs.isNotEmpty && _rr.length < 20000) _rr.addAll(r.rrMs);
  }

  Future<void> _drop() async {
    _gen++;
    final d = _device;
    _device = null;
    await _values?.cancel();
    await _link?.cancel();
    _values = null;
    _link = null;
    bpm.value = null;
    if (state.value != SensorState.scanning) state.value = SensorState.idle;
    if (d != null) {
      try {
        await d.disconnect();
      } catch (_) {/* already gone */}
    }
  }
}
