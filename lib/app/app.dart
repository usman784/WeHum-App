import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/services/crash_service.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

class WeHumApp extends StatelessWidget {
  const WeHumApp({super.key});

  @override
  Widget build(BuildContext context) => GetMaterialApp(
        title: 'WeHum',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: Get.isRegistered<ThemeController>() ? Get.find<ThemeController>().mode.value : ThemeMode.system,
        initialBinding: InitialBinding(),
        routingCallback: (r) {
          final name = r?.current;
          if (name != null && Get.isRegistered<CrashService>()) {
            Get.find<CrashService>()
              ..breadcrumb('route $name', category: 'navigation')
              ..tag('screen', name);
          }
        },
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        unknownRoute: AppPages.pages.firstWhere((p) => p.name == AppRoutes.notFound),
      );
}
