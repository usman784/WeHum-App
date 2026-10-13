import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:get/get.dart';
import '../../core/data/models/stitch.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/countdown_text.dart';
import '../../core/widgets/painters.dart';
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';
import 'package:intl/intl.dart';
import 'silence_controller.dart';
import 'silence_widgets.dart';
import '../../app/routes/app_routes.dart';

SilenceController _ctrl() {
  if (Get.isRegistered<SilenceController>() && Get.find<SilenceController>().phase.value == SilencePhase.done) Get.delete<SilenceController>(force: true); // a finished session starts clean
  return Get.isRegistered<SilenceController>() ? Get.find<SilenceController>() : Get.put(SilenceController());
}

/// 50 Silence Room setup (busy) and its quiet variant (Stitch "low traffic"): honest numbers, durations, bells.
class SilenceSetupPage extends StatelessWidget {
  const SilenceSetupPage({super.key});

  String _bellName(List<BellOption> opts, String? id, String fallback) {
    for (final o in opts) {
      if (o.id == id) return o.name;
    }
    return opts.isNotEmpty ? opts.first.name : fallback;
  }

  void _cycle(List<BellOption> opts, String? cur, RxnString target) {
    if (opts.length < 2) return;
    final i = opts.indexWhere((o) => o.id == cur);
    target.value = opts[(i + 1) % opts.length].id;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return AppScaffold(
      title: 'Silence Room', stitch: true,
      body: Obx(() {
        final info = ctrl.info.value;
        final quiet = ctrl.quietRoom;
        final belts = ctrl.live.silence.value == null ? (info?.belts ?? const Belts()) : Belts(americas: ctrl.live.silence.value!.americas, emea: ctrl.live.silence.value!.emea, apac: ctrl.live.silence.value!.apac);
        final dur = ctrl.durations;
        final opening = info?.opening ?? const <BellOption>[], interval = info?.interval ?? const <BellOption>[], closing = info?.closing ?? const <BellOption>[];
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 6, Gap.gutter, 28), children: staggered([
          if (quiet) ...[
            Row(children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('QUIET SANCTUARY', style: AppText.overline.copyWith(color: c.textSecondary)),
            ]),
            const SizedBox(height: 8),
            Text(ctrl.bigNum, key: const Key('silence-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
            Text(ctrl.bigLabel, key: const Key('silence-label'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            if ((ctrl.sittingNow ?? 0) > 0)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('${ctrl.sittingNow} quietly right now${(info?.todayZones ?? 0) > 1 ? ' · across ${info!.todayZones} zones' : ''}', key: const Key('silence-quiet-now'), style: AppText.bodySmall.copyWith(color: c.textSecondary))),
            AppCard(
              outlined: true, key: const Key('honest-card'),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.verified_user_outlined, size: 18, color: c.tealText),
                const SizedBox(width: 10),
                Expanded(child: Text('Honest presence. We never add synthetic sitters or inflate activity. When the room rests in quiet, we show everyone who sat here today.', style: AppText.caption.copyWith(color: c.textSecondary))),
              ]),
            ),
          ] else ...[
            LivePresenceRow(label: '${ctrl.bigNum} ${ctrl.bigLabel}', quiet: false),
            if (!belts.isEmpty) BeltsCard(belts: belts, onTap: () => Get.toNamed(AppRoutes.worldMapWorldVibration)),
          ],
          BreathRing(minutes: ctrl.minutes.value, inhaleSec: ctrl.inhaleSec, exhaleSec: ctrl.exhaleSec),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('SELECT SIT DURATION', style: AppText.overline.copyWith(color: c.textSecondary))),
              Text('Free unguided room', style: AppText.caption.copyWith(color: c.textSecondary)),
            ]),
            const SizedBox(height: 10),
            DurationGrid(options: dur, selected: ctrl.minutes.value, onPick: (v) => ctrl.minutes.value = v),
            const SizedBox(height: 8),
            Text(ctrl.openEnded ? 'No end: finish whenever you like.' : '${ctrl.minutes.value} minutes, then the bell. Breathing cue: ${ctrl.inhaleSec} s in · ${ctrl.exhaleSec} s out', style: AppText.caption.copyWith(color: c.textTertiary)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('ACOUSTIC INTERVALS & SIGNALS', style: AppText.overline.copyWith(color: c.textSecondary))),
            ]),
            const SizedBox(height: 10),
            AcousticRow(
              icon: Icons.notifications_active_outlined, iconColor: c.ember, title: 'Opening bell', subtitle: '${_bellName(opening, ctrl.openingId.value, 'Tibetan bowl')} · 1 strike',
              value: ctrl.bellStart.value, onChanged: (v) => ctrl.bellStart.value = v, toggleKey: const Key('bell-start'),
              chip: opening.length > 1 ? _bellName(opening, ctrl.openingId.value, 'Bowl').split(' ').first : null, onChip: () => _cycle(opening, ctrl.openingId.value, ctrl.openingId),
            ),
            const SizedBox(height: 8),
            AcousticRow(
              icon: Icons.hourglass_empty_rounded, iconColor: c.tealText, title: 'Interval marker', subtitle: '${_bellName(interval, ctrl.intervalId.value, 'Soft temple tone')} · every ${ctrl.intervalMin.value == 0 ? 5 : ctrl.intervalMin.value} min',
              value: ctrl.chimeOn.value, onChanged: (v) => ctrl.chimeOn.value = v, toggleKey: const Key('interval-toggle'),
              chip: interval.length > 1 ? _bellName(interval, ctrl.intervalId.value, 'Temple').split(' ').first : null, onChip: () => _cycle(interval, ctrl.intervalId.value, ctrl.intervalId),
            ),
            const SizedBox(height: 8),
            AcousticRow(
              icon: Icons.celebration_outlined, iconColor: c.ember, title: 'Closing sequence', subtitle: '${_bellName(closing, ctrl.closingId.value, '3 dissolving gongs')} · re-entry',
              value: ctrl.bellEnd.value, onChanged: (v) => ctrl.bellEnd.value = v, toggleKey: const Key('bell-end'),
              chip: closing.length > 1 ? _bellName(closing, ctrl.closingId.value, 'Gong').split(' ').first : null, onChip: () => _cycle(closing, ctrl.closingId.value, ctrl.closingId),
            ),
          ]),
          Container(
            padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(12)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.brightness_low_rounded, size: 18, color: c.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text('The screen dims to near-black 5 seconds after the sit starts. Tap anywhere to wake the controls.', style: AppText.caption.copyWith(color: c.textSecondary, height: 1.5))),
            ]),
          ),
          Column(children: [
            PrimaryButton(ctrl.openEnded ? 'Begin silent sit' : 'Begin silent sit · ${ctrl.minutes.value} min', key: const Key('silence-enter'), icon: Icons.play_arrow_rounded, onPressed: ctrl.enter),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Flexible(child: Text('NO VOICE GUIDANCE · ZERO DISTRACTION', textAlign: TextAlign.center, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))),
            ]),
          ]),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 20), child: w)).toList()));
      }),
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
