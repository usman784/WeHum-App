import 'package:flutter/material.dart';
import '../data/models/stitch.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';
import 'motion.dart';
import 'surfaces.dart';

/// Pieces shared by the Stitch screens: streak strip, belt counts, stat tiles, section labels.

String groupedInt(int v) {
  final s = v.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return v < 0 ? '-$b' : '$b';
}

/// "OVERLINE" caption above a block.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Expanded(child: Text(text.toUpperCase(), style: AppText.overline.copyWith(color: c.textSecondary))),
      if (trailing != null) trailing!,
    ]);
  }
}

/// A big number with a small caption: "1,420" / "sitting now".
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.accent = false, this.sub});
  final String value, label;
  final String? sub;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$value $label',
      child: ExcludeSemantics(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: AppText.title.copyWith(color: accent ? c.emberText : c.textPrimary, fontFeatures: AppText.tabular)),
          Text(label, style: AppText.micro.copyWith(color: c.textSecondary)),
          if (sub != null) Text(sub!, style: AppText.micro.copyWith(color: c.textTertiary)),
        ]),
      ),
    );
  }
}

/// Americas · EMEA · APAC with the people sitting now in each belt.
class BeltCounts extends StatelessWidget {
  const BeltCounts({super.key, required this.belts});
  final Belts belts;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget cell(String name, int n) => Expanded(
          child: Column(children: [
            Text(name.toUpperCase(), style: AppText.overline.copyWith(color: c.textSecondary)),
            const SizedBox(height: 4),
            Text(groupedInt(n), style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
          ]),
        );
    return Row(children: [cell('Americas', belts.americas), cell('EMEA', belts.emea), cell('APAC', belts.apac)]);
  }
}

/// Monday–Sunday strip: ✓ done, "rest" (grace day), today ring, empty future days.
class StreakStrip extends StatelessWidget {
  const StreakStrip({super.key, required this.week});
  final List<StreakDay> week;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    String desc(StreakDay d) => switch (d.state) {
          DayState.done => '${d.label} sat',
          DayState.rest => '${d.label} rest',
          DayState.today => '${d.label} today',
          DayState.upcoming => d.label,
          DayState.missed => '${d.label} not sat',
        };
    return Semantics(
      label: week.map(desc).join(', '),
      child: ExcludeSemantics(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final d in week)
            Column(children: [
              Text(d.label.isEmpty ? '' : d.label.substring(0, 1), style: AppText.micro.copyWith(color: d.state == DayState.today ? c.emberText : c.textSecondary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _Dot(d),
            ]),
        ]),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.d);
  final StreakDay d;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const size = 32.0;
    switch (d.state) {
      case DayState.done:
        return Container(width: size, height: size, decoration: BoxDecoration(color: c.emberDeep, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 18, color: c.emberText));
      case DayState.rest:
        return Container(
          width: size, height: size, alignment: Alignment.center,
          decoration: BoxDecoration(color: c.tealSoft.withValues(alpha: .14), shape: BoxShape.circle, border: Border.all(color: c.tealText.withValues(alpha: .5))),
          child: Text('R', style: AppText.badge.copyWith(color: c.tealText)));
      case DayState.today:
        final n = int.tryParse(d.date.length >= 10 ? d.date.substring(8, 10) : '') ?? 0;
        return Container(
          width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle, border: Border.all(color: c.emberText.withValues(alpha: .6), width: 2)),
          child: Text(n == 0 ? '' : '$n', style: AppText.micro.copyWith(color: c.onEmber, fontWeight: FontWeight.w800)));
      case DayState.missed:
      case DayState.upcoming:
        return Container(width: size, height: size, decoration: BoxDecoration(color: c.track, shape: BoxShape.circle));
    }
  }
}

/// Small pill with an icon ("🔥 5-day streak").
class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.text, this.icon, this.accent = true});
  final String text;
  final IconData? icon;
  final bool accent;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = accent ? c.emberText : c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: accent ? c.emberTint : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 5)],
        Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: fg, fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

/// A row on a card: icon tile, title, subtitle, chevron.
class AccelRow extends StatelessWidget {
  const AccelRow({super.key, required this.icon, required this.title, required this.subtitle, required this.onTap, this.locked = false});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  final bool locked;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap, padding: const EdgeInsets.all(12), semanticLabel: '$title, $subtitle',
      child: Row(children: [
        IconTile(icon),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 17)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          ]),
        ),
        Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: c.textSecondary),
      ]),
    );
  }
}

/// "● 1,248 SITTING WORLDWIDE RIGHT NOW" with the round sound/atmosphere button at its right (Today).
class LiveStrip extends StatelessWidget {
  const LiveStrip({super.key, required this.text, this.quiet = false, this.onWave});
  final String text;
  final bool quiet;
  final VoidCallback? onWave;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(children: [
      Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              quiet ? Container(width: 8, height: 8, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)) : PulseDot(color: c.success, size: 4),
              const SizedBox(width: 6),
              Flexible(child: Text(text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))),
            ]),
          ),
        ),
      ),
      const SizedBox(width: 8),
      if (onWave != null)
        GestureDetector(onTap: onWave, child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: Icon(Icons.graphic_eq_rounded, size: 18, color: c.textSecondary))),
    ]);
  }
}

/// "Global presence heatmap": a stylised world with glowing belts, then the three belt counts.
class HeatmapCard extends StatelessWidget {
  const HeatmapCard({super.key, required this.belts, required this.onExplore});
  final Belts belts;
  final VoidCallback onExplore;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = [belts.americas, belts.emea, belts.apac, 1].reduce((a, b) => a > b ? a : b);
    return AppCard(
      key: const Key('presence-card'), onTap: onExplore, semanticLabel: 'Global presence, explore the map', padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          PulseDot(color: c.success, size: 4),
          const SizedBox(width: 4),
          Expanded(child: Text('GLOBAL PRESENCE HEATMAP', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))),
          Text('EXPLORE MAP', style: AppText.overline.copyWith(color: c.emberText, fontSize: 10.5)),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_rounded, size: 14, color: c.emberText),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: c.bgDeep, padding: const EdgeInsets.all(8),
            child: AspectRatio(aspectRatio: 400 / 180, child: CustomPaint(painter: _HeatPainter(c, belts.americas / max, belts.emea / max, belts.apac / max))),
          ),
        ),
        const SizedBox(height: 14),
        BeltCounts(belts: belts),
      ]),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.c, this.a, this.e, this.p);
  final AppColors c;
  final double a, e, p;
  @override
  void paint(Canvas canvas, Size s) {
    canvas.scale(s.width / 400, s.height / 180);
    final grid = Paint()..style = PaintingStyle.stroke..strokeWidth = .6..color = c.border;
    for (final y in [45.0, 90.0, 135.0]) {
      canvas.drawLine(Offset(0, y), Offset(400, y), grid);
    }
    for (final x in [100.0, 200.0, 300.0]) {
      canvas.drawLine(Offset(x, 0), Offset(x, 180), grid);
    }
    Path blob(List<double> pts) {
      final path = Path()..moveTo(pts[0], pts[1]);
      for (var i = 2; i + 1 < pts.length; i += 2) {
        path.lineTo(pts[i], pts[i + 1]);
      }
      return path..close();
    }
    final fill = Paint()..color = c.surfaceAlt.withValues(alpha: .9);
    final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = c.border;
    for (final b in [
      blob([65, 30, 95, 34, 110, 55, 100, 78, 90, 95, 105, 110, 120, 125, 112, 145, 105, 160, 95, 135, 80, 115, 70, 92, 60, 70]),
      blob([180, 35, 225, 25, 285, 30, 325, 65, 300, 82, 285, 95, 250, 90, 235, 90, 225, 112, 215, 135, 200, 118, 185, 100, 170, 75]),
      blob([305, 75, 340, 70, 365, 90, 365, 110, 345, 135, 320, 145, 305, 135, 295, 125]),
    ]) {
      canvas.drawPath(b, fill);
      canvas.drawPath(b, edge);
    }
    void glow(double cx, double cy, double r, Color col, double k) {
      if (k <= 0) return;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawCircle(Offset(cx, cy), r, Paint()..shader = RadialGradient(colors: [col.withValues(alpha: .25 + .5 * k), col.withValues(alpha: 0)]).createShader(rect));
    }
    glow(110, 82, 38, c.success, a);
    glow(210, 62, 32, const Color(0xFFFFB59A), e);
    glow(300, 80, 42, c.success, p);
    final dot = Paint();
    for (final d in [(95.0, 70.0, c.success, a), (125.0, 92.0, c.success, a), (205.0, 56.0, const Color(0xFFFFB59A), e), (222.0, 70.0, c.success, e), (292.0, 76.0, c.success, p), (315.0, 88.0, const Color(0xFFFFB59A), p)]) {
      if (d.$4 > 0) canvas.drawCircle(Offset(d.$1, d.$2), 2.2, dot..color = d.$3);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter old) => old.a != a || old.e != e || old.p != p;
}
