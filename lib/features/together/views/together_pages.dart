import 'dart:math' as math;
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
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
                HeroImageCard(image: m.cover?.url, blurHash: m.cover?.blurhash, height: 240, child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Spacer(),
                  const Overline('Meditation of the day'),
                  const SizedBox(height: 4),
                  Text(m.title, style: AppText.heroTitle.copyWith(color: Colors.white)),
                  Text('with ${m.teacher ?? 'Raphael'}${m.theme == null ? '' : ' · ${m.theme}'}', style: AppText.bodyLarge.copyWith(color: Colors.white70)),
                ])),
                const SizedBox(height: 12),
                Text('${groupNumber(ctrl.practiced)} people practiced this meditation today', key: const Key('practiced'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 14),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (ctrl.liveText != null) LivePill(text: ctrl.liveText!, quiet: ctrl.live.paused || (ctrl.live.agg.value?.quiet ?? false)),
                    const SizedBox(height: 10),
                    Text('Start now and meditate with other souls around the world…', style: AppText.body.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 12),
                    if (m.lengths.isNotEmpty) SegmentedControl<int>(options: m.lengths, value: ctrl.length.value, onChanged: (v) => ctrl.length.value = v, labelOf: (v) => '$v min'),
                    const SizedBox(height: 12),
                    PrimaryButton('Meditate now · ${ctrl.length.value} min', key: const Key('room-meditate'), onPressed: ctrl.meditateNow),
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

/// 25 World map & World Vibration.
class WorldPage extends StatelessWidget {
  const WorldPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(WorldController());
    return AppScaffold(
      title: 'Meditating around the world', action: const Padding(padding: EdgeInsets.only(right: 4), child: SosPill()),
      body: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
            Text(ctrl.kicker, key: const Key('world-kicker'), style: AppText.overline.copyWith(color: ctrl.paused || ctrl.quiet ? c.textTertiary : c.success)),
            const SizedBox(height: 4),
            Text(ctrl.big, key: const Key('world-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
            Text(ctrl.sub, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(height: 16),
            AppCard(padding: const EdgeInsets.all(12), child: WorldDotMap(hot: ctrl.paused ? const {} : ctrl.hot, height: 190)),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: Text('WORLD VIBRATION', style: AppText.overline.copyWith(color: c.textTertiary))), Text('${ctrl.vibration} · ${ctrl.vibrationWord}', key: const Key('vibration'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))]),
            VibrationBar(value: ctrl.vibration, onInfo: () {
              ctrl.openInfo();
              showAppSheet<void>(context, title: 'World Vibration', builder: (_) => Text('The vibration rises when more people meditate on the same day and when group meditations gather many people at once. It moves toward green as the world meditates more.', style: AppText.body.copyWith(color: c.textBody)));
            }),
            const SizedBox(height: 8),
            for (final e in (ctrl.paused ? const <({String country, int n})>[] : ctrl.agg?.top ?? const <({String country, int n})>[]).take(8))
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Text(countryName(e.country), style: AppText.bodyLarge.copyWith(color: c.textPrimary))), Text('${e.n}', style: AppText.navTitle.copyWith(color: c.textSecondary))])),
            const SizedBox(height: 16),
            PrimaryButton('Meditate with them', onPressed: () => Get.toNamed(AppRoutes.motdRoom)),
            const SizedBox(height: 12),
            Text('Country and city level only, from your store region. We never ask for GPS or show who is meditating.', style: AppText.caption.copyWith(color: c.textTertiary)),
          ])),
    );
  }
}

/// 52 Together.
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
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text('Together', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Group meditations are the Meditation of the Day, started by everyone at the same moment.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 14),
                if (ctrl.liveText != null) Align(alignment: Alignment.centerLeft, child: LivePill(key: const Key('together-live'), text: '${ctrl.liveText} · see where', quiet: ctrl.quiet || ctrl.live.paused, onTap: () => Get.toNamed(AppRoutes.worldMapWorldVibration))),
                const SizedBox(height: 14),
                if (g != null && g.state != GroupPhase.ended)
                  AppCard(
                    key: const Key('next-group'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Overline('Next group meditation · ${ctrl.groupTime} your time', color: c.tealText),
                      const SizedBox(height: 6),
                      CountdownText(target: g.startsAt, now: ctrl.time.now, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 36)),
                      Text('${g.title ?? 'Meditation of the Day'} · Meditation of the Day', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                      const SizedBox(height: 8),
                      Text('${g.waiting} already in the lobby', style: AppText.bodySmall.copyWith(color: c.textBody)),
                      const SizedBox(height: 12),
                      PrimaryButton('Go to the lobby', key: const Key('go-lobby'), onPressed: () => Get.toNamed(AppRoutes.groupMeditationLobby)),
                      Center(child: TextLink('or begin now on your own', onPressed: () => Get.toNamed(AppRoutes.motdRoom), color: c.textSecondary)),
                    ]),
                  ),
                const SizedBox(height: 16),
                Text('WORLD VIBRATION', style: AppText.overline.copyWith(color: c.textTertiary)),
                Row(children: [Expanded(child: VibrationBar(value: ctrl.vibration)), Text(ctrl.vibrationWord, style: AppText.bodySmall.copyWith(color: c.textSecondary))]),
                const SizedBox(height: 16),
                Row(children: [Text('Today’s dedications', style: AppText.title.copyWith(color: c.textPrimary)), const Spacer(), if (g?.sessionId != null) TextLink('See all', onPressed: () => Get.toNamed('/dedications/${g!.sessionId}', arguments: {'sessionId': g.sessionId}))]),
                for (final d in ctrl.dedications.take(2)) DedicationLine(d),
                const SizedBox(height: 12),
                AppCard(outlined: true, child: Row(children: [Text('Gratitude feed', style: AppText.navTitle.copyWith(color: c.textPrimary)), const Spacer(), const AppBadge(BadgeKind.comingSoon)])),
              ]);
            }),
          )),
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
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text('Group meditation · ${ctrl.startLabel}', style: AppText.title.copyWith(color: c.textPrimary)),
                const SizedBox(height: 16),
                Center(child: _CountdownRing(target: startsAt, opens: g.lobbyOpensAt, now: ctrl.time.now)),
                const SizedBox(height: 8),
                Center(child: Text('until it starts', style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
                const SizedBox(height: 8),
                Text('Doors open 1 minute before. Today’s Meditation of the Day starts by itself, for everyone at the same moment.', textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${groupNumber(ctrl.waiting)} in the lobby${ctrl.countries > 0 ? ' · ${ctrl.countries} countries' : ''}', key: const Key('lobby-count'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 8),
                    for (final r in ctrl.regions) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [Expanded(child: Text(r.region, style: AppText.body.copyWith(color: c.textSecondary))), Text('${r.n}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))])),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(child: Row(children: [
                  const IconTile(Icons.self_improvement_rounded),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(g.title ?? 'Meditation of the Day', style: AppText.navTitle.copyWith(color: c.textPrimary)), Text('Meditation of the Day · Raphael · ${g.lengthMin} min', style: AppText.bodySmall.copyWith(color: c.textSecondary))])),
                ])),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Text('Remind me 10 min before', style: AppText.bodyLarge.copyWith(color: c.textPrimary))),
                  AppToggle(value: ctrl.reminder.value, onChanged: (_) => ctrl.toggleReminder(), label: 'Remind me 10 minutes before'),
                ]),
                const SizedBox(height: 8),
                PrimaryButton('Wait in the lobby', key: const Key('wait-lobby'), onPressed: () {}),
                const SizedBox(height: 8),
                OutlineButton('Add to calendar', onPressed: () => Add2Calendar.addEvent2Cal(Event(title: 'WeHum group meditation', description: g.title ?? 'Meditation of the Day', startDate: startsAt.toLocal(), endDate: startsAt.toLocal().add(Duration(minutes: g.lengthMin)))), icon: Icons.event_outlined),
                const SizedBox(height: 12),
                Center(child: Text('You can leave and come back. Late joiners start where the group is.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary))),
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
