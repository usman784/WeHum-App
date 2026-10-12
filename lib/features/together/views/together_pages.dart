import 'dart:math' as math;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
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
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
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
              ]);
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
      title: 'Global presence', action: const Padding(padding: EdgeInsets.only(right: 4), child: SosPill()),
      body: Obx(() {
        final trend = ctrl.trendPct;
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
          Text(ctrl.kicker, key: const Key('world-kicker'), style: AppText.overline.copyWith(color: ctrl.paused || ctrl.quiet ? c.textTertiary : c.success)),
          const SizedBox(height: 4),
          Text(ctrl.big, key: const Key('world-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
          Text(ctrl.sub, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 16),
          AppCard(padding: const EdgeInsets.all(12), child: WorldDotMap(hot: ctrl.paused ? const {} : ctrl.hot, height: 190)),
          const SizedBox(height: 16),
          AppCard(
            key: const Key('gauge-card'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('WORLD VIBRATION', style: AppText.overline.copyWith(color: c.textSecondary))),
                if (trend != null) InfoChip(key: const Key('trend'), text: '${trend >= 0 ? '+' : ''}$trend% today', icon: trend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded, accent: trend >= 0),
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${ctrl.vibration}', key: const Key('vibration-num'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 44)),
                Padding(padding: const EdgeInsets.only(bottom: 8, left: 4), child: Text('/ 100 · ${ctrl.vibrationWord}', key: const Key('vibration'), style: AppText.navTitle.copyWith(color: c.textSecondary, fontSize: 15))),
              ]),
              const SizedBox(height: 4),
              VibrationBar(value: ctrl.vibration, onInfo: () {
                ctrl.openInfo();
                showAppSheet<void>(context, title: 'World Vibration', builder: (_) => Text('The vibration rises when more people meditate on the same day and when group meditations gather many people at once. It moves toward green as the world meditates more.', style: AppText.body.copyWith(color: c.textBody)));
              }),
              if (ctrl.minutesToday != null && ctrl.minutesToday! > 0) ...[
                const SizedBox(height: 10),
                Text('${groupedInt(ctrl.minutesToday!)} minutes sat so far today', key: const Key('minutes-today'), style: AppText.bodySmall.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
              ],
            ]),
          ),
          if (ctrl.regions.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('Active regional belts'),
            const SizedBox(height: 6),
            for (final r in ctrl.regions) _BeltRow(key: Key('belt-${r.key}'), b: r, name: r.name),
          ],
          if (ctrl.countryRows.isNotEmpty) ...[
            const SizedBox(height: 16),
            const SectionLabel('Where people are sitting'),
            const SizedBox(height: 6),
            for (final b in ctrl.countryRows.take(8)) _BeltRow(key: Key('country-${b.key}'), b: b, name: b.name),
          ],
          const SizedBox(height: 16),
          AppCard(
            outlined: true,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_outlined, color: c.tealText, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('Country-level numbers only. We never access, store or show your GPS, your IP trail or who is sitting. Counts come from the server, not from guesses.', style: AppText.caption.copyWith(color: c.textSecondary))),
            ]),
          ),
          const SizedBox(height: 16),
          PrimaryButton('Join the global sit', onPressed: () => Get.toNamed(AppRoutes.motdRoom)),
        ]);
      }),
    );
  }
}

class _BeltRow extends StatelessWidget {
  const _BeltRow({super.key, required this.b, required this.name});
  final WorldBelt b;
  final String name;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
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
      title: 'Group meditation',
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
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Row(children: [
                  Icon(Icons.public_rounded, size: 18, color: c.success),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${groupNumber(ctrl.waiting)} in the lobby${ctrl.countries > 0 ? ' · ${ctrl.countries} countries' : ''}', key: const Key('lobby-count'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular))),
                ]),
                if (ctrl.regions.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2, left: 26), child: Text('${ctrl.regions.take(4).map((r) => r.region).join(', ')} gathering…', style: AppText.caption.copyWith(color: c.textSecondary))),
                const SizedBox(height: 16),
                Text(g.hourly ? 'HOURLY SYNCHRONISED SIT · ${ctrl.startLabel}' : 'SYNCHRONISED DAILY SIT · ${ctrl.startLabel}', style: AppText.overline.copyWith(color: c.textSecondary)),
                const SizedBox(height: 8),
                Center(child: _CountdownRing(target: startsAt, opens: g.lobbyOpensAt, now: ctrl.time.now)),
                const SizedBox(height: 8),
                Center(child: Text('until it starts', style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
                const SizedBox(height: 8),
                Text('${ctrl.doorsLine}The sit starts by itself, for everyone at the same moment. Joining late? You land where the group is.', key: const Key('lobby-doors'), textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                if (!belts.isEmpty || ctrl.regions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!belts.isEmpty) BeltCounts(key: const Key('lobby-belts'), belts: belts),
                      if (!belts.isEmpty && ctrl.regions.isNotEmpty) const SizedBox(height: 10),
                      for (final r in ctrl.regions) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(r.region, style: AppText.body.copyWith(color: c.textSecondary))), Text('${r.n}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))])),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                AppCard(
                  key: const Key('focus-card'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('TODAY’S FOCUS · ${g.lengthMin} MIN', style: AppText.overline.copyWith(color: c.emberText)),
                    const SizedBox(height: 6),
                    Text(focus?.title ?? g.title ?? 'Meditation of the Day', style: AppText.title.copyWith(color: c.textPrimary)),
                    Text(focus?.summary.isNotEmpty == true ? focus!.summary : 'Meditation of the Day · Raphael', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    if ((focus?.quote ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('“${focus!.quote}”${focus.attribution.isEmpty ? '' : ' — ${focus.attribution}'}', style: AppText.body.copyWith(color: c.textBody, fontStyle: FontStyle.italic)),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),
                const SectionLabel('Before you sit'),
                const SizedBox(height: 6),
                const _CheckRow(icon: Icons.headphones_rounded, title: 'Headphones, if you have them', body: 'Better for presence. Speakers work too.'),
                const _CheckRow(icon: Icons.notifications_off_outlined, title: 'Do Not Disturb', body: 'Silence incoming notifications for the sit.'),
                Row(children: [
                  const Expanded(child: _CheckRow(icon: Icons.alarm_on_rounded, title: 'Remind me', body: '10 minutes before it starts.')),
                  AppToggle(key: const Key('lobby-remind'), value: ctrl.reminder.value, onChanged: (_) => ctrl.toggleReminder(), label: 'Remind me 10 minutes before'),
                ]),
                const SizedBox(height: 8),
                PrimaryButton('You’re in the lobby', key: const Key('wait-lobby'), onPressed: () {}),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlineButton('Add to calendar', icon: Icons.event_outlined, onPressed: () => Add2Calendar.addEvent2Cal(Event(title: 'WeHum group sit', description: g.title ?? 'Meditation of the Day', startDate: startsAt.toLocal(), endDate: startsAt.toLocal().add(Duration(minutes: g.lengthMin)))))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlineButton('Leave the lobby', key: const Key('leave-lobby'), onPressed: () {
                    ctrl.leave();
                    Get.back<void>();
                  })),
                ]),
              ]);
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
      title: 'Next sit',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final g = ctrl.group.value!;
              final w = ctrl.waiting;
              final total = g.waiting > w.total ? g.waiting : w.total;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text(g.hourly ? 'HOURLY SYNCHRONISED SIT · STARTS AT ${ctrl.startLabel}' : 'SYNCHRONISED SIT · STARTS AT ${ctrl.startLabel}', key: const Key('nextsit-kicker'), style: AppText.overline.copyWith(color: c.emberText)),
                const SizedBox(height: 10),
                Center(child: CountdownText(target: g.startsAt, now: ctrl.time.now, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 64))),
                const SizedBox(height: 6),
                Text('The doors open ${g.doorsOpenSec} seconds before the start. The sit begins by itself.', textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${groupedInt(total)} ${total == 1 ? 'meditator' : 'meditators'} waiting', key: const Key('waiting-count'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
                    if (!w.isEmpty) ...[const SizedBox(height: 12), BeltCounts(belts: w)],
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Row(children: [
                    const IconTile(Icons.self_improvement_rounded),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.focus?.title ?? g.title ?? 'Meditation of the Day', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                      Text('with Raphael · ${g.lengthMin} min', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    ])),
                  ]),
                ),
                if (g.intentions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionLabel('Intention for this sit'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final i in g.intentions)
                      GestureDetector(
                        key: Key('intent-$i'), onTap: () => ctrl.pick(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: ctrl.intention.value == i ? c.emberTint : c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: ctrl.intention.value == i ? c.ember : c.border)),
                          child: Text(i, style: AppText.bodySmall.copyWith(color: ctrl.intention.value == i ? c.emberText : c.textPrimary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                  ]),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Notify me before it starts', style: AppText.bodyLarge.copyWith(color: c.textPrimary)),
                    Text('A single heads-up, ${g.reminderMin} minutes before', style: AppText.caption.copyWith(color: c.textSecondary)),
                  ])),
                  AppToggle(key: const Key('nextsit-notify'), value: ctrl.reminder.value, onChanged: (_) => ctrl.toggleReminder(), label: 'Notify me before the sit starts'),
                ]),
                const SizedBox(height: 14),
                PrimaryButton('Enter the lobby', key: const Key('nextsit-lobby'), onPressed: () => Get.toNamed(AppRoutes.groupMeditationLobby)),
                const SizedBox(height: 8),
                OutlineButton('Sit in silence while you wait', key: const Key('nextsit-silence'), onPressed: () => Get.toNamed(AppRoutes.silenceRoomSetup)),
                const SizedBox(height: 8),
                OutlineButton('Add to calendar', icon: Icons.event_outlined, onPressed: () => Add2Calendar.addEvent2Cal(Event(title: 'WeHum group sit', description: g.title ?? 'Meditation of the Day', startDate: g.startsAt.toLocal(), endDate: g.startsAt.toLocal().add(Duration(minutes: g.lengthMin))))),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.sensors_rounded, size: 18, color: c.textTertiary),
                  const SizedBox(width: 10),
                  Expanded(child: Text('No cameras. No talking. Just shared presence with everyone sitting at the same moment.', style: AppText.caption.copyWith(color: c.textTertiary))),
                ]),
              ]);
            }),
          )),
    );
  }
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
    return SizedBox(
      width: 220, height: 220,
      child: StreamBuilder<int>(
        stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
        builder: (_, __) {
          final total = widget.target.difference(widget.opens).inSeconds.clamp(1, 1 << 30);
          final left = widget.target.difference(widget.now()).inSeconds.clamp(0, 1 << 30); // the text always shows the real time left
          final progress = (1 - left / total).clamp(0.0, 1.0); // the ring only fills once the lobby is open
          return CustomPaint(
            painter: _RingPainter(progress, c.ember, c.track),
            child: Center(child: Text(formatCountdown(Duration(seconds: left)), key: const Key('lobby-countdown'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 44))),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.color, this.track);
  final double progress;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 8);
    canvas.drawArc(r, 0, math.pi * 2, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = track);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * progress, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..strokeCap = StrokeCap.round..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.progress != progress;
}
