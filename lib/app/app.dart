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
        themeMode: Get.isRegistered<ThemeController>() ? Get.find<ThemeController>().mode.value : ThemeMode.dark,
        initialBinding: InitialBinding(),
        // A tap outside a text field closes the keyboard, and so does every change of screen: the keyboard never stays
        // up on a page that has no field.
        builder: (context, child) => GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child,
        ),
        routingCallback: (r) {
          FocusManager.instance.primaryFocus?.unfocus();
          final name = r?.current;
          if (name != null && Get.isRegistered<CrashService>()) {
            Get.find<CrashService>()
              ..breadcrumb('route $name', category: 'navigation')
              ..tag('screen', name);
          }
        },
        defaultTransition: Transition.cupertino,
        transitionDuration: const Duration(milliseconds: 320),
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        unknownRoute: AppPages.pages.firstWhere((p) => p.name == AppRoutes.notFound),
      );
}
