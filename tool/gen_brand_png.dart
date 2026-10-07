// Renders the brand PNGs from the logo definition in spec §3.3 (same numbers as assets/brand/logo.svg):
//   flutter test tool/gen_brand_png.dart
// then: dart run flutter_launcher_icons && dart run flutter_native_splash:create
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// The ring logo on a 30×30 viewBox, scaled to [logo] px and centred in a [size] px square.
Future<void> render(String path, {required int size, required double logo, Color? background}) async {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  if (background != null) c.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), Paint()..color = background);
  final k = logo / 30, o = (size - logo) / 2;
  c.translate(o, o);
  c.scale(k);
  // circle r=11, stroke 3.5, dasharray 52 18 (circumference 69.1): one arc of 52 units starting at 3 o'clock
  const r = 11.0;
  final arc = Paint()
    ..color = const Color(0xFFFF7A45)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round;
  c.drawArc(Rect.fromCircle(center: const Offset(15, 15), radius: r), 0, 52 / r, false, arc);
  c.drawCircle(const Offset(15, 15), 6, Paint()..color = const Color(0xFF4ADE80));
  c.drawCircle(const Offset(15, 15), 2.4, Paint()..color = const Color(0xFF0B0D0E));
  final img = await rec.endRecording().toImage(size, size);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('brand PNGs', () async {
    assert(52 / 11 < 2 * math.pi);
    const dark = Color(0xFF0B0D0E);
    await render('assets/brand/icon_1024.png', size: 1024, logo: 620, background: dark); // iOS + legacy Android (no alpha)
    await render('assets/brand/icon_foreground.png', size: 1024, logo: 430); // Android adaptive: inside the 66 % safe zone
    await render('assets/brand/logo_512.png', size: 512, logo: 512); // native splash
  });
}
