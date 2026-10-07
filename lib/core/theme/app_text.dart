import 'package:flutter/material.dart';

/// Type scale (spec §4). Inter, bundled. Colors come from AppColors at use site.
abstract final class AppText {
  static const _f = 'Inter';
  static const tabular = [FontFeature.tabularFigures()];

  static const display   = TextStyle(fontFamily: _f, fontSize: 40, height: 44 / 40, fontWeight: FontWeight.w700, letterSpacing: -0.8, fontFeatures: tabular);
  static const heroTitle = TextStyle(fontFamily: _f, fontSize: 30, height: 34 / 30, fontWeight: FontWeight.w700, letterSpacing: -0.5);
  static const title     = TextStyle(fontFamily: _f, fontSize: 22, height: 28 / 22, fontWeight: FontWeight.w700, letterSpacing: -0.3);
  static const navTitle  = TextStyle(fontFamily: _f, fontSize: 17, height: 22 / 17, fontWeight: FontWeight.w600);
  static const bodyLarge = TextStyle(fontFamily: _f, fontSize: 16, height: 24 / 16, fontWeight: FontWeight.w400);
  static const body      = TextStyle(fontFamily: _f, fontSize: 15, height: 22 / 15, fontWeight: FontWeight.w400);
  static const bodySmall = TextStyle(fontFamily: _f, fontSize: 14, height: 21 / 14, fontWeight: FontWeight.w400);
  static const caption   = TextStyle(fontFamily: _f, fontSize: 13, height: 19 / 13, fontWeight: FontWeight.w400);
  static const micro     = TextStyle(fontFamily: _f, fontSize: 12, height: 17 / 12, fontWeight: FontWeight.w400);
  static const overline  = TextStyle(fontFamily: _f, fontSize: 11, height: 14 / 11, fontWeight: FontWeight.w700, letterSpacing: 1.2);
  static const badge     = TextStyle(fontFamily: _f, fontSize: 10, height: 13 / 10, fontWeight: FontWeight.w700, letterSpacing: 0.8);
  static const button    = TextStyle(fontFamily: _f, fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w700);
}
