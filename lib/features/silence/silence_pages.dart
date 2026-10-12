import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:get/get.dart';
import '../../core/data/models/stitch.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/countdown_text.dart';
import '../../core/widgets/painters.dart';
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';
import 'package:intl/intl.dart';
import 'silence_controller.dart';

SilenceController _ctrl() {
  if (Get.isRegistered<SilenceController>() && Get.find<SilenceController>().phase.value == SilencePhase.done) Get.delete<SilenceController>(force: true); // a finished session starts clean
  return Get.isRegistered<SilenceController>() ? Get.find<SilenceController>() : Get.put(SilenceController());
}

/// 50 Silence Room setup (busy) and its quiet variant (Stitch "low traffic"): honest numbers, durations, bells.
class SilenceSetupPage extends StatelessWidget {
  const SilenceSetupPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return AppScaffold(
      title: 'Silence Room',
      body: Obx(() {
        final info = ctrl.info.value;
        final quiet = ctrl.quietRoom;
        final belts = ctrl.live.silence.value == null ? (info?.belts ?? const Belts()) : Belts(americas: ctrl.live.silence.value!.americas, emea: ctrl.live.silence.value!.emea, apac: ctrl.live.silence.value!.apac);
        final dur = ctrl.durations;
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: staggered([
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: quiet ? c.textTertiary : c.success, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(quiet ? 'QUIET SANCTUARY' : 'LIVE SYNC', style: AppText.overline.copyWith(color: c.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Text(ctrl.bigNum, key: const Key('silence-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
          Text(ctrl.bigLabel, key: const Key('silence-label'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          if (quiet && (ctrl.sittingNow ?? 0) > 0)
            Padding(padding: const EdgeInsets.only(top: 4), child: Text('${ctrl.sittingNow} quietly right now${(info?.todayZones ?? 0) > 1 ? ' · across ${info!.todayZones} zones' : ''}', key: const Key('silence-quiet-now'), style: AppText.bodySmall.copyWith(color: c.textSecondary))),
          if (!quiet && !belts.isEmpty) ...[const SizedBox(height: 14), BeltCounts(key: const Key('silence-belts'), belts: belts)],
          if (quiet)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: AppCard(
                outlined: true, key: const Key('honest-card'),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.verified_user_outlined, size: 18, color: c.tealText),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Honest presence. We never add synthetic sitters or inflate activity. When the room rests in quiet, we show everyone who sat here today.', style: AppText.caption.copyWith(color: c.textSecondary))),
                ]),
              ),
            ),
          const SizedBox(height: 22),
          Text('SIT DURATION', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          PillGroup<int>(options: dur, selected: {ctrl.minutes.value}, onToggle: (v) => ctrl.minutes.value = v, labelOf: (v) => v == 0 ? 'Open' : '$v min'),
          const SizedBox(height: 4),
          Text(ctrl.openEnded ? 'No end: finish whenever you like.' : '${ctrl.minutes.value} minutes, then the bell.', style: AppText.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Breathing cue: ${ctrl.inhaleSec} s in · ${ctrl.exhaleSec} s out', style: AppText.caption.copyWith(color: c.textTertiary)),
          const SizedBox(height: 22),
          Text('ACOUSTIC INTERVALS & SIGNALS', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 6),
          Row(children: [Expanded(child: Text('Opening bell', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('bell-start'), value: ctrl.bellStart.value, onChanged: (v) => ctrl.bellStart.value = v, label: 'Bell at the start')]),
          if (info != null && info.opening.length > 1) _BellPick(options: info.opening, selected: ctrl.openingId.value, onPick: (id) => ctrl.openingId.value = id),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Interval marker', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Text('A soft tone every ${ctrl.intervalMin.value == 0 ? 5 : ctrl.intervalMin.value} minutes', style: AppText.caption.copyWith(color: c.textSecondary))])),
            AppToggle(key: const Key('interval-toggle'), value: ctrl.chimeOn.value, onChanged: (v) => ctrl.chimeOn.value = v, label: 'Interval marker'),
          ]),
          if (info != null && info.interval.length > 1) _BellPick(options: info.interval, selected: ctrl.intervalId.value, onPick: (id) => ctrl.intervalId.value = id),
          Row(children: [Expanded(child: Text('Closing sequence', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('bell-end'), value: ctrl.bellEnd.value, onChanged: (v) => ctrl.bellEnd.value = v, label: 'Bell at the end')]),
          if (info != null && info.closing.length > 1) _BellPick(options: info.closing, selected: ctrl.closingId.value, onPick: (id) => ctrl.closingId.value = id),
          const SizedBox(height: 20),
          Row(children: [
            Icon(Icons.brightness_low_rounded, size: 18, color: c.textTertiary),
            const SizedBox(width: 8),
            Expanded(child: Text('The screen dims to near-black 5 seconds after the sit starts. Tap anywhere to wake the controls.', style: AppText.caption.copyWith(color: c.textTertiary))),
          ]),
          const SizedBox(height: 16),
          PrimaryButton(ctrl.openEnded ? 'Begin silent sit' : 'Begin silent sit · ${ctrl.minutes.value} min', key: const Key('silence-enter'), onPressed: ctrl.enter),
          const SizedBox(height: 10),
          Center(child: Text('No voice guidance. Part of membership. Others see only a count, never your name.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary))),
        ]));
      }),
    );
  }
}

/// Small horizontal chooser for a bell (only shown when the CMS offers more than one).
class _BellPick extends StatelessWidget {
  const _BellPick({required this.options, required this.selected, required this.onPick});
  final List<BellOption> options;
  final String? selected;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (final o in options)
          GestureDetector(
            key: Key('bell-${o.id}'), onTap: () => onPick(o.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: selected == o.id ? c.emberTint : c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: selected == o.id ? c.ember : c.border)),
              child: Text(o.name, style: AppText.caption.copyWith(color: selected == o.id ? c.emberText : c.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }
}

/// 51 Silence Room meditating: breathing cue, remaining time, people with you, next chime. Dims after a few seconds; tap wakes.
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
              final next = ctrl.nextChimeAt;
              final people = ctrl.sittingNow;
              return AnimatedOpacity(
                opacity: dim ? .15 : 1, duration: const Duration(milliseconds: 600),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.gutterOnboarding),
                  child: Column(children: [
                    Align(alignment: Alignment.centerRight, child: TextLink('End sit', key: const Key('silence-end'), onPressed: () => ctrl.finish(completed: false), color: c.textSecondary)),
                    const Spacer(),
                    Text('SILENCE ROOM · ${ctrl.openEnded ? 'OPEN' : '${ctrl.minutes.value} MIN'}', style: AppText.overline.copyWith(color: c.textTertiary)),
                    const SizedBox(height: 18),
                    const BreathCue(),
                    const SizedBox(height: 18),
                    Text(formatCountdown(shown), key: const Key('silence-time'), style: AppText.display.copyWith(color: Colors.white, fontSize: 76, fontFeatures: AppText.tabular)),
                    const SizedBox(height: 8),
                    Text(
                      paused ? 'Paused' : (ctrl.live.paused ? 'Live counts paused' : (people != null && people > 1 ? '${groupedInt(people)} sitting with you right now' : 'You’re sitting in silence')),
                      key: const Key('silence-with'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                    if (next != null && !paused) ...[
                      const SizedBox(height: 6),
                      Text('Next chime at ${DateFormat('HH:mm').format(next.toLocal())}', key: const Key('next-chime'), style: AppText.caption.copyWith(color: c.textTertiary, fontFeatures: AppText.tabular)),
                    ],
                    const Spacer(),
                    Row(children: [
                      if (!ctrl.openEnded) Expanded(child: OutlineButton('+${ctrl.extendMin} min', key: const Key('silence-extend'), onPressed: ctrl.extend)),
                      if (!ctrl.openEnded) const SizedBox(width: 10),
                      Expanded(child: OutlineButton(paused ? 'Resume' : 'Pause', key: const Key('silence-pause'), onPressed: paused ? ctrl.resume : ctrl.pause)),
                      const SizedBox(width: 10),
                      Expanded(child: OutlineButton(ctrl.chimeOn.value ? 'Chime on' : 'Chime off', key: const Key('silence-chime'), onPressed: () => ctrl.chimeOn.value = !ctrl.chimeOn.value)),
                    ]),
                    const SizedBox(height: 12),
                    Text('Tap anywhere to brighten the controls. The screen dims in 5 seconds.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary)),
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
