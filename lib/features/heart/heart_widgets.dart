import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/health/hr_summary.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/surfaces.dart';

/// "♥ 72 bpm" on the player: the heart beats at the real rate. One small controller, retimed only when the rate moves by
/// 4 bpm or more; nothing animates when the system asks for reduced motion. Rebuilds on its own, not with the player.
class HeartPill extends StatelessWidget {
  const HeartPill({super.key, required this.live});
  final Rxn<int> live;

  @override
  Widget build(BuildContext context) => Obx(() {
        final v = live.value;
        if (v == null) return const SizedBox(height: 4);
        return Center(child: _Beat(bpm: v));
      });
}

class _Beat extends StatefulWidget {
  const _Beat({required this.bpm});
  final int bpm;
  @override
  State<_Beat> createState() => _BeatState();
}

class _BeatState extends State<_Beat> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this);
  int _rate = 0;

  Duration _period(int bpm) => Duration(milliseconds: (60000 / bpm.clamp(40, 180)).round());

  void _retime(bool reduce) {
    if (reduce) {
      _ctl.stop();
      _rate = 0;
      return;
    }
    if ((widget.bpm - _rate).abs() < 4 && _ctl.isAnimating) return;
    _rate = widget.bpm;
    _ctl.duration = _period(_rate);
    _ctl.repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _retime(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void didUpdateWidget(_Beat old) {
    super.didUpdateWidget(old);
    _retime(MediaQuery.disableAnimationsOf(context));
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  // a quick double-bump per beat, then rest: lub-dub
  static double _scale(double t) => 1 + .16 * math.max(math.exp(-math.pow((t - .12) / .07, 2)), .7 * math.exp(-math.pow((t - .3) / .07, 2)));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Heart rate ${widget.bpm} beats per minute', excludeSemantics: true,
      child: Container(
        key: const Key('heart-pill'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(child: AnimatedBuilder(animation: _ctl, builder: (_, child) => Transform.scale(scale: _scale(_ctl.value), child: child), child: Icon(Icons.favorite_rounded, size: 16, color: c.ember))),
          const SizedBox(width: 8),
          Text('${widget.bpm}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15, fontFeatures: AppText.tabular)),
          const SizedBox(width: 4),
          Text('bpm', style: AppText.caption.copyWith(color: c.textSecondary)),
        ]),
      ),
    );
  }
}

/// The sit as a smooth line with a soft fill. Painted once into its own layer.
class HeartSparkline extends StatelessWidget {
  const HeartSparkline(this.values, {super.key, this.height = 64});
  final List<double> values;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return RepaintBoundary(
      child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _SparkPainter(values, c.ember, c.track))),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color, this.grid);
  final List<double> v;
  final Color color, grid;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.length < 2) return;
    final lo = v.reduce(math.min), hi = v.reduce(math.max);
    final pad = math.max(4.0, (hi - lo) * .2), min = lo - pad, span = (hi + pad) - min;
    const inset = 3.0;
    final w = size.width - inset * 2, h = size.height - inset * 2;
    Offset p(int i) => Offset(inset + w * i / (v.length - 1), inset + h * (1 - (v[i] - min) / span));
    // a baseline at the starting level makes "lower than where I began" readable at a glance
    final y0 = p(0).dy;
    canvas.drawLine(Offset(inset, y0), Offset(size.width - inset, y0), Paint()..color = grid..strokeWidth = 1);
    final path = Path()..moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < v.length; i++) {
      final a = p(i - 1), b = p(i), mid = (a.dx + b.dx) / 2;
      path.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }
    final fill = Path.from(path)..lineTo(p(v.length - 1).dx, size.height)..lineTo(p(0).dx, size.height)..close();
    canvas.drawPath(fill, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    canvas.drawCircle(p(v.length - 1), 3.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter o) => !identical(o.v, v) || o.color != color || o.grid != grid;
}

/// The payoff card: the calm shift in big type, the sit as a line, then average, low and HRV.
class HeartSummaryCard extends StatelessWidget {
  const HeartSummaryCard(this.hr, {super.key});
  final HrSummary hr;

  String get _line {
    final d = hr.deltaBpm;
    if (d == null) return hr.sampleCount <= 2 ? 'Your wearable shared ${hr.sampleCount == 1 ? 'one reading' : 'two readings'} for this meditation.' : 'Not enough readings to compare the start and the end.';
    if (d <= -2) return 'Your heart slowed down by the end of the meditation.';
    if (d >= 2) return 'Your heart rate was a little higher at the end.';
    return 'Your heart rate stayed steady through the meditation.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = hr.deltaBpm;
    final calmer = d != null && d <= -2;
    final big = d == null ? '${hr.avgBpm}' : '${d > 0 ? '+' : (d < 0 ? '−' : '')}${d.abs()}';
    return AppCard(
      key: const Key('complete-hr'),
      padding: const EdgeInsets.all(16),
      child: Semantics(
        container: true, label: 'Heart rate. ${d == null ? 'Average ${hr.avgBpm} beats per minute' : 'Shift $d beats per minute'}. $_line',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: c.emberDeep, shape: BoxShape.circle), child: Icon(Icons.favorite_rounded, size: 15, color: c.emberText)),
            const SizedBox(width: 10),
            Expanded(child: Text('HEART RATE', style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5))),
            if ((hr.sourceName ?? '').isNotEmpty)
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
                child: Text(hr.sourceName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.micro.copyWith(color: c.textSecondary)),
              )),
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(big, key: const Key('hr-big'), style: AppText.display.copyWith(color: calmer ? c.success : c.textPrimary)),
            const SizedBox(width: 6),
            Text('bpm', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(width: 8),
            Flexible(child: Text(d == null ? 'average' : 'by the end', style: AppText.caption.copyWith(color: c.textSecondary))),
          ]),
          const SizedBox(height: 4),
          Text(_line, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          if (hr.trend.length >= 3) ...[const SizedBox(height: 12), HeartSparkline(hr.trend)],
          const SizedBox(height: 12),
          Row(children: [
            if (d != null) ...[Expanded(child: _Mini('AVERAGE', '${hr.avgBpm}', 'bpm')), const SizedBox(width: 8)],
            Expanded(child: _Mini('LOWEST', '${hr.minBpm}', 'bpm')),
            if (hr.hrvMs != null) ...[const SizedBox(width: 8), Expanded(child: _Mini('HRV', hr.hrvMs!.round().toString(), 'ms'))],
          ]),
        ]),
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.unit);
  final String label, value, unit;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(Radii.input)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppText.overline.copyWith(color: c.textTertiary, fontSize: 9.5)),
        const SizedBox(height: 3),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(value, style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
          const SizedBox(width: 3),
          Text(unit, style: AppText.micro.copyWith(color: c.textSecondary)),
        ]),
      ]),
    );
  }
}
