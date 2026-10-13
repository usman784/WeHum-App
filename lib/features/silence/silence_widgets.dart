import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/data/models/stitch.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/stitch.dart';

/// "● 214 SITTING IN SILENCE NOW" + "LIVE SYNC": the pulsing pill at the top of the Silence Room.
class LivePresenceRow extends StatelessWidget {
  const LivePresenceRow({super.key, required this.label, required this.quiet, this.right = 'Live sync'});
  final String label, right;
  final bool quiet;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            quiet ? Container(width: 8, height: 8, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)) : PulseDot(color: c.success, size: 4),
            const SizedBox(width: 6),
            Flexible(child: Text(label.toUpperCase(), key: const Key('silence-big'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textPrimary))),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.public_rounded, size: 15, color: quiet ? c.textTertiary : c.success),
        const SizedBox(width: 6),
        Text(right.toUpperCase(), style: AppText.overline.copyWith(color: c.textSecondary)),
      ]),
    ]);
  }
}

/// The "Active global belts" card: three glowing regions on a dotted route with their live counts.
class BeltsCard extends StatelessWidget {
  const BeltsCard({super.key, required this.belts, this.onTap});
  final Belts belts;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final zones = [belts.americas, belts.emea, belts.apac].where((n) => n > 0).length;
    Widget label(String t, int n, Color dot) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text('$t ${groupedInt(n)}'.toUpperCase(), style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
        ]);
    return Container(
      key: const Key('silence-belts'), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.public_rounded, size: 16, color: c.success),
          const SizedBox(width: 8),
          Expanded(child: Text('ACTIVE GLOBAL BELTS', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5, letterSpacing: .6))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              PulseDot(color: c.success, size: 3),
              const SizedBox(width: 4),
              Text('$zones ${zones == 1 ? 'REGION' : 'REGIONS'} LIVE', style: AppText.overline.copyWith(color: c.success, fontSize: 10)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              Container(color: c.bgDeep.withValues(alpha: .8)),
              Opacity(opacity: .5, child: CustomPaint(painter: _BeltPainter(c.success, c.ember, c.border))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final l in [label('Americas', belts.americas, c.success), label('EMEA', belts.emea, c.ember), label('Asia-Pac', belts.apac, c.success)]) Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: l))]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.travel_explore_rounded, size: 14, color: c.success),
              const SizedBox(width: 6),
              Expanded(child: Text('VIEW GLOBAL BELT PRESENCE', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))),
              Icon(Icons.chevron_right_rounded, size: 16, color: c.textSecondary),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _BeltPainter extends CustomPainter {
  _BeltPainter(this.green, this.ember, this.line);
  final Color green, ember, line;
  @override
  void paint(Canvas canvas, Size s) {
    final sx = s.width / 320, sy = s.height / 64;
    canvas.scale(sx, sy);
    final path = Path()..moveTo(20, 38)..quadraticBezierTo(50, 22, 90, 32)..quadraticBezierTo(130, 42, 170, 26)..quadraticBezierTo(210, 12, 250, 36)..quadraticBezierTo(280, 40, 300, 24);
    final dashed = Path();
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 6) {
        dashed.addPath(m.extractPath(d, math.min(d + 2, m.length)), Offset.zero);
      }
    }
    canvas.drawPath(dashed, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = line);
    void glow(double cx, double cy, double rx, double ry, Color col) {
      final r = Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      canvas.drawOval(r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .7), col.withValues(alpha: 0)]).createShader(r));
    }
    glow(78, 30, 28, 18, green);
    glow(168, 27, 34, 20, ember);
    glow(258, 35, 24, 16, green);
    for (final d in [(72.0, 31.0, 2.5, green), (84.0, 28.0, 1.5, const Color(0xFFA5CECB)), (160.0, 25.0, 2.5, ember), (176.0, 30.0, 2.0, const Color(0xFFFFB59A)), (254.0, 34.0, 2.0, green), (265.0, 38.0, 1.5, const Color(0xFFA5CECB))]) {
      canvas.drawCircle(Offset(d.$1, d.$2), d.$3, Paint()..color = d.$4);
    }
  }

  @override
  bool shouldRepaint(covariant _BeltPainter old) => false;
}

/// "Target duration 15 MIN": a breathing ring (track + arc), a few sitter dots around it and the cadence chip.
class BreathRing extends StatefulWidget {
  const BreathRing({super.key, required this.minutes, required this.inhaleSec, required this.exhaleSec});
  final int minutes, inhaleSec, exhaleSec;
  @override
  State<BreathRing> createState() => _BreathRingState();
}

class _BreathRingState extends State<BreathRing> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: Duration(seconds: widget.inhaleSec + widget.exhaleSec))..repeat();

  @override
  void didUpdateWidget(covariant BreathRing old) {
    super.didUpdateWidget(old);
    final d = Duration(seconds: widget.inhaleSec + widget.exhaleSec);
    if (_breath.duration != d) {
      _breath.duration = d;
      _breath.repeat();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final open = widget.minutes == 0;
    final arc = open ? 1.0 : (.25 + .75 * (math.min(widget.minutes, 60) / 60));
    final still = reduceMotion(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: _breath,
              builder: (_, __) {
                // inhale: grows over `inhaleSec`, exhale: shrinks over `exhaleSec`
                final t = _breath.value * (widget.inhaleSec + widget.exhaleSec);
                final k = still ? .5 : (t < widget.inhaleSec ? Curves.easeInOut.transform(t / widget.inhaleSec) : 1 - Curves.easeInOut.transform((t - widget.inhaleSec) / widget.exhaleSec));
                return Container(
                  margin: EdgeInsets.all(20 - 8 * k),
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.ember.withValues(alpha: .0), c.ember.withValues(alpha: .0), c.ember.withValues(alpha: .10 + .08 * k), c.ember.withValues(alpha: 0)], stops: const [0, .62, .9, 1])),
                );
              },
            ),
            const _SitterDots(),
            TweenAnimationBuilder<double>(
              tween: Tween(end: arc), duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic,
              builder: (_, v, __) => CustomPaint(size: Size.infinite, painter: _RingPainter(track: c.surfaceAlt, arc: c.ember, fraction: v)),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('TARGET DURATION', style: AppText.overline.copyWith(color: c.textSecondary, letterSpacing: 1.6)),
              const SizedBox(height: 4),
              Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (w, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: .9, end: 1.0).animate(a), child: w)),
                  child: Text(open ? '∞' : '${widget.minutes}', key: ValueKey(widget.minutes), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 52, fontFeatures: AppText.tabular)),
                ),
                const SizedBox(width: 4),
                Text(open ? 'OPEN' : 'MIN', style: AppText.navTitle.copyWith(color: c.ember)),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.air_rounded, size: 13, color: c.success),
                  const SizedBox(width: 6),
                  Text('CADENCE: ${widget.inhaleSec}S / ${widget.exhaleSec}S', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
                ]),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.track, required this.arc, required this.fraction});
  final Color track, arc;
  final double fraction;
  @override
  void paint(Canvas canvas, Size s) {
    final r = s.width * (102 / 240);
    final c = Offset(s.width / 2, s.height / 2);
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * fraction, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.fraction != fraction || old.arc != arc || old.track != track;
}

class _SitterDots extends StatelessWidget {
  const _SitterDots();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget dot(double? l, double? t, double? r, double? b, double size, Color col, {bool pulse = false}) => Positioned(
          left: l, top: t, right: r, bottom: b, child: pulse ? PulseDot(color: col, size: size / 2) : Container(width: size, height: size, decoration: BoxDecoration(color: col, shape: BoxShape.circle)));
    return LayoutBuilder(builder: (_, k) {
      final w = k.maxWidth, h = k.maxHeight;
      return Stack(children: [
        dot(w * .28, h * .08, null, null, 6, c.track, pulse: true),
        dot(null, h * .12, w * .22, null, 8, c.success.withValues(alpha: .7)),
        dot(w * .18, null, null, h * .16, 6, c.ember.withValues(alpha: .7)),
        dot(null, null, w * .14, h * .22, 8, c.track),
        dot(w * .04, h * .52, null, null, 6, c.border),
        dot(null, h * .48, w * .05, null, 8, c.success.withValues(alpha: .6), pulse: true),
        dot(w * .45, null, null, h * .06, 6, c.track),
      ]);
    });
  }
}

/// 4-column duration grid: a number over "MIN"; the chosen one is ember with a small dot.
class DurationGrid extends StatelessWidget {
  const DurationGrid({super.key, required this.options, required this.selected, required this.onPick});
  final List<int> options;
  final int selected;
  final ValueChanged<int> onPick;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(builder: (_, k) {
      const gap = 8.0;
      final w = (k.maxWidth - gap * 3) / 4;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (final m in options)
          GestureDetector(
            key: Key('dur-$m'), onTap: () => onPick(m),
            child: Pressable(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180), width: w, constraints: const BoxConstraints(minHeight: 56),
                decoration: BoxDecoration(color: m == selected ? c.ember : c.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                  Column(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                    m == 0 ? Icon(Icons.all_inclusive_rounded, size: 20, color: m == selected ? c.onEmber : c.textPrimary) : Text('$m', style: AppText.navTitle.copyWith(fontSize: 15, color: m == selected ? c.onEmber : c.textPrimary, fontFeatures: AppText.tabular)),
                    Text(m == 0 ? 'OPEN' : 'MIN', style: AppText.overline.copyWith(fontSize: 10, color: m == selected ? c.onEmber : c.textSecondary)),
                  ]),
                  if (m == selected) Positioned(top: -3, right: -3, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.emberText, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)))),
                ]),
              ),
            ),
          ),
      ]);
    });
  }
}

/// One acoustic row: icon tile, title + subtitle, optional bell chip, toggle.
class AcousticRow extends StatelessWidget {
  const AcousticRow({super.key, required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.value, required this.onChanged, this.chip, this.onChip, this.toggleKey});
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? chip;
  final VoidCallback? onChip;
  final Key? toggleKey;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 18, color: iconColor)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(fontSize: 14, color: c.textPrimary)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary)),
        ])),
        if (chip != null) GestureDetector(
          onTap: onChip,
          child: Container(margin: const EdgeInsets.only(right: 6), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(6)), child: Text(chip!.toUpperCase(), style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10))),
        ),
        AppToggle(key: toggleKey, value: value, onChanged: onChanged, label: title),
      ]),
    );
  }
}
