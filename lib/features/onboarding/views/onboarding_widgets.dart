import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';

/// 5 pagination dots (intro 1–4 + start). Current one is a wide pill.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.index, this.count = 5});
  final int index;
  final int count;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: 'Step ${index + 1} of $count',
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: Motion.state, margin: const EdgeInsets.symmetric(horizontal: 4), width: i == index ? 24 : 8, height: 8,
            decoration: BoxDecoration(color: i == index ? c.ember : c.track, borderRadius: BorderRadius.circular(Radii.pill)),
          ),
      ]),
    );
  }
}

/// Common frame for the onboarding slides: top row (back / skip), content, dots, primary button.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({super.key, required this.child, this.onSkip, this.skipLabel = 'Skip', this.showBack = false, this.dots, this.cta, this.onCta, this.ctaEnabled = true, this.ctaLoading = false, this.footer, this.topRight});
  final Widget child;
  final VoidCallback? onSkip, onCta;
  final String skipLabel;
  final bool showBack, ctaEnabled, ctaLoading;
  final int? dots;
  final String? cta;
  final Widget? footer, topRight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.gutterOnboarding),
          child: Column(children: [
            SizedBox(
              height: 56,
              child: Row(children: [
                if (showBack)
                  Semantics(
                    button: true, label: 'Back',
                    child: GestureDetector(
                      onTap: () => Get.back<void>(),
                      child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)), child: Icon(Icons.chevron_left_rounded, color: c.textPrimary)),
                    ),
                  ),
                const Spacer(),
                topRight ?? (onSkip == null ? const SizedBox.shrink() : TextLink(skipLabel, onPressed: onSkip, color: c.textSecondary)),
              ]),
            ),
            Expanded(child: child),
            if (dots != null) Padding(padding: const EdgeInsets.only(bottom: 20), child: StepDots(index: dots!)),
            if (cta != null) PrimaryButton(cta!, onPressed: ctaEnabled ? onCta : null, loading: ctaLoading),
            if (footer != null) footer! else const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}
