import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/data/models/soon.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/countries.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../account/views/account_pages.dart';
import '../dedications/controllers/dedications_controllers.dart' show reportReasons;
import '../today/controllers/today_controller.dart';
import '../today/views/today_widgets.dart';
import 'soon_controllers.dart';

/// What a coming-soon screen shows while its flag is off.
class SoonTeaser extends StatelessWidget {
  const SoonTeaser({super.key, required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 56, color: c.textTertiary),
        const SizedBox(height: 16),
        const AppBadge(BadgeKind.comingSoon),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center, style: AppText.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
      ]),
    );
  }
}

/// 69 Challenges.
class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(ChallengesController());
    return AppScaffold(
      title: 'Challenges',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              if (ctrl.off.value) return const SoonTeaser(icon: Icons.emoji_events_outlined, title: 'Challenges are coming', body: 'Meditate any length, once a day. Every meditation counts.');
              final d = ctrl.data.value;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text('Meditate any length, once a day. Every meditation counts.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 16),
                if (d.inProgress.isNotEmpty) ...[
                  Text('IN PROGRESS', style: AppText.overline.copyWith(color: c.textTertiary)),
                  for (final ch in d.inProgress)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: AppCard(key: Key('ch-${ch.id}'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${groupNumber(ch.peopleInIt)} people in it', style: AppText.caption.copyWith(color: c.textTertiary)),
                        Text(ch.name, style: AppText.title.copyWith(color: c.textPrimary)),
                        const SizedBox(height: 8),
                        Text('${ch.me!.completedDays}', style: AppText.display.copyWith(color: c.emberText, fontSize: 40)),
                        Text('of ${ch.days} days', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                        const SizedBox(height: 8),
                        AppProgressBar(ch.me!.completedDays / ch.days),
                        const SizedBox(height: 12),
                        Row(children: [Expanded(child: PrimaryButton('Meditate today', onPressed: () => Get.offAllNamed(AppRoutes.todayMember))), TextLink('Leave', onPressed: () => ctrl.leave(ch), color: c.textSecondary)]),
                      ])),
                    ),
                  const SizedBox(height: 16),
                ],
                Text('START ANOTHER', style: AppText.overline.copyWith(color: c.textTertiary)),
                for (final ch in d.available)
                  ListRow(key: Key('av-${ch.id}'), title: ch.name, subtitle: '${ch.days} days · ${groupNumber(ch.peopleInIt)} people in it', showChevron: false, trailing: SizedBox(width: 96, child: OutlineButton(ch.me?.finishedAt != null ? 'Again' : 'Join', height: 40, loading: ctrl.busy.value == ch.id, onPressed: () => ctrl.join(ch)))),
                if (ctrl.message.value != null) Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText)),
                if (d.finished.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('FINISHED', style: AppText.overline.copyWith(color: c.textTertiary)),
                  for (final f in d.finished) ListRow(title: f.name, subtitle: '${f.days} days', showChevron: false, trailing: Icon(Icons.check_circle_rounded, color: c.success)),
                ],
              ]);
            }),
          )),
    );
  }
}

/// 70 Gratitude feed (live over the socket).
class GratitudePage extends StatelessWidget {
  const GratitudePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(GratitudeController());
    return AppScaffold(
      title: 'Gratitude feed',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            empty: const EmptyState(title: 'Be the first to share', body: 'One thing you’re grateful for today.', icon: Icons.favorite_border_rounded),
            content: () => Obx(() {
              if (ctrl.off.value) return const SoonTeaser(icon: Icons.favorite_border_rounded, title: 'The gratitude feed is coming', body: 'Read and share what people around the world are grateful for.');
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                SingleChildScrollView(scrollDirection: Axis.horizontal, child: PillGroup<String>(options: GratitudeController.kinds, selected: {ctrl.kind.value}, onToggle: ctrl.select, labelOf: GratitudeController.label)),
                const SizedBox(height: 12),
                Text('One thing you’re grateful for today. Shared with everyone in WeHum.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 8),
                TextField(key: const Key('grat-field'), maxLength: 200, onChanged: (v) => ctrl.text.value = v, style: AppText.bodyLarge.copyWith(color: c.textPrimary), decoration: InputDecoration(hintText: 'What are you grateful for?', filled: true, fillColor: c.surfaceInput, counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)))),
                const SizedBox(height: 8),
                PrimaryButton('Share', key: const Key('grat-share'), loading: ctrl.busy.value, onPressed: () async {
                  final r = await ctrl.share();
                  if (r == PostOutcomeG.membership) openPaywall('lock');
                  if (r == PostOutcomeG.account && context.mounted) await showAccountGate(context);
                }),
                if (ctrl.message.value != null) Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText)),
                const SizedBox(height: 12),
                for (final p in ctrl.posts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppCard(key: Key('post-${p.id}'), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('“${p.text}”', style: AppText.body.copyWith(color: c.textBody)), const SizedBox(height: 4), Text('${p.firstName}${p.country == null ? '' : ' · ${countryName(p.country)}'}', style: AppText.caption.copyWith(color: c.textTertiary))])),
                      PopupMenuButton<String>(tooltip: 'Report', onSelected: (r) => ctrl.report(p, r), itemBuilder: (_) => [for (final (id, label) in reportReasons) PopupMenuItem(value: id, child: Text(label))]),
                    ])),
                  ),
              ]);
            }),
          )),
    );
  }
}

/// 71 Breathwork.
class BreathworkPage extends StatelessWidget {
  const BreathworkPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(BreathworkController());
    return AppScaffold(
      title: 'Breathwork',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              if (ctrl.off.value) return const SoonTeaser(icon: Icons.air_rounded, title: 'Breathwork is coming', body: 'Design your own breathing patterns, or start from a template.');
              final d = ctrl.data.value;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text('DESIGN YOUR OWN', style: AppText.overline.copyWith(color: c.textTertiary)),
                AppCard(key: const Key('designer-card'), onTap: () => Get.toNamed(AppRoutes.breathPattern), child: const ListRow(title: 'Pattern designer', subtitle: 'Rounds and beats for in, hold, out, hold', leading: IconTile(Icons.tune_rounded))),
                if (ctrl.mine.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('YOUR PATTERNS', style: AppText.overline.copyWith(color: c.textTertiary)),
                  for (final p in ctrl.mine) ListRow(key: Key('mine-${p.id}'), title: p.name, subtitle: '${p.beats} · ${p.rounds} rounds', leading: const IconTile(Icons.air_rounded), onTap: () => Get.toNamed(AppRoutes.breathRun, arguments: p), trailing: IconButton(tooltip: 'Delete', onPressed: () => ctrl.deleteMine(p), icon: const Icon(Icons.delete_outline_rounded))),
                ],
                const SizedBox(height: 16),
                Text('START FROM A TEMPLATE', style: AppText.overline.copyWith(color: c.textTertiary)),
                for (final t in d.templates) ListRow(key: Key('tpl-${t.name}'), title: t.name, subtitle: '${t.subtitle ?? ''}${t.subtitle == null ? '' : ' · '}${t.beats}', leading: const IconTile(Icons.air_rounded), onTap: () => Get.toNamed(AppRoutes.breathRun, arguments: t)),
                if (d.lessons.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('LESSONS WITH RAPHAEL', style: AppText.overline.copyWith(color: c.textTertiary)),
                  for (final l in d.lessons) ListRow(title: l.session.title, subtitle: 'Lesson ${l.lesson} · ${l.session.minutes} min', onTap: () => Get.toNamed('/session/${l.session.id}', arguments: {'id': l.session.id})),
                ],
              ]);
            }),
          )),
    );
  }
}

/// 72 Breath pattern designer.
class BreathPatternPage extends StatelessWidget {
  const BreathPatternPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(PatternDesignerController());
    Widget stepper(String label, RxInt v, {int min = 0, int max = 20, String unit = 's'}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: AppText.bodyLarge.copyWith(color: c.textPrimary))),
            IconButton(tooltip: 'Less $label', onPressed: () => ctrl.adjust(v, -1, min: min, max: max), icon: const Icon(Icons.remove_circle_outline_rounded)),
            SizedBox(width: 44, child: Text('${v.value}$unit', key: Key('v-$label'), textAlign: TextAlign.center, style: AppText.navTitle.copyWith(color: c.textPrimary))),
            IconButton(tooltip: 'More $label', onPressed: () => ctrl.adjust(v, 1, min: min, max: max), icon: const Icon(Icons.add_circle_outline_rounded)),
          ]),
        );
    return AppScaffold(
      title: 'Pattern designer',
      body: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
            Center(child: Text(ctrl.pattern.beats, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 44))),
            Center(child: Text(ctrl.summary, key: const Key('pattern-summary'), style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
            const SizedBox(height: 12),
            stepper('Breathe in', ctrl.inhale, min: 1),
            stepper('Hold', ctrl.hold1),
            stepper('Breathe out', ctrl.exhale, min: 1),
            stepper('Hold ', ctrl.hold2),
            stepper('Rounds', ctrl.rounds, min: 1, max: 100, unit: ''),
            TextFormField(key: const Key('pattern-name'), initialValue: ctrl.name.value, onChanged: (v) => ctrl.name.value = v, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            if (ctrl.error != null) Text(ctrl.error!, key: const Key('pattern-error'), style: AppText.bodySmall.copyWith(color: c.dangerText)),
            if (ctrl.message.value != null && ctrl.error == null) Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText)),
            const SizedBox(height: 12),
            PrimaryButton('Start breathing', key: const Key('pattern-start'), onPressed: ctrl.error == null ? ctrl.start : null),
            const SizedBox(height: 8),
            OutlineButton('Save pattern', key: const Key('pattern-save'), loading: ctrl.busy.value, onPressed: ctrl.error == null ? () async {
              if (await ctrl.save() && context.mounted) AppSnack.success(context, 'Pattern saved');
            } : null),
            const SizedBox(height: 12),
            Center(child: Text('Stop if you feel dizzy. Not for use while driving or in water.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary))),
          ])),
    );
  }
}

/// The animated breathing screen (circle grows on in, stays on hold, shrinks on out).
class BreathRunPage extends StatefulWidget {
  const BreathRunPage({super.key});
  @override
  State<BreathRunPage> createState() => _BreathRunPageState();
}

class _BreathRunPageState extends State<BreathRunPage> {
  late final BreathSession s = BreathSession(Get.arguments as BreathPattern)..start();
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(s.tick);
      if (s.done) _t?.cancel();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final big = s.phase == BreathPhase.inhale || s.phase == BreathPhase.hold1;
    final label = switch (s.phase) { BreathPhase.inhale => 'Breathe in', BreathPhase.hold1 || BreathPhase.hold2 => 'Hold', BreathPhase.exhale => 'Breathe out', BreathPhase.done => 'Done' };
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Scaffold(
      body: SafeArea(
        child: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(children: [
            Align(alignment: Alignment.centerRight, child: TextLink(s.done ? 'Close' : 'End', key: const Key('breath-end'), onPressed: () => Get.back<void>(), color: c.textSecondary)),
            const Spacer(),
            AnimatedContainer(
              duration: reduce ? Duration.zero : Duration(seconds: s.phase == BreathPhase.inhale ? s.pattern.inhaleSec : (s.phase == BreathPhase.exhale ? s.pattern.exhaleSec : 1)), curve: Curves.easeInOut,
              width: big ? 240 : 140, height: big ? 240 : 140, decoration: BoxDecoration(shape: BoxShape.circle, color: c.emberTint, border: Border.all(color: c.ember, width: 3)),
              child: Center(child: Text(s.done ? '' : '${s.left}', style: AppText.display.copyWith(color: c.textPrimary))),
            ),
            const SizedBox(height: 24),
            Text(label, key: const Key('breath-phase'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            Text(s.done ? 'Well done.' : 'Round ${s.round} of ${s.pattern.rounds}', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const Spacer(),
            Text('Stop if you feel dizzy.', style: AppText.caption.copyWith(color: c.textTertiary)),
          ]),
        ),
      ),
    );
  }
}

/// 73 Milestones.
class MilestonesPage extends StatelessWidget {
  const MilestonesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(MilestonesController());
    return AppScaffold(
      title: 'Milestones',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              if (ctrl.off.value) return const SoonTeaser(icon: Icons.workspace_premium_outlined, title: 'Milestones are coming', body: 'Awards for the practice you build, and the world’s progress together.');
              final d = ctrl.data.value;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text('YOUR AWARDS · ${d.reached} OF ${d.total}', key: const Key('awards-title'), style: AppText.overline.copyWith(color: c.textTertiary)),
                const SizedBox(height: 8),
                AdaptiveGrid(columns: 3, baseExtent: 118, children: [
                  for (final a in d.awards)
                    Opacity(
                      opacity: a.reached ? 1 : .45,
                      child: AppCard(key: Key('award-${a.key}'), padding: const EdgeInsets.all(10), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(a.badge, style: AppText.title.copyWith(color: a.reached ? c.emberText : c.textTertiary)), const SizedBox(height: 4), Text(a.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary)), if (!a.reached) Text('${a.value}/${a.target}', style: AppText.micro.copyWith(color: c.textTertiary))])),
                    ),
                ]),
                const SizedBox(height: 20),
                Text('THE WORLD SO FAR', style: AppText.overline.copyWith(color: c.textTertiary)),
                const SizedBox(height: 8),
                for (final (k, label) in [('minutes', 'minutes meditated on WeHum'), ('meditations', 'meditations'), ('countries', 'countries'), ('dedications', 'dedications')])
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text(_compact(d.world[k] ?? 0), style: AppText.title.copyWith(color: c.textPrimary)), const SizedBox(width: 10), Text(label, style: AppText.bodyLarge.copyWith(color: c.textSecondary))])),
              ]);
            }),
          )),
    );
  }

  static String _compact(int v) => v >= 1000000 ? '${(v / 1000000).toStringAsFixed(1)}M' : (v >= 1000 ? '${(v / 1000).round()}k' : '$v');
}

/// 74 Intent (setup step, behind `features.intent`).
class IntentPage extends StatelessWidget {
  const IntentPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(IntentController());
    return Scaffold(
      body: SafeArea(
        child: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Align(alignment: Alignment.centerRight, child: TextLink('Skip', onPressed: ctrl.skip, color: c.textSecondary)),
                const SizedBox(height: 12),
                Text('What brings you here?', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                Text('Pick one. It sets your first recommendation.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 20),
                for (final (k, t, sub) in IntentController.choices)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(key: Key('intent-$k'), color: ctrl.selected.value == k ? c.emberTint : null, onTap: () => ctrl.pick(k), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.navTitle.copyWith(color: c.textPrimary)), Text(sub, style: AppText.bodySmall.copyWith(color: c.textSecondary))]))),
                const Spacer(),
                PrimaryButton('Continue', key: const Key('intent-next'), onPressed: ctrl.selected.value == null ? null : ctrl.next),
              ])),
        ),
      ),
    );
  }
}
