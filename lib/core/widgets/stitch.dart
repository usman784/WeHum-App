import 'package:flutter/material.dart';
import '../data/models/stitch.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';
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
        return Container(width: size, height: size, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle), child: Icon(Icons.check_rounded, size: 18, color: c.onEmber));
      case DayState.rest:
        return Container(
          width: size, height: size, alignment: Alignment.center,
          decoration: BoxDecoration(color: c.tealSoft.withValues(alpha: .14), shape: BoxShape.circle, border: Border.all(color: c.tealText.withValues(alpha: .5))),
          child: Text('R', style: AppText.badge.copyWith(color: c.tealText)));
      case DayState.today:
        final n = int.tryParse(d.date.length >= 10 ? d.date.substring(8, 10) : '') ?? 0;
        return Container(
          width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.ember, width: 2)),
          child: Text(n == 0 ? '' : '$n', style: AppText.micro.copyWith(color: c.emberText, fontWeight: FontWeight.w700)));
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
            Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary)),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          ]),
        ),
        Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: c.textSecondary),
      ]),
    );
  }
}
