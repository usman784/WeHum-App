import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_pages.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/data/contracts/auth_repository.dart';
import 'package:meditation/core/data/contracts/bootstrap_repository.dart';
import 'package:meditation/core/data/mock/mock_repositories.dart';
import 'package:meditation/core/data/models/bootstrap.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/network/session_store.dart';
import 'package:meditation/core/services/auth_service.dart';
import 'package:meditation/core/services/config_service.dart';
import 'package:meditation/core/services/crash_service.dart';
import 'package:meditation/core/services/time_service.dart';
import 'package:meditation/core/theme/app_theme.dart';
import 'package:meditation/core/theme/theme_controller.dart';

import '../core/fake_adapter.dart';

class FlakyBootstrap implements BootstrapRepository {
  FlakyBootstrap(this.bad);
  Bootstrap? bad;
  int calls = 0;
  @override
  Future<Bootstrap> bootstrap() async {
    calls++;
    if (calls == 1) throw ApiException(ErrorCode.network);
    return MockBootstrapRepository().bootstrap();
  }
}

void wire(BootstrapRepository boot) {
  Get.reset();
  final store = SessionStore(MemoryKv());
  Get.put(CrashService());
  Get.put(TimeService());
  final auth = AuthService(MockAuthRepository(), store, Get.find(),
      device: (id) async => DeviceInfoDto(installId: id, platform: 'ios', appVersion: '1.0.0', timezone: 'UTC'));
  Get.put(auth);
  Get.put(ConfigService(boot, Get.find()));
}

Widget app() => GetMaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );

void main() {
  testWidgets('splash: guest session + bootstrap, then the first intro screen', (t) async {
    wire(MockBootstrapRepository());
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.byKey(const Key('placeholder-name')), findsOneWidget);
    expect(find.text('intro1Welcome'), findsOneWidget);
    expect(Get.find<AuthService>().me.value!.isGuest, true);
    expect(Get.find<ConfigService>().current.value!.catalogVersion, 1);
  });

  testWidgets('splash: offline shows retry, retry recovers', (t) async {
    wire(FlakyBootstrap(null));
    await t.pumpWidget(app());
    await t.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
    await t.tap(find.byKey(const Key('splash-retry')));
    await t.pumpAndSettle();
    expect(find.text('intro1Welcome'), findsOneWidget);
  });

  test('every route constant has a page', () {
    final names = AppPages.pages.map((p) => p.name).toSet();
    expect(names.length, AppPages.pages.length, reason: 'no duplicate routes');
    expect(names, containsAll([AppRoutes.splash, AppRoutes.todayMember, AppRoutes.updateRequired, AppRoutes.notFound]));
  });

  testWidgets('theme: dark and light build and switch live', (t) async {
    Get.reset();
    await t.pumpWidget(GetMaterialApp(
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: Builder(builder: (c) => Scaffold(body: Text('x', style: TextStyle(color: Theme.of(c).colorScheme.onSurface)))),
    ));
    expect(Theme.of(t.element(find.text('x'))).brightness, Brightness.dark);
    Get.changeThemeMode(ThemeMode.light);
    await t.pumpAndSettle();
    expect(Theme.of(t.element(find.text('x'))).brightness, Brightness.light);
  });

  testWidgets('ThemeController keeps its choice', (t) async {
    Get.reset();
    await t.pumpWidget(const GetMaterialApp(home: SizedBox()));
    String? stored;
    final c = ThemeController(load: () => stored, save: (v) => stored = v)..onInit();
    expect(c.mode.value, ThemeMode.system);
    c.set(ThemeMode.dark);
    expect(stored, 'dark');
    final again = ThemeController(load: () => stored, save: (v) => stored = v)..onInit();
    expect(again.mode.value, ThemeMode.dark);
  });
}
