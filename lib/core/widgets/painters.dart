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
            return CustomPaint(painter: _RingPainter(c.ember, c.tealText, c.track, (_reduce ?? false) ? .5 : k, widget.people), child: child);
          },
          child: Center(child: widget.center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ember, this.dot, this.track, this.k, this.people);
  final Color ember, dot, track;
  final double k;
  final int people;
  @override
  void paint(Canvas canvas, Size s) {
    final ctr = s.center(Offset.zero), r = s.width / 2;
    canvas.drawCircle(ctr, r * (.62 + .1 * k), Paint()..color = ember.withValues(alpha: .10 + .08 * k));
    canvas.drawCircle(ctr, r * (.70 + .08 * k), Paint()..style = PaintingStyle.stroke..strokeWidth = 3 ..color = ember.withValues(alpha: .85));
    canvas.drawCircle(ctr, r * .94, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = track);
    // dot clusters: count is small on purpose (spec: numbers small), capped at 48
    final n = people.clamp(0, 48);
    final rnd = math.Random(7);
    for (var i = 0; i < n; i++) {
      final a = rnd.nextDouble() * math.pi * 2, rr = r * (.82 + rnd.nextDouble() * .14);
      canvas.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * rr, 2.4, Paint()..color = dot.withValues(alpha: .55 + .4 * rnd.nextDouble()));
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.k != k || o.people != people;
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
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: AppText.overline.copyWith(color: color ?? context.colors.emberText));
}
