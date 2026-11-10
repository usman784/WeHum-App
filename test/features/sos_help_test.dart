import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../support/test_env.dart';

class _FakeLauncher extends Fake with MockPlatformInterfaceMixin implements UrlLauncherPlatform {
  final launched = <String>[];
  @override
  Future<bool> canLaunch(String url) async => true;
  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  late _FakeLauncher launcher;
  setUp(() {
    Get.reset();
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  testWidgets('SoS: no crisis directory, Contact us emails Raphael, booking says coming soon', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final e = await TestEnv.create(onboardingDone: true);
    await t.pumpWidget(e.app(initial: AppRoutes.sosHowCanIHelp));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    // the crisis directory is gone from this screen
    expect(find.text('Crisis directory'), findsNothing);
    expect(find.byKey(const Key('sos-crisis')), findsNothing);
    expect(find.textContaining('crisis'), findsNothing);

    await t.scrollUntilVisible(find.byKey(const Key('sos-help')), 300, scrollable: find.byType(Scrollable).first);
    // booking link is not ready: a clear message, nothing opens
    expect(find.text('Link coming soon'), findsOneWidget);
    await t.tap(find.text('Book a personal session'));
    await t.pump(const Duration(milliseconds: 600));
    expect(find.textContaining('coming soon'), findsWidgets);
    expect(launcher.launched, isEmpty);
    await t.pump(const Duration(seconds: 5));

    // Contact us → mail to Raphael
    await t.tap(find.byKey(const Key('sos-contact')));
    await t.pump(const Duration(milliseconds: 300));
    expect(launcher.launched, ['mailto:raphael@raphaelreiter.com']);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });
}
