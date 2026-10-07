import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
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
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        unknownRoute: AppPages.pages.firstWhere((p) => p.name == AppRoutes.notFound),
      );
}
