import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

/// Breathing ring with dot clusters. Decorative (excluded from semantics); static with Reduce Motion.
class PresenceRing extends StatefulWidget {
  const PresenceRing({super.key, this.people = 0, this.size = 260, this.center});
  final int people;
  final double size;
  final Widget? center;
  @override
  State<PresenceRing> createState() => _PresenceRingState();
}

class _PresenceRingState extends State<PresenceRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.breatheIn + Motion.breatheOut);
  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (r != _reduce) {
      _reduce = r;
      r ? _c.stop() : _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(
      child: SizedBox(
        width: widget.size, height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, child) {
            // 4 s in, 6 s out (spec §5)
            final t = _c.value;
            final k = t < .4 ? Curves.easeInOut.transform(t / .4) : 1 - Curves.easeInOut.transform((t - .4) / .6);
            return CustomPaint(painter: _RingPainter(c.ember, c.tealText, c.track, (_reduce ?? false) ? .5 : k, (_reduce ?? false) ? 0 : t, widget.people), child: child);
          },
          child: Center(child: widget.center),
        ),
      ),
    );
  }
}

/// "Breathe in" / "Breathe out" in step with [PresenceRing] (4 s in, 6 s out). Shown for sighted users only: the
/// ring is decoration, and a screen reader announcing it every few seconds would disturb the meditation.
class BreathCue extends StatefulWidget {
  const BreathCue({super.key});
  @override
  State<BreathCue> createState() => _BreathCueState();
}

class _BreathCueState extends State<BreathCue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.breatheIn + Motion.breatheOut);
  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (r != _reduce) {
      _reduce = r;
      r ? _c.stop() : _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (_reduce ?? false) return const SizedBox(height: 18);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final inhale = _c.value < .4;
          // fade the words out around the turn of the breath
          final edge = inhale ? (_c.value / .4) : ((_c.value - .4) / .6);
          final alpha = (math.sin(edge * math.pi)).clamp(0.0, 1.0);
          return SizedBox(height: 18, child: Text(inhale ? 'Breathe in' : 'Breathe out', key: const Key('breath-cue'), style: AppText.caption.copyWith(color: c.textSecondary.withValues(alpha: .35 + .65 * alpha), letterSpacing: .6)));
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ember, this.dot, this.track, this.k, this.t, this.people);
  final Color ember, dot, track;
  /// Breath 0..1 (in → out) and the raw cycle position 0..1 (for the ripples that travel outwards).
  final double k, t;
  final int people;

  static const _teal = Color(0xFF9FE3D6), _tealDeep = Color(0xFF123C3A);

  @override
  void paint(Canvas canvas, Size s) {
    final ctr = s.center(Offset.zero), r = s.width / 2;
    final ringR = r * (.66 + .07 * k);

    // 1. the breathing aura behind everything (spec §3.2 `presenceRing`: teal light fading to nothing)
    final aura = Rect.fromCircle(center: ctr, radius: r * (.86 + .12 * k));
    canvas.drawCircle(ctr, aura.width / 2, Paint()
      ..shader = RadialGradient(colors: [_teal.withValues(alpha: .16 + .14 * k), _tealDeep.withValues(alpha: .34 + .18 * k), _tealDeep.withValues(alpha: 0)], stops: const [.0, .62, 1]).createShader(aura));

    // 2. two ripples that leave the ring and fade, like a breath going out into the room
    for (final phase in const [0.0, .5]) {
      final p = (t + phase) % 1.0;
      canvas.drawCircle(ctr, ringR + (r * .98 - ringR) * p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = ember.withValues(alpha: .34 * (1 - p)));
    }

    // 3. a fine dial of ticks on the outer track (decoration, not people)
    final tick = Paint()..strokeWidth = 1..strokeCap = StrokeCap.round;
    for (var i = 0; i < 72; i++) {
      final a = i * math.pi * 2 / 72, long = i % 6 == 0;
      final dir = Offset(math.cos(a), math.sin(a));
      tick.color = track.withValues(alpha: long ? .9 : .5);
      canvas.drawLine(ctr + dir * r * (long ? .955 : .965), ctr + dir * r * .985, tick);
    }

    // 4. the warm core: lit from the top, deeper at the edge
    final core = Rect.fromCircle(center: ctr, radius: ringR - 5);
    canvas.drawCircle(ctr, core.width / 2, Paint()
      ..shader = RadialGradient(center: const Alignment(-.25, -.35), radius: 1.05, colors: [Color.lerp(const Color(0xFF6B3A24), ember, .18 + .14 * k)!, const Color(0xFF3A1D12), const Color(0xFF1B0F0A)], stops: const [0, .58, 1]).createShader(core));

    // 5. the ember ring itself: a soft glow under a bright arc that slowly turns
    canvas.drawCircle(ctr, ringR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..color = ember.withValues(alpha: .20 + .22 * k)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));
    final ringRect = Rect.fromCircle(center: ctr, radius: ringR);
    canvas.drawCircle(ctr, ringR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..shader = SweepGradient(transform: GradientRotation(t * math.pi * 2), colors: [ember, const Color(0xFFFFB99A), ember, ember.withValues(alpha: .55), ember], stops: const [0, .18, .4, .72, 1]).createShader(ringRect));

    // 6. one dot per person the server reports (small on purpose, capped at 48), drifting gently with the breath
    final n = people.clamp(0, 48);
    final rnd = math.Random(7);
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2 + t * .35, rr = r * (.80 + rnd.nextDouble() * .12) + 3 * k;
      final at = ctr + Offset(math.cos(a), math.sin(a)) * rr;
      final alpha = .55 + .4 * rnd.nextDouble();
      canvas.drawCircle(at, 5, Paint()..color = dot.withValues(alpha: alpha * .22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawCircle(at, 2.6, Paint()..color = dot.withValues(alpha: alpha));
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.k != k || o.t != t || o.people != people;
}

/// A cover drawn by the app for content that has no picture (or whose picture did not load): a calm gradient from the
/// brand palette, picked by [seed] so the same session always gets the same one, with soft rings. Never an empty box.
class GeneratedCover extends StatelessWidget {
  const GeneratedCover({super.key, this.seed = ''});
  final String seed;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CustomPaint(painter: _CoverPainter(seed), child: const SizedBox.expand()));
}

class _CoverPainter extends CustomPainter {
  _CoverPainter(this.seed);
  final String seed;

  // (top, bottom, accent): dusk ember, deep teal, night blue, lilac, forest, dawn
  static const _palettes = [
    (Color(0xFF5A2C1B), Color(0xFF14100E), Color(0xFFFF9B70)),
    (Color(0xFF16504C), Color(0xFF0B1716), Color(0xFF9FE3D6)),
    (Color(0xFF233A5A), Color(0xFF0B1018), Color(0xFFA9C4E8)),
    (Color(0xFF43305A), Color(0xFF120E18), Color(0xFFCDB6E6)),
    (Color(0xFF2C4A30), Color(0xFF0C140D), Color(0xFFB7E3A8)),
    (Color(0xFF6A4A22), Color(0xFF16110A), Color(0xFFF2D08A)),
  ];

  @override
  void paint(Canvas canvas, Size s) {
    var h = 0;
    for (final u in seed.codeUnits) {
      h = (h * 31 + u) & 0x7fffffff;
    }
    final (top, bottom, accent) = _palettes[h % _palettes.length];
    final rect = Offset.zero & s;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [top, bottom]).createShader(rect));
    // a low sun / moon and its rings, placed by the seed so covers differ
    final cx = s.width * (.28 + (h % 5) * .11), cy = s.height * (.34 + ((h ~/ 7) % 4) * .07);
    final base = math.min(s.width, s.height);
    final c = Offset(cx, cy);
    canvas.drawCircle(c, base * .55, Paint()..shader = RadialGradient(colors: [accent.withValues(alpha: .30), accent.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: base * .55)));
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(c, base * (.12 + i * .13), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, base * .008)
        ..color = accent.withValues(alpha: .26 - i * .045));
    }
    canvas.drawCircle(c, base * .10, Paint()..color = accent.withValues(alpha: .85));
    // soft hills at the bottom
    final hills = Path()
      ..moveTo(0, s.height)
      ..lineTo(0, s.height * .78)
      ..quadraticBezierTo(s.width * .28, s.height * (.62 + (h % 3) * .04), s.width * .55, s.height * .80)
      ..quadraticBezierTo(s.width * .80, s.height * .94, s.width, s.height * .72)
      ..lineTo(s.width, s.height)
      ..close();
    canvas.drawPath(hills, Paint()..color = bottom.withValues(alpha: .72));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CoverPainter o) => o.seed != seed;
}

/// Dotted world map from country aggregates (no GPS). [hot] maps ISO-2 → people.
class WorldDotMap extends StatelessWidget {
  const WorldDotMap({super.key, this.hot = const {}, this.height = 180});
  final Map<String, int> hot;
  final double height;

  /// Approximate centroid (lon, lat) of countries that commonly appear; unknown codes are skipped.
  static const centroids = <String, (double, double)>{
    'US': (-98, 39), 'CA': (-106, 56), 'MX': (-102, 23), 'BR': (-52, -10), 'AR': (-64, -34), 'CL': (-71, -33), 'CO': (-74, 4), 'PE': (-75, -10),
    'GB': (-2, 54), 'IE': (-8, 53), 'FR': (2, 46), 'DE': (10, 51), 'ES': (-4, 40), 'PT': (-8, 39), 'IT': (12, 42), 'NL': (5, 52), 'BE': (4, 50),
    'CH': (8, 47), 'AT': (14, 47), 'SE': (16, 62), 'NO': (9, 61), 'DK': (10, 56), 'FI': (26, 64), 'PL': (19, 52), 'CZ': (15, 49), 'GR': (22, 39),
    'RU': (95, 61), 'UA': (31, 49), 'TR': (35, 39), 'IL': (35, 31), 'AE': (54, 24), 'SA': (45, 24), 'EG': (30, 27), 'ZA': (24, -29), 'NG': (8, 9),
    'KE': (38, 0), 'IN': (79, 22), 'PK': (70, 30), 'BD': (90, 24), 'CN': (104, 35), 'JP': (138, 37), 'KR': (127, 36), 'TH': (101, 15), 'VN': (108, 14),
    'ID': (118, -2), 'MY': (102, 4), 'SG': (104, 1), 'PH': (122, 13), 'AU': (134, -25), 'NZ': (172, -41),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ExcludeSemantics(child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _MapPainter(c.track, c.ember, hot))));
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.base, this.hotColor, this.hot);
  final Color base, hotColor;
  final Map<String, int> hot;

  /// Coarse land mask on a 36×18 grid (10° cells), row 0 = 80°N. '#' = land.
  static const _land = [
    '..........##.......####............',
    '....####..###...#############.....',
    '...######.####.###################.',
    '...#####.#####.#################...',
    '....####.####..##############.....',
    '.....###..###...##########..#.....',
    '......##...##....########...##....',
    '......###..####..######.....###...',
    '.......###..####..####.......##...',
    '.......###..####...##.............',
    '.......##....###...##.............',
    '........#.....##........###.......',
    '........#.............#####.......',
    '..........................#.......',
    '.................................',
    '.................................',
  ];

  @override
  void paint(Canvas canvas, Size s) {
    final cols = 36, rows = _land.length;
    final cw = s.width / cols, ch = s.height / rows;
    final p = Paint()..color = base;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols && c < _land[r].length; c++) {
        if (_land[r][c] == '#') canvas.drawCircle(Offset(c * cw + cw / 2, r * ch + ch / 2), math.min(cw, ch) * .28, p);
      }
    }
    final max = hot.values.isEmpty ? 1 : hot.values.reduce(math.max);
    hot.forEach((code, n) {
      final pos = WorldDotMap.centroids[code];
      if (pos == null) return;
      final o = Offset((pos.$1 + 180) / 360 * s.width, (80 - pos.$2) / 160 * s.height);
      final rr = 3 + 5 * (n / max);
      canvas.drawCircle(o, rr * 2, Paint()..color = hotColor.withValues(alpha: .18));
      canvas.drawCircle(o, rr, Paint()..color = hotColor);
    });
  }

  @override
  bool shouldRepaint(_MapPainter o) => o.hot != hot || o.base != base;
}

/// Gradient bar + marker (0–100) + info button (World Vibration).
class VibrationBar extends StatelessWidget {
  const VibrationBar({super.key, required this.value, this.onInfo});
  final int value;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = value.clamp(0, 100) / 100;
    return Semantics(
      label: 'World vibration $value out of 100',
      child: Row(children: [
        Expanded(
          child: LayoutBuilder(
            builder: (_, box) => SizedBox(
              height: 28,
              child: Stack(alignment: Alignment.centerLeft, children: [
                Container(height: 8, decoration: BoxDecoration(borderRadius: BorderRadius.circular(Radii.pill), gradient: LinearGradient(colors: [c.track, c.emberSoft, c.success]))),
                Positioned(left: (box.maxWidth - 16) * v, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 3)))),
              ]),
            ),
          ),
        ),
        if (onInfo != null) IconButton(tooltip: 'About World Vibration', onPressed: onInfo, icon: Icon(Icons.info_outline_rounded, color: c.textSecondary)),
      ]),
    );
  }
}

/// Overline label used above titles ("MEDITATION OF THE DAY").
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: color ?? context.colors.emberText));
}

/// The WeHum ring logo (spec §3.3, same numbers as assets/brand/logo.svg): an ember arc with the gap top-right,
/// a green disc and a dark centre dot. Brand colours are fixed in both themes. Decorative: no semantics.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30});
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(child: CustomPaint(size: Size.square(size), painter: const _BrandLogoPainter()));
}

class _BrandLogoPainter extends CustomPainter {
  const _BrandLogoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 30);
    const centre = Offset(15, 15);
    final arc = Paint()
      ..color = const Color(0xFFFF7A45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: centre, radius: 11), 0, 52 / 11, false, arc); // dasharray 52 18
    canvas.drawCircle(centre, 6, Paint()..color = const Color(0xFF4ADE80));
    canvas.drawCircle(centre, 2.4, Paint()..color = const Color(0xFF0B0D0E));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
