import 'package:flutter/material.dart';

/// WeHum color tokens (spec §3). Dark = designed default; light = derived (verify contrast ≥ 4.5:1).
/// Usage: `context.colors.ember`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg, required this.bgDeep, required this.surface, required this.surfaceAlt, required this.surfaceInput,
    required this.border, required this.borderStrong, required this.borderOutline, required this.track,
    required this.textPrimary, required this.textBody, required this.textSoft, required this.textSecondary, required this.textTertiary,
    required this.ember, required this.emberText, required this.emberSoft, required this.onEmber, required this.emberTint, required this.emberDeep,
    required this.teal, required this.tealText, required this.tealSoft,
    required this.success, required this.onSuccess, required this.infoBg, required this.infoText, required this.lilacBg, required this.lilacText,
    required this.danger, required this.dangerText, required this.dangerTint, required this.dangerBorder, required this.overlayScrim,
  });

  final Color bg, bgDeep, surface, surfaceAlt, surfaceInput, border, borderStrong, borderOutline, track;
  final Color textPrimary, textBody, textSoft, textSecondary, textTertiary;
  final Color ember, emberText, emberSoft, onEmber, emberTint, emberDeep;
  final Color teal, tealText, tealSoft, success, onSuccess, infoBg, infoText, lilacBg, lilacText;
  final Color danger, dangerText, dangerTint, dangerBorder, overlayScrim;

  static const dark = AppColors(
    bg: Color(0xFF0B0D0E), bgDeep: Color(0xFF050607), surface: Color(0xFF17191B), surfaceAlt: Color(0xFF1E2124), surfaceInput: Color(0xFF0F1112),
    border: Color(0xFF23262A), borderStrong: Color(0xFF2A2D30), borderOutline: Color(0xFF3A3E42), track: Color(0xFF2A2D30),
    textPrimary: Color(0xFFF2F2F2), textBody: Color(0xFFD9DBDD), textSoft: Color(0xFFC9CCCF), textSecondary: Color(0xFFA0A4A8), textTertiary: Color(0xFF6E7378),
    ember: Color(0xFFFF7A45), emberText: Color(0xFFFF9B70), emberSoft: Color(0xFFFFB99A), onEmber: Color(0xFF2A0E02),
    emberTint: Color(0x24FF7A45) /* 14 % */, emberDeep: Color(0xFF3A1D12),
    teal: Color(0xFF123C3A), tealText: Color(0xFF9FE3D6), tealSoft: Color(0xFFCFEDE6),
    success: Color(0xFF4ADE80), onSuccess: Color(0xFF062B14), infoBg: Color(0xFF1E2A3A), infoText: Color(0xFFA9C4E8),
    lilacBg: Color(0xFF2A1F33), lilacText: Color(0xFFCDB6E6),
    danger: Color(0xFFD9483B), dangerText: Color(0xFFFF8A75), dangerTint: Color(0x1ADC4632) /* 10 % */, dangerBorder: Color(0xFF7A2E22),
    overlayScrim: Color(0x990B0D0E) /* 60 % */,
  );

  static const light = AppColors(
    bg: Color(0xFFF7F5F2), bgDeep: Color(0xFFECE8E3), surface: Color(0xFFFFFFFF), surfaceAlt: Color(0xFFF1EEEA), surfaceInput: Color(0xFFF4F1ED),
    border: Color(0xFFE4E0DA), borderStrong: Color(0xFFD6D1CA), borderOutline: Color(0xFFBDB6AE), track: Color(0xFFE2DDD6),
    textPrimary: Color(0xFF141618), textBody: Color(0xFF2B2F33), textSoft: Color(0xFF3E4348), textSecondary: Color(0xFF5C6166), textTertiary: Color(0xFF8A8F94),
    ember: Color(0xFFE8622C), emberText: Color(0xFFC2471A), emberSoft: Color(0xFFD9693A), onEmber: Color(0xFFFFFFFF),
    emberTint: Color(0x1AE8622C), emberDeep: Color(0xFFFBE3D8),
    teal: Color(0xFFDDF3EF), tealText: Color(0xFF0F5E55), tealSoft: Color(0xFF2F7A70),
    success: Color(0xFF16A34A), onSuccess: Color(0xFFFFFFFF), infoBg: Color(0xFFE3ECF7), infoText: Color(0xFF2C5282),
    lilacBg: Color(0xFFEEE6F5), lilacText: Color(0xFF5B3E7A),
    danger: Color(0xFFC53030), dangerText: Color(0xFFC53030), dangerTint: Color(0xFFFDECEA), dangerBorder: Color(0xFFF5B5AE),
    overlayScrim: Color(0x73141618) /* 45 % */,
  );

  /// World Vibration bar (90°).
  static const worldVibration = LinearGradient(
    colors: [Color(0xFF3A2A22), Color(0xFFFF7A45), Color(0xFFE5D96B), Color(0xFF4ADE80)],
    stops: [0, .35, .62, 1],
  );

  /// Next group meditation card (160°).
  static const groupCard = LinearGradient(
    begin: Alignment(-0.34, -0.94), end: Alignment(0.34, 0.94),
    colors: [Color(0xFF2A1810), Color(0xFF17191B)], stops: [0, .7],
  );

  /// Hero image legibility (always dark on photos).
  static const imageGradient = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0x000B0D0E), Color(0xF00B0D0E)], stops: [.25, 1],
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < .5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
