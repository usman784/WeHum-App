// Visual review aid (not part of the normal suite): renders screens with the mock data and writes PNGs to test/tool/shots/.
//   flutter test --update-goldens tool/shots_test.dart            (all)   |   SHOT=silence flutter test ... (name filter)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:get/get.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/features/player/player_args.dart';
import 'package:meditation/features/player/controllers/player_controller.dart' show CompleteArgs;
import '../test/support/test_env.dart';

const routes = <String, String>{
  'today': AppRoutes.todayMember, 'library': AppRoutes.library, 'silence': AppRoutes.silenceRoomSetup, 'lobby': AppRoutes.groupMeditationLobby, 'next': AppRoutes.nextSit,
  'you': AppRoutes.you, 'together': AppRoutes.together, 'sos': AppRoutes.sosHowCanIHelp, 'directory': AppRoutes.crisisDirectory, 'world': AppRoutes.worldMapWorldVibration,
  'downloads': AppRoutes.downloads, 'privacy': AppRoutes.privacyData, 'byo': AppRoutes.buildYourOwn, 'membership': AppRoutes.membershipPaywall, 'account': AppRoutes.saveYourProgressOptional,
  'time': AppRoutes.setup2MeditationReminder, 'progress': AppRoutes.yourProgress, 'editprofile': AppRoutes.editProfile, 'signup': AppRoutes.signUpWithEmail, 'compose': AppRoutes.dedicate,
  'preview': '/preview/s-sleep', 'challenge': '/challenge/c7',
};

const sid = '11111111-1111-4111-8111-111111111111';
PlayerArgs _motd() => const PlayerArgs(kind: 'motd', mode: 'solo', title: 'Steady Under Pressure', subtitle: 'with Raphael', sessionId: sid, date: '2026-10-07', lengthMin: 10, target: PlayMotd('2026-10-07', 10), durationSec: 600);
/// Screens that need arguments: opened from the Today page.
final special = <String, void Function()>{
  'player': () => Get.toNamed(AppRoutes.playerPresenceRing, arguments: _motd()),
  'complete': () => Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(player: _motd(), record: MeditationRecord(id: 'm-1', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 7, 8), endedAt: DateTime.utc(2026, 10, 7, 8, 10), durationSec: 600, completed: true), counted: true)),
  'message': () => Get.toNamed('/message/2026-10-12', arguments: {'date': '2026-10-12'}),
};

Future<void> loadIcons() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/Users/apple/development/flutter';
  final f = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!f.existsSync()) return;
  final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

void main() {
  final only = Platform.environment['SHOT'];
  for (final e in [...routes.entries, ...special.keys.map((k) => MapEntry(k, ''))]) {
    if (only != null && !only.split(',').contains(e.key)) continue;
    testWidgets('shot ${e.key}', (t) async {
      phone(t);
      t.view.physicalSize = Size(1170, double.parse(Platform.environment['SHOT_H'] ?? '4800')); // tall: the whole page in one picture
      await t.runAsync(loadIcons);
      final env = await TestEnv.create(member: true, onboardingDone: true, prefs: const {'first_name': 'Alex'});
      await t.pumpWidget(env.app(initial: e.value.isEmpty ? AppRoutes.todayMember : e.value));
      if (e.value.isEmpty) {
        for (var i = 0; i < 6; i++) {
          await t.pump(const Duration(milliseconds: 150));
        }
        special[e.key]!();
      }
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../test/tool/shots/${e.key}.png'));
      await t.pumpWidget(const SizedBox());
      await env.dispose();
    });
  }
}
