import 'dart:math' as math;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
import '../../../core/data/models/stitch.dart';
import '../../../core/data/models/today.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/countries.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/stitch.dart';
import '../../../core/widgets/surfaces.dart';
import '../../today/controllers/today_controller.dart';
import '../../today/views/today_pages.dart' show tabHeader;
import '../../today/views/today_widgets.dart';
import '../controllers/together_controllers.dart';

String _ago(DateTime? d) {
  if (d == null) return '';
  final m = DateTime.now().toUtc().difference(d).inMinutes;
  return m < 1 ? 'now' : (m < 60 ? '${m}m' : (m < 1440 ? '${m ~/ 60}h' : '${m ~/ 1440}d'));
}

/// A dedication line: “text” · Name, Country.
class DedicationLine extends StatelessWidget {
  const DedicationLine(this.d, {super.key});
  final Dedication d;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('“${d.text}”', style: AppText.body.copyWith(color: c.textBody)),
        Text('${d.firstName}${d.country == null ? '' : ' · ${countryName(d.country)}'}${d.createdAt == null ? '' : ' · ${_ago(d.createdAt)}'}', style: AppText.caption.copyWith(color: c.textTertiary)),
      ]),
    );
  }
}

/// 23 Meditation of the Day room.
class MotdRoomPage extends StatelessWidget {
  const MotdRoomPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(MotdRoomController());
    return Obx(() => AppScaffold(
          title: 'Meditation of the Day', action: const Padding(padding: EdgeInsets.only(right: 4), child: SosPill()),
          body: StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final d = ctrl.data.value!;
              final m = d.motd!;
              final g = ctrl.group;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: staggered([
                HeroImageCard(image: m.cover?.url, blurHash: m.cover?.blurhash, seed: m.sessionId, height: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  const SizedBox(height: 70),
                  const Overline('Meditation of the day'),
                  const SizedBox(height: 4),
                  Text(m.title, style: AppText.heroTitle.copyWith(color: Colors.white)),
                  Text('with ${m.teacher ?? 'Raphael'}${m.theme == null ? '' : ' · ${m.theme}'}', style: AppText.bodyLarge.copyWith(color: Colors.white70)),
                ])),
                const SizedBox(height: 12),
                if (ctrl.practiced > 0) Text('${groupNumber(ctrl.practiced)} ${ctrl.practiced == 1 ? 'person' : 'people'} practiced this meditation today', key: const Key('practiced'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (ctrl.liveText != null) LivePill(text: ctrl.liveText!, quiet: ctrl.live.paused || (ctrl.live.agg.value?.quiet ?? false)),
                    const SizedBox(height: 10),
                    Text('Start now and meditate with other souls around the world…', style: AppText.body.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 12),
                    if (m.lengths.isNotEmpty) SegmentedControl<int>(options: m.lengths, value: ctrl.length.value, onChanged: (v) => ctrl.length.value = v, labelOf: (v) => '$v min'),
                    const SizedBox(height: 12),
                    PrimaryButton(ctrl.isMember ? 'Meditate now · ${ctrl.length.value} min' : 'Try 7 days free', key: const Key('room-meditate'), onPressed: ctrl.meditateNow),
                  ]),
                ),
                if (g != null && ctrl.groupOpen) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    key: const Key('group-card'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline('Next group meditation · ${ctrl.groupTime} your time', color: c.tealText),
                      const SizedBox(height: 6),
                      CountdownText(target: g.startsAt, now: ctrl.time.now, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 32)),
                      const SizedBox(height: 12),
                      PrimaryButton('Wait in the lobby', key: const Key('room-lobby'), onPressed: () => Get.toNamed(AppRoutes.groupMeditationLobby)),
                      const SizedBox(height: 8),
                      OutlineButton(ctrl.reminder.value ? 'Reminder on' : 'Remind me', key: const Key('room-remind'), onPressed: ctrl.toggleReminder),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Today’s dedications', style: AppText.title.copyWith(color: c.textPrimary)),
                if (ctrl.dedications.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Dedications will load when you’re back.', style: AppText.bodySmall.copyWith(color: c.textSecondary)))
                else
                  for (final x in ctrl.dedications.take(2)) DedicationLine(x),
                const SizedBox(height: 8),
                Text('You can meditate right away on your own, or wait and start together with everyone.', style: AppText.caption.copyWith(color: c.textTertiary)),
              ]));
            }),
          ),
        ));
  }
}

/// 25 World map & global gauge (Stitch): total, countries, World Vibration with the day's trend, minutes, regional belts.
class WorldPage extends StatelessWidget {
  const WorldPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(WorldController());
    return AppScaffold(
      title: 'Global presence', stitch: true,
      body: Obx(() {
        final trend = ctrl.trendPct;
        final live = !(ctrl.paused || ctrl.quiet);
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 6, Gap.gutter, 28), children: staggered([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(ctrl.kicker, key: const Key('world-kicker'), style: AppText.overline.copyWith(color: live ? c.emberText : c.textTertiary, fontSize: 10.5))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  live ? PulseDot(color: c.success, size: 3.5) : Container(width: 7, height: 7, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(live ? 'Synchronized' : (ctrl.paused ? 'Paused' : 'Quiet'), style: AppText.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 11)),
                ]),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Global Presence', style: AppText.heroTitle.copyWith(color: c.textPrimary, fontSize: 30)),
            const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(ctrl.big, key: const Key('world-big'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15, fontFeatures: AppText.tabular)),
              const SizedBox(width: 6),
              Expanded(child: Text(ctrl.sub, style: AppText.bodySmall.copyWith(color: c.textSecondary))),
            ]),
          ]),
          AppCard(
            key: const Key('gauge-card'), padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('WORLD VIBRATION GAUGE', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(ctrl.vibrationWord, style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
                ])),
                if (trend != null) InfoChip(key: const Key('trend'), text: '${trend >= 0 ? '+' : ''}$trend% today', icon: trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, accent: trend >= 0),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                SizedBox(
                  width: 104, height: 104,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: ctrl.vibration / 100), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
                    builder: (_, v, __) => CustomPaint(
                      painter: _GaugePainter(v, c.ember, c.success, c.track),
                      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('${ctrl.vibration}', key: const Key('vibration-num'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 32, fontFeatures: AppText.tabular)),
                        Text('/ 100', style: AppText.caption.copyWith(color: c.textSecondary)),
                      ]))),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: Container(
                  padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(12)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('VOLUME TRACKED', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)),
                    const SizedBox(height: 4),
                    if (ctrl.minutesToday != null && ctrl.minutesToday! > 0)
                      Text('${groupedInt(ctrl.minutesToday!)} min', key: const Key('minutes-today'), style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20, fontFeatures: AppText.tabular))
                    else
                      Text('Quiet · ${ctrl.vibrationWord}', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 2),
                    Text('sat so far today', style: AppText.caption.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 4),
                    Text('/ 100 · ${ctrl.vibrationWord}', key: const Key('vibration'), style: AppText.caption.copyWith(color: c.textTertiary)),
                  ]),
                )),
              ]),
              const SizedBox(height: 14),
              VibrationBar(value: ctrl.vibration, onInfo: () {
                ctrl.openInfo();
                showAppSheet<void>(context, title: 'World Vibration', builder: (_) => Text('The vibration rises when more people meditate on the same day and when group meditations gather many people at once. It moves toward green as the world meditates more.', style: AppText.body.copyWith(color: c.textBody)));
              }),
            ]),
          ),
          AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.travel_explore_rounded, size: 18, color: c.emberText),
                const SizedBox(width: 8),
                Expanded(child: Text('Active sanctuary field', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16))),
                Text('LIVE COARSE HEATMAP', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5)),
              ]),
              const SizedBox(height: 12),
              WorldDotMap(hot: ctrl.paused ? const {} : ctrl.hot, height: 190),
            ]),
          ),
          PrimaryButton('Join the global sit', icon: Icons.play_circle_outline_rounded, onPressed: () => Get.toNamed(AppRoutes.motdRoom)),
          if (ctrl.regions.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACTIVE REGIONAL BELTS', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
            const SizedBox(height: 8),
            for (final r in ctrl.regions) Padding(padding: const EdgeInsets.only(bottom: 10), child: _BeltRow(key: Key('belt-${r.key}'), b: r, name: r.name)),
          ]),
          if (ctrl.countryRows.isNotEmpty) Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('WHERE PEOPLE ARE SITTING', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
            const SizedBox(height: 8),
            for (final b in ctrl.countryRows.take(8)) Padding(padding: const EdgeInsets.only(bottom: 10), child: _BeltRow(key: Key('country-${b.key}'), b: b, name: b.name)),
          ]),
          AppCard(
            outlined: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_outlined, color: c.tealText, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('ZERO-TRACKING PRIVACY GUARANTEE', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)),
                const SizedBox(height: 4),
                Text('Country-level numbers only. We never access, store or show your GPS, your IP trail or who is sitting. Counts come from the server, not from guesses.', style: AppText.caption.copyWith(color: c.textSecondary, height: 1.45)),
              ])),
            ]),
          ),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList()));
      }),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.v, this.a, this.b, this.track);
  final double v;
  final Color a, b, track;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 6);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * v.clamp(0.0, 1.0), false, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..shader = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: [a, b]).createShader(r));
  }

  @override
  bool shouldRepaint(covariant _GaugePainter o) => o.v != v;
}

class _BeltRow extends StatelessWidget {
  const _BeltRow({super.key, required this.b, required this.name});
  final WorldBelt b;
  final String name;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(width: 40, height: 40, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: c.bgDeep, shape: BoxShape.circle), child: Icon(Icons.public_rounded, size: 20, color: c.success)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)),
          Text('${groupedInt(b.sittingNow)} sitting now · ${groupedInt(b.minutesToday)} min today', style: AppText.caption.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
        ])),
        if (b.sittingNow > 0) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${b.syncShare}%', style: AppText.navTitle.copyWith(color: c.emberText, fontFeatures: AppText.tabular)),
          Text('in group sits', style: AppText.micro.copyWith(color: c.textTertiary)),
        ]),
      ]),
    );
  }
}

/// 52 Together (Stitch): the live count, the daily collective sit, the silence room and the shared-intent feed.
class TogetherPage extends StatelessWidget {
  const TogetherPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(TogetherController());
    return AppScaffold(
      header: tabHeader(), bottom: const AppBottomNav(current: AppTab.together),
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final g = ctrl.group.value;
              final running = g != null && g.state != GroupPhase.ended;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text('Together', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                if (ctrl.liveText != null) Align(alignment: Alignment.centerLeft, child: LivePill(key: const Key('together-live'), text: '${ctrl.liveText} · see where', quiet: ctrl.quiet || ctrl.live.paused, onTap: () => Get.toNamed(AppRoutes.worldMapWorldVibration))),
                const SizedBox(height: 16),
                if (running)
                  AppCard(
                    key: const Key('next-group'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline(g.hourly ? 'Hourly sit · ${ctrl.groupTime} your time' : 'Daily collective sit · ${ctrl.groupTime} your time', color: c.tealText),
                      const SizedBox(height: 6),
                      Text(g.focus?.title ?? g.title ?? 'Meditation of the Day', style: AppText.title.copyWith(color: c.textPrimary)),
                      if ((g.focus?.summary ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(g.focus!.summary, style: AppText.bodySmall.copyWith(color: c.textSecondary))),
                      const SizedBox(height: 10),
                      CountdownText(target: g.startsAt, now: ctrl.time.now, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 36)),
                      const SizedBox(height: 4),
                      Text('${groupedInt(g.waiting)} already waiting · ${g.lengthMin} min', style: AppText.bodySmall.copyWith(color: c.textBody, fontFeatures: AppText.tabular)),
                      const SizedBox(height: 12),
                      PrimaryButton(g.state == GroupPhase.live ? 'Join the sit now' : 'Go to the lobby', key: const Key('go-lobby'), onPressed: () => Get.toNamed(AppRoutes.groupMeditationLobby)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: OutlineButton('Sit details', key: const Key('next-sit'), onPressed: () => Get.toNamed(AppRoutes.nextSit))),
                        const SizedBox(width: 10),
                        Expanded(child: OutlineButton(ctrl.reminder.value ? 'Reminder on' : 'Notify me', key: const Key('together-remind'), onPressed: ctrl.toggleReminder)),
                      ]),
                      Center(child: TextLink('or begin now on your own', onPressed: () => Get.toNamed(AppRoutes.motdRoom), color: c.textSecondary)),
                    ]),
                  ),
                const SizedBox(height: 14),
                AppCard(
                  key: const Key('together-silence'), onTap: () => Get.toNamed(AppRoutes.silenceRoomSetup),
                  child: Row(children: [
                    const IconTile(Icons.self_improvement_rounded),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Silence Room', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                      Text(ctrl.silenceCount > 0 ? '${groupedInt(ctrl.silenceCount)} sitting in silence · unguided, timer only' : 'Unguided, timer only · a quiet room, together', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    ])),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ]),
                ),
                const SizedBox(height: 22),
                Row(children: [
                  Expanded(child: Text('Shared intent', style: AppText.title.copyWith(color: c.textPrimary))),
                  if (g?.sessionId != null) TextLink('By meditation', onPressed: () => Get.toNamed('/dedications/${g!.sessionId}', arguments: {'sessionId': g.sessionId})),
                ]),
                const SizedBox(height: 2),
                Text('Text only · 1 dedication per finished sit · real people', style: AppText.caption.copyWith(color: c.textTertiary)),
                const SizedBox(height: 8),
                if (ctrl.feed.isEmpty)
                  for (final d in ctrl.dedications.take(2)) DedicationLine(d)
                else
                  for (final it in ctrl.feed.take(8)) _FeedCard(key: Key('feed-${it.dedication.id}'), it: it, onHold: () => ctrl.hold(it)),
                const SizedBox(height: 10),
                Text('Dedicate your sit during the final reflection. It is shown here, with your first name.', style: AppText.caption.copyWith(color: c.textTertiary)),
                const SizedBox(height: 12),
                AppCard(outlined: true, child: Row(children: [Text('Gratitude feed', style: AppText.navTitle.copyWith(color: c.textPrimary)), const Spacer(), const AppBadge(BadgeKind.comingSoon)])),
              ]);
            }),
          )),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({super.key, required this.it, required this.onHold});
  final FeedItem it;
  final VoidCallback onHold;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = it.dedication;
    final who = it.isTeacher ? '${d.firstName} · Teacher' : d.firstName;
    final where = it.place ?? (d.country == null ? null : countryName(d.country));
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text([who, if (where != null) where].join(' · '), style: AppText.caption.copyWith(color: it.isTeacher ? c.emberText : c.textSecondary, fontWeight: FontWeight.w700))),
            Text(_ago(d.createdAt), style: AppText.micro.copyWith(color: c.textTertiary)),
          ]),
          const SizedBox(height: 6),
          Text('“${d.text}”', style: AppText.body.copyWith(color: c.textPrimary)),
          const SizedBox(height: 8),
          Semantics(
            button: true, label: 'Holding this with you, ${d.holdingCount}',
            child: GestureDetector(
              key: Key('hold-${d.id}'), onTap: onHold, behavior: HitTestBehavior.opaque,
              child: Row(children: [
                Icon(d.heldByMe ? Icons.front_hand : Icons.front_hand_outlined, size: 18, color: d.heldByMe ? c.emberText : c.textSecondary),
                const SizedBox(width: 6),
                Text('Holding this with you (${d.holdingCount})', style: AppText.caption.copyWith(color: d.heldByMe ? c.emberText : c.textSecondary, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 53 Group meditation lobby.
class LobbyPage extends StatelessWidget {
  const LobbyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(LobbyController());
    return AppScaffold(
      title: 'Scheduled sit', stitch: true,
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              if (ctrl.denied.value) {
                return EmptyState(title: 'Group meditation is for members', body: 'Join the Meditation of the Day together with everyone, at the same moment.', icon: Icons.groups_2_outlined, ctaLabel: 'See membership options', onCta: () => openPaywall('lock'));
              }
              final g = ctrl.group.value!;
              final startsAt = ctrl.startsAt ?? g.startsAt;
              final belts = ctrl.belts;
              final focus = g.focus;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 28), children: staggered([
                Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      PulseDot(color: c.success, size: 4),
                      const SizedBox(width: 6),
                      Flexible(child: Text('${groupNumber(ctrl.waiting)} PRACTITIONERS IN LOBBY${ctrl.countries > 0 ? ' · ${ctrl.countries} COUNTRIES' : ''}', key: const Key('lobby-count'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5))),
                    ]),
                  ),
                  if (ctrl.regions.isNotEmpty)
                    Padding(padding: const EdgeInsets.only(top: 8), child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.public_rounded, size: 14, color: c.success),
                      const SizedBox(width: 6),
                      Flexible(child: Text('${ctrl.regions.take(4).map((r) => r.region).join(', ')} gathering…', style: AppText.caption.copyWith(color: c.textSecondary))),
                    ])),
                ]),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Text(g.hourly ? 'HOURLY SYNCHRONISED SIT · ${ctrl.startLabel}' : 'SYNCHRONISED DAILY SIT · ${ctrl.startLabel}', textAlign: TextAlign.center, style: AppText.overline.copyWith(color: c.emberText, fontSize: 10.5)),
                    const SizedBox(height: 14),
                    _CountdownRing(target: startsAt, opens: g.lobbyOpensAt, now: ctrl.time.now),
                    const SizedBox(height: 16),
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle), child: Icon(Icons.graphic_eq_rounded, color: c.onEmber)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep.withValues(alpha: .6), borderRadius: BorderRadius.circular(10)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Icon(Icons.all_inclusive_rounded, size: 18, color: c.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${ctrl.doorsLine}The sit starts by itself, for everyone at the same moment. Joining late? You land where the group is.', key: const Key('lobby-doors'), style: AppText.caption.copyWith(color: c.textSecondary, height: 1.45))),
                      ]),
                    ),
                  ]),
                ),
                if (!belts.isEmpty || ctrl.regions.isNotEmpty)
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!belts.isEmpty) BeltCounts(key: const Key('lobby-belts'), belts: belts),
                      if (!belts.isEmpty && ctrl.regions.isNotEmpty) const SizedBox(height: 10),
                      for (final r in ctrl.regions) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(r.region, style: AppText.body.copyWith(color: c.textSecondary))), Text('${r.n}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))])),
                    ]),
                  ),
                AppCard(
                  key: const Key('focus-card'), padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.tealSoft.withValues(alpha: .18), borderRadius: BorderRadius.circular(4)), child: Text('TODAY’S FOCUS', style: AppText.overline.copyWith(color: c.success, fontSize: 10))),
                      const SizedBox(width: 8),
                      Text('· ${g.lengthMin} MIN', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
                    ]),
                    const SizedBox(height: 10),
                    Text(focus?.title ?? g.title ?? 'Meditation of the Day', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 19)),
                    const SizedBox(height: 2),
                    Text(focus?.summary.isNotEmpty == true ? focus!.summary : 'Meditation of the Day · Raphael', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    if ((focus?.quote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep.withValues(alpha: .6), borderRadius: BorderRadius.circular(10)),
                        child: Text('“${focus!.quote}”${focus.attribution.isEmpty ? '' : ' — ${focus.attribution}'}', style: AppText.bodySmall.copyWith(color: c.textBody, fontStyle: FontStyle.italic, height: 1.45)),
                      ),
                    ],
                  ]),
                ),
                AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('SIT READINESS CHECKLIST', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
                    const SizedBox(height: 10),
                    const _CheckRow(icon: Icons.headphones_rounded, title: 'Headphones, if you have them', body: 'Better for presence. Speakers work too.'),
                    const _CheckRow(icon: Icons.notifications_off_outlined, title: 'Do Not Disturb', body: 'Silence incoming notifications for the sit.'),
                    Row(children: [
                      const Expanded(child: _CheckRow(icon: Icons.alarm_on_rounded, title: 'Remind me', body: '10 minutes before it starts.')),
                      AppToggle(key: const Key('lobby-remind'), value: ctrl.reminder.value, onChanged: (_) => ctrl.toggleReminder(), label: 'Remind me 10 minutes before'),
                    ]),
                  ]),
                ),
                Column(children: [
                  PrimaryButton('You’re in the lobby', key: const Key('wait-lobby'), icon: Icons.lock_outline_rounded, onPressed: () {}),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: OutlineButton('Add to calendar', icon: Icons.event_outlined, onPressed: () => Add2Calendar.addEvent2Cal(Event(title: 'WeHum group sit', description: g.title ?? 'Meditation of the Day', startDate: startsAt.toLocal(), endDate: startsAt.toLocal().add(Duration(minutes: g.lengthMin)))))),
                    const SizedBox(width: 10),
                    Expanded(child: OutlineButton('Leave the lobby', key: const Key('leave-lobby'), onPressed: () {
                      ctrl.leave();
                      Get.back<void>();
                    })),
                  ]),
                ]),
              ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList()));
            }),
          )),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Icon(icon, color: c.textSecondary, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.bodyLarge.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600)),
          Text(body, style: AppText.caption.copyWith(color: c.textSecondary)),
        ])),
      ]),
    );
  }
}

/// Next synchronised sit (Stitch): countdown, who is waiting, the intention, a heads-up and a way into silence meanwhile.
class NextSitPage extends StatelessWidget {
  const NextSitPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(NextSitController());
    return AppScaffold(
      title: 'Upcoming sit', stitch: true,
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final g = ctrl.group.value!;
              final w = ctrl.waiting;
              final total = g.waiting > w.total ? g.waiting : w.total;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 28), children: staggered([
                Center(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PulseDot(color: c.success, size: 3.5),
                    const SizedBox(width: 6),
                    Flexible(child: Text(g.hourly ? 'HOURLY SYNCHRONISED SIT · STARTS AT ${ctrl.startLabel}' : 'SYNCHRONISED SIT · STARTS AT ${ctrl.startLabel}', key: const Key('nextsit-kicker'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10))),
                  ]),
                )),
                Column(children: [
                  CountdownText(target: g.startsAt, now: ctrl.time.now, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
                  const SizedBox(height: 8),
                  Text('The doors open ${g.doorsOpenSec} seconds before the start. The sit begins by itself.', textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                ]),
                AppCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(children: [
                    SizedBox(height: 150, child: _OrbitDots(count: total.clamp(0, 9))),
                    const SizedBox(height: 10),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Flexible(child: Text('${groupedInt(total)} ${total == 1 ? 'meditator' : 'meditators'} waiting', key: const Key('waiting-count'), textAlign: TextAlign.center, style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular))),
                    ]),
                    if (!w.isEmpty) ...[const SizedBox(height: 10), BeltCounts(belts: w)],
                  ]),
                ),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text('SYNCHRONISED PROTOCOL', style: AppText.overline.copyWith(color: c.emberText, fontSize: 10.5))),
                      Container(padding: const EdgeInsets.fromLTRB(4, 4, 10, 4), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle), child: Text('R', style: AppText.badge.copyWith(color: c.tealText))),
                        const SizedBox(width: 6),
                        Text('Raphael', style: AppText.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600)),
                      ])),
                    ]),
                    const SizedBox(height: 8),
                    Text(g.focus?.title ?? g.title ?? 'Meditation of the Day', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
                    const SizedBox(height: 2),
                    Text('with Raphael · ${g.lengthMin} min', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  ]),
                ),
                if (g.intentions.isNotEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text('INTENTION FOR THIS SIT', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))), Icon(Icons.track_changes_rounded, size: 18, color: c.textSecondary)]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final i in g.intentions)
                          GestureDetector(
                            key: Key('intent-$i'), onTap: () => ctrl.pick(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(color: ctrl.intention.value == i ? c.ember : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
                              child: Text(i, style: AppText.bodySmall.copyWith(color: ctrl.intention.value == i ? c.onEmber : c.textPrimary, fontWeight: FontWeight.w700)),
                            ),
                          ),
                      ]),
                    ]),
                  ),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(color: c.bgDeep, shape: BoxShape.circle), child: Icon(Icons.timer_outlined, size: 20, color: c.textSecondary)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Notify me before it starts', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15)),
                      Text('A single heads-up, ${g.reminderMin} minutes before', style: AppText.caption.copyWith(color: c.textSecondary)),
                    ])),
                    AppToggle(key: const Key('nextsit-notify'), value: ctrl.reminder.value, onChanged: (_) => ctrl.toggleReminder(), label: 'Notify me before the sit starts'),
                  ]),
                ),
                Column(children: [
                  PrimaryButton('Enter the lobby', key: const Key('nextsit-lobby'), onPressed: () => Get.toNamed(AppRoutes.groupMeditationLobby)),
                  const SizedBox(height: 10),
                  SecondaryButton('Sit in silence while you wait', key: const Key('nextsit-silence'), icon: Icons.air_rounded, onPressed: () => Get.toNamed(AppRoutes.silenceRoomSetup)),
                  const SizedBox(height: 10),
                  SecondaryButton('Add to calendar', icon: Icons.event_outlined, onPressed: () => Add2Calendar.addEvent2Cal(Event(title: 'WeHum group sit', description: g.title ?? 'Meditation of the Day', startDate: g.startsAt.toLocal(), endDate: g.startsAt.toLocal().add(Duration(minutes: g.lengthMin))))),
                ]),
                Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.sensors_rounded, size: 14, color: c.textSecondary), const SizedBox(width: 6), Flexible(child: Text('STRICT PRESENCE TELEMETRY', maxLines: 2, textAlign: TextAlign.center, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)))]),
                  const SizedBox(height: 4),
                  Text('No cameras. No talking. Just shared presence with everyone sitting at the same moment.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary)),
                ]),
              ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList()));
            }),
          )),
    );
  }
}

/// Soft orbit of dots around a centre: one dot per person waiting (up to nine), slowly turning.
class _OrbitDots extends StatefulWidget {
  const _OrbitDots({required this.count});
  final int count;
  @override
  State<_OrbitDots> createState() => _OrbitDotsState();
}

class _OrbitDotsState extends State<_OrbitDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(size: Size.infinite, painter: _OrbitPainter(widget.count, reduceMotion(context) ? 0 : _c.value, c.success, c.ember, c.border)),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.n, this.t, this.green, this.ember, this.line);
  final int n;
  final double t;
  final Color green, ember, line;
  @override
  void paint(Canvas canvas, Size s) {
    final ctr = s.center(Offset.zero), r = s.shortestSide / 2 - 8;
    canvas.drawCircle(ctr, r, Paint()..shader = RadialGradient(colors: [ember.withValues(alpha: .10), ember.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: ctr, radius: r)));
    canvas.drawCircle(ctr, r * .55, Paint()..style = PaintingStyle.stroke..strokeWidth = .8..color = line);
    canvas.drawCircle(ctr, r, Paint()..style = PaintingStyle.stroke..strokeWidth = .8..color = line.withValues(alpha: .6));
    canvas.drawCircle(ctr, 9, Paint()..color = ember);
    canvas.drawCircle(ctr, 3.5, Paint()..color = const Color(0xFF0B0D0E));
    for (var i = 0; i < n; i++) {
      final ring = i.isEven ? r : r * .55;
      final a = 2 * math.pi * (i / math.max(n, 1)) + t * 2 * math.pi * (i.isEven ? 1 : -1) * .25;
      canvas.drawCircle(ctr + Offset(math.cos(a), math.sin(a)) * ring, 4 + (i % 3) * .8, Paint()..color = green);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => old.t != t || old.n != n;
}

class _CountdownRing extends StatefulWidget {
  const _CountdownRing({required this.target, required this.opens, required this.now});
  final DateTime target, opens;
  final DateTime Function() now;
  @override
  State<_CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<_CountdownRing> {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (_, __) {
        final total = widget.target.difference(widget.opens).inSeconds.clamp(1, 1 << 30);
        final left = widget.target.difference(widget.now()).inSeconds.clamp(0, 1 << 30); // the text always shows the real time left
        final progress = (1 - left / total).clamp(0.0, 1.0); // the bar only fills once the lobby is open
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Text('STARTS IN', style: AppText.overline.copyWith(color: c.textSecondary, letterSpacing: 1.6)),
          const SizedBox(height: 4),
          Text(formatCountdown(Duration(seconds: left)), key: const Key('lobby-countdown'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 54, fontFeatures: AppText.tabular)),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: SizedBox(width: 200, child: LinearProgressIndicator(value: progress, minHeight: 4, backgroundColor: c.track, color: c.ember))),
        ]);
      },
    );
  }
}

