import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

class _BtnBase extends StatelessWidget {
  const _BtnBase({
    required this.label, required this.onPressed, required this.bg, required this.fg, this.border, this.height = Sizes.primaryButton,
    this.loading = false, this.icon, this.sub, this.fullWidth = true,
  });
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final Color bg, fg;
  final BorderSide? border;
  final double height;
  final bool loading, fullWidth;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = loading
        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
            Flexible(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(label, textAlign: TextAlign.center, style: AppText.button.copyWith(color: fg)),
                if (sub != null) Text(sub!, textAlign: TextAlign.center, style: AppText.micro.copyWith(color: fg.withValues(alpha: .8), fontWeight: FontWeight.w500)),
              ]),
            ),
          ]);
    return Semantics(
      button: true, enabled: enabled, label: label,
      child: Opacity(
        opacity: onPressed == null ? .45 : 1,
        child: SizedBox(
          width: fullWidth ? double.infinity : null,
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: height), child: Material(
            color: bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill), side: border ?? BorderSide.none),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
              onTap: enabled ? onPressed : null,
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Center(child: ExcludeSemantics(child: child))),
            ),
          )),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.label, {super.key, this.onPressed, this.loading = false, this.icon, this.sub, this.fullWidth = true});
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final bool loading, fullWidth;
  final IconData? icon;
  @override
  Widget build(BuildContext context) =>
      _BtnBase(label: label, onPressed: onPressed, bg: context.colors.ember, fg: context.colors.onEmber, loading: loading, icon: icon, sub: sub, fullWidth: fullWidth);
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(this.label, {super.key, this.onPressed, this.loading = false, this.icon, this.fullWidth = true});
  final String label;
  final VoidCallback? onPressed;
  final bool loading, fullWidth;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => _BtnBase(
      label: label, onPressed: onPressed, bg: context.colors.surfaceAlt, fg: context.colors.textPrimary, height: Sizes.secondaryButton, loading: loading, icon: icon, fullWidth: fullWidth);
}

class OutlineButton extends StatelessWidget {
  const OutlineButton(this.label, {super.key, this.onPressed, this.loading = false, this.icon, this.sub, this.fullWidth = true, this.height = Sizes.secondaryButton});
  final String label;
  final String? sub;
  final VoidCallback? onPressed;
  final bool loading, fullWidth;
  final IconData? icon;
  final double height;
  @override
  Widget build(BuildContext context) => _BtnBase(
      label: label, sub: sub, onPressed: onPressed, bg: Colors.transparent, fg: context.colors.textPrimary, height: height,
      border: BorderSide(color: context.colors.borderOutline), loading: loading, icon: icon, fullWidth: fullWidth);
}

class DangerButton extends StatelessWidget {
  const DangerButton(this.label, {super.key, this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => _BtnBase(
      label: label, onPressed: onPressed, bg: context.colors.dangerTint, fg: context.colors.dangerText, height: Sizes.secondaryButton,
      border: BorderSide(color: context.colors.dangerBorder), loading: loading);
}

class TextLink extends StatelessWidget {
  const TextLink(this.label, {super.key, this.onPressed, this.color});
  final String label;
  final VoidCallback? onPressed;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true, label: label,
        child: InkWell(
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Sizes.touch, minWidth: Sizes.touch),
            child: Center(widthFactor: 1, child: Text(label, style: AppText.bodySmall.copyWith(color: color ?? context.colors.emberText, fontWeight: FontWeight.w600))),
          ),
        ),
      );
}
