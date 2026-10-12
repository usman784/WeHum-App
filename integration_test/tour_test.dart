// Sim tour: boots the real app against a local backend and visits every screen, saving a screenshot of each
// and listing framework errors (overflow, exceptions). Run with `flutter drive` (see test_driver/).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:meditation/bootstrap.dart' as app;

const sid = String.fromEnvironment('SID');
const fid = String.fromEnvironment('FID');
const tid = String.fromEnvironment('TID');
const pid = String.fromEnvironment('PID');
const teid = String.fromEnvironment('TEID');
const cid = String.fromEnvironment('CID');

Future<void> settle(WidgetTester t, [int ms = 1500]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final errors = <String>[];
  testWidgets('tour', (t) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      errors.add('${Get.currentRoute}: ${d.exceptionAsString().split('\n').first}');
      prev?.call(d);
    };
    app.bootstrap();
    await settle(t, 6000);
    await binding.convertFlutterSurfaceToImage();
    Future<void> shot(String name) async {
      await settle(t, 1800);
      await binding.takeScreenshot(name);
    }

    await shot('00_start');
    // onboarding in order
    final onboarding = ['/intro/1', '/intro/2', '/intro/3', '/intro/4', '/setup/name', '/setup/time', '/setup/permission', '/start', '/welcome', '/account/save', '/membership', '/account/save-free', '/account/email', '/login', '/login/forgot', '/login/check'];
    final member = <String>[
      '/today', '/motd', '/today-free', '/world', '/message/archive', '/notifications', '/sos', '/sos/directory', '/library', '/theme/$tid', '/search', '/programs', '/program/$pid', '/teacher/$teid',
      '/recipes', '/byo', '/byo/advanced', '/session/$sid', '/session/$fid', '/preview/$sid', '/player', '/player/free', '/complete', '/share', '/dedications/$sid', '/dedications/compose',
      '/silence', '/silence/run', '/together', '/lobby', '/sit/next', '/you', '/progress', '/profile/edit', '/reminders', '/downloads', '/privacy', '/help', '/membership/manage',
      '/membership/trial-ending', '/membership/billing', '/membership/ended', '/offline', '/update', '/soon/challenges', '/challenge/$cid', '/soon/gratitude', '/soon/breathwork', '/soon/breath-pattern',
    ];
    var n = 1;
    for (final r in [...onboarding, ...member]) {
      try {
        Get.offAllNamed('/today');
        await settle(t, 400);
        Get.toNamed(r);
      } catch (e) {
        errors.add('$r: nav failed $e');
      }
      final before = errors.length;
      await shot('${(n++).toString().padLeft(2, '0')}_${r.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}');
      final ex = t.takeException();
      if (ex != null) errors.add('$r: exception ${ex.toString().split('\n').first}');
      debugPrint('VISITED $r ${errors.length > before ? 'ERRORS' : 'ok'}');
    }
    debugPrint('ERRORS_BEGIN\n${errors.join('\n')}\nERRORS_END');
  }, timeout: const Timeout(Duration(minutes: 25)));
}
