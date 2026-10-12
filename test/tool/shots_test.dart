// Visual review aid (not part of the normal suite): renders screens with the mock data and writes PNGs to test/tool/shots/.
//   flutter test --update-goldens test/tool/shots_test.dart            (all)   |   SHOT=silence flutter test ... (name filter)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/app/routes/app_routes.dart';
import '../support/test_env.dart';

const routes = <String, String>{
  'today': AppRoutes.todayMember, 'library': AppRoutes.library, 'silence': AppRoutes.silenceRoomSetup, 'lobby': AppRoutes.groupMeditationLobby, 'next': AppRoutes.nextSit,
  'you': AppRoutes.you, 'together': AppRoutes.together, 'sos': AppRoutes.sosHowCanIHelp, 'directory': AppRoutes.crisisDirectory, 'world': AppRoutes.worldMapWorldVibration,
  'downloads': AppRoutes.downloads, 'privacy': AppRoutes.privacyData, 'byo': AppRoutes.buildYourOwn, 'membership': AppRoutes.membershipPaywall, 'account': AppRoutes.saveYourProgressOptional,
  'time': AppRoutes.setup2MeditationReminder, 'progress': AppRoutes.yourProgress, 'editprofile': AppRoutes.editProfile, 'signup': AppRoutes.signUpWithEmail, 'compose': AppRoutes.dedicate,
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
  for (final e in routes.entries) {
    if (only != null && !only.split(',').contains(e.key)) continue;
    testWidgets('shot ${e.key}', (t) async {
      phone(t);
      t.view.physicalSize = Size(1170, double.parse(Platform.environment['SHOT_H'] ?? '4800')); // tall: the whole page in one picture
      await t.runAsync(loadIcons);
      final env = await TestEnv.create(member: true, onboardingDone: true, prefs: const {'first_name': 'Alex'});
      await t.pumpWidget(env.app(initial: e.value));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 150));
      }
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${e.key}.png'));
      await t.pumpWidget(const SizedBox());
      await env.dispose();
    });
  }
}
