// Sim flow against the local backend: swipe-to-delete notifications, profile edit rules, a real session playing.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/bootstrap.dart' as app;
import 'package:meditation/core/data/models/activity.dart' show PlaySession;
import 'package:meditation/features/player/player_args.dart';

const sid = String.fromEnvironment('SID');

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('notifications, profile, player', (t) async {
    app.bootstrap();
    await settle(t, 6000);
    await binding.convertFlutterSurfaceToImage();
    // 1) notifications: swipe, delete icon, confirmation
    Get.offAllNamed('/today');
    await settle(t, 2500);
    await binding.takeScreenshot('n0_today');
    Get.toNamed('/notifications');
    await settle(t, 3000);
    await binding.takeScreenshot('n1_list');
    final items = find.byWidgetPredicate((w) => w.key is Key && (w.key.toString().contains('inbox-')));
    debugPrint('FLOW inbox rows: ${items.evaluate().length}');
    await t.drag(items.first, const Offset(-260, 0));
    await settle(t, 800);
    await binding.takeScreenshot('n2_swiped');
    await t.tap(find.text('Delete').first);
    await settle(t, 1200);
    await binding.takeScreenshot('n3_confirm');
    await t.tap(find.byKey(const Key('confirm-delete-notification')));
    await settle(t, 2000);
    await binding.takeScreenshot('n4_deleted');
    debugPrint('FLOW inbox rows after delete: ${find.byWidgetPredicate((w) => w.key is Key && (w.key.toString().contains('inbox-'))).evaluate().length}');
    // 2) profile
    Get.offAllNamed('/profile/edit');
    await settle(t, 2500);
    await t.enterText(find.byKey(const Key('profile-last')), 'Sim');
    await settle(t, 600);
    await t.tap(find.byKey(const Key('profile-save')));
    await settle(t, 3000);
    await binding.takeScreenshot('p1_saved');
    // 3) player with a real session
    Get.offAllNamed('/today');
    await settle(t, 1500);
    Get.toNamed('/player', arguments: const PlayerArgs(kind: 'solo', title: 'Steady Under Pressure', subtitle: 'with Raphael', sessionId: sid, target: PlaySession(sid), durationSec: 600));
    await settle(t, 9000);
    await binding.takeScreenshot('y1_player');
    await t.tap(find.byKey(const Key('play-pause')));
    await settle(t, 1500);
    await binding.takeScreenshot('y2_paused');
    debugPrint('FLOW done');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
