// Sim probe for the free (YouTube) player: opens real videos in the real embedded player and takes pictures over time,
// to see whether YouTube's own ads are shown (an "Ad" badge / "Skip" button / countdown instead of the video).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/features/player/player_args.dart';

const vids = String.fromEnvironment('VIDS', defaultValue: 'bp-2_tAO3NY');
const sid = String.fromEnvironment('SID');

Future<void> settle(WidgetTester t, int ms) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('free player: do ads play', (t) async {
    app.bootstrap();
    await settle(t, 6000);
    await binding.convertFlutterSurfaceToImage();
    for (final id in vids.split(',')) {
      Get.toNamed('/player/free', arguments: PlayerArgs(kind: 'free', title: 'Probe $id', youtubeId: id, sessionId: sid.isEmpty ? null : sid));
      await settle(t, 4000);
      final play = find.byKey(const Key('play-pause'));
      if (play.evaluate().isNotEmpty) await t.tap(play); // what a person does
      for (var k = 0; k < 3; k++) {
        await binding.takeScreenshot('ad_${id}_$k');
        await settle(t, 4000);
      }
      Get.back<void>();
      await settle(t, 1500);
    }
  }, timeout: const Timeout(Duration(minutes: 10)));
}
