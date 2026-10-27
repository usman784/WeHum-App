import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../../core/health/health_service.dart';
import '../../core/health/hr_sensor_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/surfaces.dart';

class HeartSetupController extends GetxController {
  late final HealthService health = Get.find();
  late final HrSensorService sensor = Get.find();
  final healthBusy = false.obs;
  final pairBusy = false.obs;
  final note = RxnString();
  /// Android 13 and older: Health Connect is a separate app.
  final healthMissing = false.obs;

  Future<void> connectHealth() async {
    healthBusy.value = true;
    note.value = null;
    final r = await health.connect();
    healthMissing.value = r == HealthConnectResult.unavailable;
    if (r == HealthConnectResult.denied) note.value = 'Access to heart rate was not granted. You can change it in ${Platform.isIOS ? 'the Health app → Sharing → Apps' : 'Health Connect → App permissions'}.';
    healthBusy.value = false;
  }

  Future<void> pair(BluetoothDevice d) async {
    pairBusy.value = true;
    note.value = null;
    final ok = await sensor.pair(d);
    if (!ok) note.value = 'Couldn’t connect. Check that heart-rate broadcast is on and the sensor isn’t connected to another app.';
    pairBusy.value = false;
  }

  Future<void> test() async {
    note.value = null;
    if (!await sensor.connectPaired()) note.value = 'Couldn’t reach ${sensor.pairedName.value ?? 'the sensor'}. Wake it up, keep it close and check broadcast is on.';
  }

  @override
  void onClose() {
    sensor.releaseIfIdle();
    super.onClose();
  }
}

/// Heart rate settings: a Health source for the after-sit summary, a Bluetooth sensor for the live reading.
class HeartRatePage extends StatelessWidget {
  const HeartRatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(HeartSetupController());
    final health = ctrl.health.platformName;
    return AppScaffold(
      title: 'Heart rate',
      body: Obx(() {
        final connected = ctrl.health.connected.value;
        final name = ctrl.sensor.pairedName.value;
        final paired = ctrl.sensor.paired;
        return ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
          Text('See how your body settles. Your heart rate is read only while you meditate, and only the average and the shift are saved to your account.', style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          Text('AFTER EACH MEDITATION', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          AppCard(
            key: const Key('hr-health'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Badge(Icons.watch_outlined, connected),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(health, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                  Text(connected ? 'Connected' : 'Not connected', style: AppText.caption.copyWith(color: connected ? c.success : c.textSecondary)),
                ])),
              ]),
              const SizedBox(height: 10),
              Text('Apple Watch, Garmin, Whoop, Samsung, Fitbit and any other wearable that syncs to $health. A summary appears after each meditation, once your device has synced.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              const SizedBox(height: 14),
              if (ctrl.healthMissing.value)
                PrimaryButton('Get Health Connect', key: const Key('hr-install'), icon: Icons.download_rounded, onPressed: ctrl.health.installHealthConnect)
              else if (connected)
                OutlineButton('Disconnect', key: const Key('hr-health-off'), onPressed: ctrl.health.disconnect)
              else
                PrimaryButton('Connect $health', key: const Key('hr-health-on'), loading: ctrl.healthBusy.value, onPressed: ctrl.connectHealth),
            ]),
          ),
          const SizedBox(height: 22),
          Text('DURING THE MEDITATION', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          AppCard(
            key: const Key('hr-sensor'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                _Badge(Icons.sensors_rounded, paired),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(paired ? (name ?? 'Heart-rate sensor') : 'Bluetooth sensor', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                  Text(paired ? 'Paired · connects when a meditation starts' : 'Not paired', style: AppText.caption.copyWith(color: paired ? c.success : c.textSecondary)),
                ])),
                if (ctrl.sensor.bpm.value != null) Text('${ctrl.sensor.bpm.value} bpm', key: const Key('hr-test'), style: AppText.navTitle.copyWith(color: c.emberText, fontFeatures: AppText.tabular)),
              ]),
              const SizedBox(height: 10),
              Text('Shows your heart rate live on the player. Works with chest straps (Polar, Wahoo, Garmin HRM) and with watches or bands that can broadcast heart rate: turn on “Heart Rate Broadcast” on Whoop, or “Broadcast Heart Rate” on a Garmin.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              const SizedBox(height: 14),
              if (paired) ...[
                SecondaryButton('Test connection', key: const Key('hr-test-btn'), icon: Icons.favorite_border_rounded, loading: ctrl.sensor.state.value == SensorState.connecting, onPressed: ctrl.test),
                const SizedBox(height: 4),
                TextLink('Forget this sensor', key: const Key('hr-forget'), color: c.textSecondary, onPressed: ctrl.sensor.forget),
              ] else
                PrimaryButton('Find a sensor', key: const Key('hr-find'), icon: Icons.bluetooth_searching_rounded, loading: ctrl.pairBusy.value, onPressed: () => _scanSheet(context, ctrl)),
            ]),
          ),
          if (ctrl.note.value != null)
            Padding(padding: const EdgeInsets.only(top: 14), child: Text(ctrl.note.value!, key: const Key('hr-note'), style: AppText.bodySmall.copyWith(color: c.dangerText))),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lock_outline_rounded, size: 16, color: c.textTertiary),
            const SizedBox(width: 8),
            Expanded(child: Text('Heart-rate data is read with your permission and never sold or shared. Readings stay on your phone; WeHum saves only the average and the change for each meditation. You can disconnect at any time.', style: AppText.caption.copyWith(color: c.textTertiary))),
          ]),
        ]);
      }),
    );
  }

  Future<void> _scanSheet(BuildContext context, HeartSetupController ctrl) async {
    final started = ctrl.sensor.startScan();
    await showAppSheet<void>(context, title: 'Find a sensor', builder: (ctx) => _ScanList(ctrl: ctrl, started: started));
    await ctrl.sensor.stopScan();
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.on);
  final IconData icon;
  final bool on;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(width: 44, height: 44, decoration: BoxDecoration(color: on ? c.emberDeep : c.surfaceAlt, shape: BoxShape.circle), child: Icon(icon, color: on ? c.emberText : c.textSecondary));
  }
}

class _ScanList extends StatelessWidget {
  const _ScanList({required this.ctrl, required this.started});
  final HeartSetupController ctrl;
  final Future<bool> started;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FutureBuilder<bool>(
      future: started,
      builder: (ctx, snap) {
        if (snap.hasData && snap.data == false) {
          return Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('Bluetooth is off or not allowed. Turn it on in Settings to find a sensor.', key: const Key('hr-bt-off'), textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)));
        }
        return Obx(() {
          final list = ctrl.sensor.found;
          final scanning = ctrl.sensor.state.value == SensorState.scanning;
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Wake your sensor (wet the straps, or turn on heart-rate broadcast) and keep it close.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            const SizedBox(height: 12),
            if (list.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: scanning ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.4)) : Text('No sensors found.', style: AppText.body.copyWith(color: c.textSecondary))))
            else
              for (final r in list)
                ListRow(
                  key: Key('sensor-${r.device.remoteId.str}'),
                  title: r.device.platformName.isEmpty ? (r.advertisementData.advName.isEmpty ? 'Heart-rate sensor' : r.advertisementData.advName) : r.device.platformName,
                  subtitle: _signal(r.rssi),
                  leading: Icon(Icons.favorite_border_rounded, color: c.emberText),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await ctrl.pair(r.device);
                  },
                ),
            if (!scanning && list.isNotEmpty) TextLink('Search again', onPressed: ctrl.sensor.startScan),
            if (!scanning && list.isEmpty) TextLink('Search again', key: const Key('hr-rescan'), onPressed: ctrl.sensor.startScan),
          ]);
        });
      },
    );
  }

  static String _signal(int rssi) => rssi > -60 ? 'Very close' : (rssi > -78 ? 'Nearby' : 'Far');
}
