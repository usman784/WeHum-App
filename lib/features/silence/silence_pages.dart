import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/countries.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/countdown_text.dart';
import 'silence_controller.dart';

SilenceController _ctrl() {
  if (Get.isRegistered<SilenceController>() && Get.find<SilenceController>().phase.value == SilencePhase.done) Get.delete<SilenceController>(force: true); // a finished session starts clean
  return Get.isRegistered<SilenceController>() ? Get.find<SilenceController>() : Get.put(SilenceController());
}

/// 50 Silence Room setup.
class SilenceSetupPage extends StatelessWidget {
  const SilenceSetupPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return AppScaffold(
      title: 'Silence Room',
      body: Obx(() {
        final top = ctrl.live.agg.value?.top ?? const <({String country, int n})>[];
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
          Text(ctrl.bigNum, key: const Key('silence-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
          Text(ctrl.bigLabel, key: const Key('silence-label'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          if (top.isNotEmpty && !ctrl.live.paused) Padding(padding: const EdgeInsets.only(top: 6), child: Text(top.take(4).map((t) => countryName(t.country)).join(' · '), style: AppText.bodySmall.copyWith(color: c.textTertiary))),
          if (ctrl.live.agg.value?.quiet ?? false) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Quiet right now. We never add fake numbers, so this is the honest count of everyone who meditated here today.', style: AppText.caption.copyWith(color: c.textTertiary))),
          const SizedBox(height: 20),
          Text('TIMER', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          PillGroup<int>(options: SilenceController.presets, selected: {ctrl.minutes.value}, onToggle: (v) => ctrl.minutes.value = v, labelOf: (v) => v == 0 ? 'Open' : '$v min'),
          const SizedBox(height: 4),
          Text(ctrl.openEnded ? 'No end: finish whenever you like.' : '${ctrl.minutes.value} minutes, then the bell.', style: AppText.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: 20),
          Text('CHIME', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 4),
          Row(children: [Expanded(child: Text('Bell at the start', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('bell-start'), value: ctrl.bellStart.value, onChanged: (v) => ctrl.bellStart.value = v, label: 'Bell at the start')]),
          Row(children: [Expanded(child: Text('Bell at the end', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('bell-end'), value: ctrl.bellEnd.value, onChanged: (v) => ctrl.bellEnd.value = v, label: 'Bell at the end')]),
          const SizedBox(height: 20),
          PrimaryButton('Enter the Silence Room', key: const Key('silence-enter'), onPressed: ctrl.enter),
          const SizedBox(height: 10),
          Center(child: Text('Part of membership. Others see only your country, never your name.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary))),
        ]);
      }),
    );
  }
}

/// 51 Silence Room meditating: remaining time, dims after a few seconds, tap to wake.
class SilenceRunPage extends StatelessWidget {
  const SilenceRunPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.finish(completed: false);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque, onTap: ctrl.wake,
          child: SafeArea(
            child: Obx(() {
              final dim = ctrl.dimmed.value;
              final paused = ctrl.phase.value == SilencePhase.paused;
              final shown = ctrl.openEnded ? ctrl.elapsed.value : ctrl.remaining.value;
              return AnimatedOpacity(
                opacity: dim ? .15 : 1, duration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.gutterOnboarding),
                  child: Column(children: [
                    Align(alignment: Alignment.centerRight, child: TextLink('End', key: const Key('silence-end'), onPressed: () => ctrl.finish(completed: false), color: c.textSecondary)),
                    const Spacer(),
                    Text('SILENCE ROOM · ${ctrl.openEnded ? 'OPEN' : '${ctrl.minutes.value} MIN'}', style: AppText.overline.copyWith(color: c.textTertiary)),
                    const SizedBox(height: 12),
                    Text(formatCountdown(shown), key: const Key('silence-time'), style: AppText.display.copyWith(color: Colors.white, fontSize: 76, fontFeatures: AppText.tabular)),
                    const SizedBox(height: 8),
                    Text(paused ? 'Paused' : (ctrl.live.paused ? 'Live counts paused' : '${ctrl.bigNum} ${ctrl.bigLabel}'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                    const Spacer(),
                    OutlineButton(paused ? 'Resume' : 'Pause', key: const Key('silence-pause'), onPressed: paused ? ctrl.resume : ctrl.pause),
                    const SizedBox(height: 12),
                    Text('The screen dims after a few seconds. Tap to wake it.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
