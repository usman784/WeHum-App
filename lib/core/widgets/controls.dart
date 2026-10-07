import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

/// 2–4 options (lengths 10/30/45, Simple/Rich, 9:16/1:1, period tabs).
class SegmentedControl<T> extends StatelessWidget {
  const SegmentedControl({super.key, required this.options, required this.value, required this.onChanged, this.labelOf});
  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.bgDeep.withValues(alpha: .55), borderRadius: BorderRadius.circular(Radii.pill)),
      child: Row(children: [
        for (final o in options)
          Expanded(
            child: Semantics(
              button: true, selected: o == value, label: labelOf?.call(o) ?? '$o',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, onTap: () => onChanged(o),
                child: AnimatedContainer(
                  duration: Motion.state, constraints: const BoxConstraints(minHeight: 44), padding: const EdgeInsets.symmetric(vertical: 8), alignment: Alignment.center,
                  decoration: BoxDecoration(color: o == value ? c.textPrimary : Colors.transparent, borderRadius: BorderRadius.circular(Radii.pill)),
                  child: Text(labelOf?.call(o) ?? '$o', style: AppText.navTitle.copyWith(fontSize: 15, color: o == value ? c.bg : c.textPrimary)),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Switch, 52×32 (spec §5).
class AppToggle extends StatelessWidget {
  const AppToggle({super.key, required this.value, required this.onChanged, this.label});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      toggled: value, label: label, enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: Sizes.touch + 8, height: Sizes.touch,
          child: Center(
            child: AnimatedContainer(
              duration: Motion.state, width: Sizes.toggleW, height: Sizes.toggleH, padding: const EdgeInsets.all(3),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(color: value ? c.ember : c.track, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Container(width: 26, height: 26, decoration: BoxDecoration(color: value ? c.onEmber : c.textPrimary, shape: BoxShape.circle)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single- or multi-select pill (lengths, filters).
class PillGroup<T> extends StatelessWidget {
  const PillGroup({super.key, required this.options, required this.selected, required this.onToggle, required this.labelOf});
  final List<T> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;
  final String Function(T) labelOf;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final o in options)
        Semantics(
          button: true, selected: selected.contains(o), label: labelOf(o),
          child: GestureDetector(
            onTap: () => onToggle(o),
            child: AnimatedContainer(
              duration: Motion.state, constraints: const BoxConstraints(minHeight: 40), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: selected.contains(o) ? c.emberTint : c.surface, borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: selected.contains(o) ? c.ember : c.border),
              ),
              child: Text(labelOf(o), style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w600, color: selected.contains(o) ? c.emberText : c.textBody)),
            ),
          ),
        ),
    ]);
  }
}
