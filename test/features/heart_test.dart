import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/core/health/heart_service.dart';
import 'package:meditation/core/health/hr_summary.dart';
import 'package:meditation/core/theme/app_theme.dart';
import 'package:meditation/features/heart/heart_widgets.dart';

import '../support/fonts.dart';

final _t0 = DateTime.utc(2026, 10, 22, 8);
HrSample s(int sec, int bpm) => HrSample(_t0.add(Duration(seconds: sec)), bpm);

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildTheme(Brightness.dark),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(disableAnimations: reduceMotion), child: w!),
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 390, child: Padding(padding: const EdgeInsets.all(20), child: child)))),
    );

void main() {
  group('parseHeartRateMeasurement (Bluetooth SIG 0x2A37)', () {
    test('8-bit value', () => expect(parseHeartRateMeasurement([0x00, 72])!.bpm, 72));
    test('16-bit value', () => expect(parseHeartRateMeasurement([0x01, 0x48, 0x00])!.bpm, 72));
    test('no skin contact is ignored, contact is read', () {
      expect(parseHeartRateMeasurement([0x04, 72]), isNull); // contact supported, not detected
      expect(parseHeartRateMeasurement([0x06, 72])!.bpm, 72); // contact supported and detected
    });
    test('RR intervals (1/1024 s) after the value; energy expended is skipped', () {
      final r = parseHeartRateMeasurement([0x10, 60, 0x00, 0x04, 0x00, 0x04])!; // 0x0400 = 1024 → 1000 ms
      expect(r.rrMs, [1000.0, 1000.0]);
      final e = parseHeartRateMeasurement([0x18, 60, 0xFF, 0xFF, 0x00, 0x04])!; // energy then one RR
      expect(e.rrMs, [1000.0]);
    });
    test('garbage never throws', () {
      expect(parseHeartRateMeasurement([]), isNull);
      expect(parseHeartRateMeasurement([0x01, 70]), isNull); // 16-bit flag but one byte
      expect(parseHeartRateMeasurement([0x00, 5]), isNull); // not a plausible rate
      expect(parseHeartRateMeasurement([0x01, 0x2C, 0x01]), isNull); // 300 bpm
    });
  });

  group('summarizeSit', () {
    test('nothing usable → null; out-of-range readings are dropped', () {
      expect(summarizeSit(const [], source: HrSource.sensor), isNull);
      expect(summarizeSit([s(0, 0), s(10, 250)], source: HrSource.sensor), isNull);
    });

    test('calm shift is the mean of the last third minus the first third', () {
      // 10 minutes, a reading every 10 s, sliding from 80 down to 62
      final list = [for (var i = 0; i < 60; i++) s(i * 10, 80 - (i * 18 / 59).round())];
      final r = summarizeSit(list, source: HrSource.sensor, sourceName: 'Polar H10')!;
      expect(r.deltaBpm, inInclusiveRange(-16, -12));
      expect(r.minBpm, 62);
      expect(r.maxBpm, 80);
      expect(r.avgBpm, inInclusiveRange(70, 72));
      expect(r.sourceName, 'Polar H10');
      expect(r.trend.length, lessThanOrEqualTo(HrSummary.maxPoints));
      expect(r.trend.first, greaterThan(r.trend.last));
    });

    test('too few readings or too short a span: the average is kept, no shift is claimed', () {
      expect(summarizeSit([s(0, 70)], source: HrSource.health)!.deltaBpm, isNull);
      expect(summarizeSit([s(0, 70), s(60, 60)], source: HrSource.health)!.deltaBpm, isNull); // 60 s apart
      final two = summarizeSit([s(0, 76), s(300, 64)], source: HrSource.health)!;
      expect(two.deltaBpm, -12);
      expect(two.avgBpm, 70);
    });

    test('the shift is clamped to what the server accepts (±60)', () {
      expect(summarizeSit([s(0, 200), s(300, 50)], source: HrSource.health)!.deltaBpm, -60);
    });

    test('unsorted input is fine; HRV is carried and can be added later', () {
      final r = summarizeSit([s(300, 64), s(0, 76)], source: HrSource.health, hrvMs: 41)!;
      expect(r.deltaBpm, -12);
      expect(r.hrvMs, 41);
      expect(r.withHrv(null).hrvMs, 41);
      expect(r.withHrv(55).hrvMs, 55);
    });
  });

  group('rmssd', () {
    test('steady beats → ~0, alternating beats → the swing', () {
      expect(rmssd(List.filled(40, 1000.0)), 0);
      final alt = [for (var i = 0; i < 40; i++) i.isEven ? 950.0 : 1000.0];
      expect(rmssd(alt)!, closeTo(50, .001));
    });
    test('too little data gives null; a jump over 200 ms between beats is ignored', () {
      expect(rmssd(List.filled(10, 1000.0)), isNull);
      final withJump = [for (var i = 0; i < 40; i++) i.isEven ? 950.0 : 1000.0]..[10] = 1900.0; // ectopic-like jump
      expect(rmssd(withJump), isNotNull);
    });
  });

  group('widgets', () {
    setUpAll(loadAppFonts);

    testWidgets('summary card: shift in big type, the line, average / lowest / HRV', (t) async {
      final hr = summarizeSit([for (var i = 0; i < 40; i++) s(i * 15, 78 - i ~/ 3)], source: HrSource.health, sourceName: 'Apple Watch', hrvMs: 48.4)!;
      await t.pumpWidget(host(HeartSummaryCard(hr)));
      expect(find.byKey(const Key('complete-hr')), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('hr-big'))).data!, startsWith('−'));
      expect(find.text('Your heart slowed down by the end of the meditation.'), findsOneWidget);
      expect(find.text('Apple Watch'), findsOneWidget);
      expect(find.text('HRV'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
    });

    testWidgets('summary card with a single reading shows the average and says so', (t) async {
      final hr = summarizeSit([s(0, 68)], source: HrSource.health, sourceName: 'Health Connect')!;
      await t.pumpWidget(host(HeartSummaryCard(hr)));
      expect(t.widget<Text>(find.byKey(const Key('hr-big'))).data, '68');
      expect(find.text('Your wearable shared one reading for this meditation.'), findsOneWidget);
      expect(find.text('HRV'), findsNothing);
    });

    testWidgets('live pill shows the rate and disappears with no reading', (t) async {
      final live = Rxn<int>();
      await t.pumpWidget(host(HeartPill(live: live)));
      expect(find.byKey(const Key('heart-pill')), findsNothing);
      live.value = 72;
      await t.pump();
      expect(find.text('72'), findsOneWidget);
      await t.pump(const Duration(milliseconds: 400)); // the heart is beating
      live.value = null;
      await t.pump();
      expect(find.byKey(const Key('heart-pill')), findsNothing);
    });

    testWidgets('reduced motion: the pill is shown but nothing animates', (t) async {
      final live = Rxn<int>(64);
      await t.pumpWidget(host(HeartPill(live: live), reduceMotion: true));
      await t.pump();
      expect(find.text('64'), findsOneWidget);
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  test('NoHeart is inert', () async {
    const h = NoHeart();
    expect(h.enabled, false);
    await h.begin();
    expect(await h.end(_t0, _t0.add(const Duration(minutes: 5))), isNull);
  });
}
