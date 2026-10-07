import 'package:flutter/services.dart';

bool _loaded = false;

/// `flutter test` draws text in a placeholder font with full-width glyphs, which fakes overflows.
/// Loading the bundled Inter gives the real metrics (the same font the app ships).
Future<void> loadAppFonts() async {
  if (_loaded) return;
  _loaded = true;
  final loader = FontLoader('Inter');
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Inter-$f.ttf'));
  }
  await loader.load();
}
