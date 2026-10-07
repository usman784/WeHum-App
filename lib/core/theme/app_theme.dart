import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text.dart';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.dark ? AppColors.dark : AppColors.light;
  return ThemeData(
    brightness: b,
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: b,
      primary: c.ember, onPrimary: c.onEmber,
      secondary: c.tealText, onSecondary: c.bg,
      surface: c.surface, onSurface: c.textPrimary,
      error: c.danger, onError: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: AppText.display, headlineMedium: AppText.heroTitle, titleLarge: AppText.title,
      titleMedium: AppText.navTitle, bodyLarge: AppText.bodyLarge, bodyMedium: AppText.body,
      bodySmall: AppText.caption, labelSmall: AppText.overline,
    ).apply(bodyColor: c.textPrimary, displayColor: c.textPrimary),
    dividerColor: c.border,
    splashFactory: NoSplash.splashFactory,
    extensions: [c],
  );
}
