import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
import '../../../core/data/models/today.dart';
import '../../../core/services/inbox_service.dart';
import '../../../core/services/onboarding_store.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/countdown_text.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../player/player_args.dart';
import '../controllers/today_controller.dart';
import 'today_widgets.dart';

/// Tab header with the avatar initial and the live unread count of the bell (`inbox:new`).
Widget tabHeader() => Obx(() {
      final name = Get.find<OnboardingStore>().name;
      return TabHeader(initials: name.isEmpty ? '' : name.substring(0, 1).toUpperCase(), unread: Get.find<InboxService>().unread.value);
    });

/// 22 Today (member).
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(TodayController());
    return Obx(() => AppScaffold(
          header: tabHeader(),
          bottom: const AppBottomNav(current: AppTab.today),
          banner: ctrl.offline.value ? const OfflineBanner() : null,
          body: StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => RefreshIndicator(
              onRefresh: ctrl.refreshAll,
              child: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text(DateFormatX.today(), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 2),
                Text(greetingFor(DateTime.now(), ctrl.name), key: const Key('greeting'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 16),
                if (ctrl.data.value?.motd != null) _MotdHero(ctrl: ctrl) else const _NoMotd(),
                const SizedBox(height: 16),
                _ProgramCard(card: ctrl.data.value?.program),
                const SizedBox(height: 12),
                SilenceRoomRow(locked: false, onTap: () => Get.toNamed(AppRoutes.silenceRoomSetup)),
                const SizedBox(height: 12),
                _ProgressCard(p: ctrl.data.value?.progress ?? const WeekProgress()),
                if (ctrl.data.value?.dailyMessage != null) ...[const SizedBox(height: 12), _DailyMessageLine(m: ctrl.data.value!.dailyMessage!)],
              ])),
            ),
          ),
        ));
  }
}

class DateFormatX {
  static String today() {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final n = DateTime.now();
    return '${days[n.weekday - 1]}, ${months[n.month - 1]} ${n.day}';
  }
}

class _NoMotd extends StatelessWidget {
  const _NoMotd();
  @override
  Widget build(BuildContext context) => const EmptyState(title: 'Today’s meditation is on its way', body: 'Check back in a moment, or explore the library.', icon: Icons.wb_twilight_rounded);
}

class _MotdHero extends StatelessWidget {
  const _MotdHero({required this.ctrl});
  final TodayController ctrl;
  @override
  Widget build(BuildContext context) => Obx(_hero);

  Widget _hero() {
    final m = ctrl.data.value!.motd!;
    final g = ctrl.group;
    return HeroImageCard(
      key: const Key('motd-hero'), image: m.cover?.url, blurHash: m.cover?.blurhash, onTap: ctrl.openRoom,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (ctrl.liveText != null) Align(alignment: Alignment.centerLeft, child: LivePill(text: ctrl.liveText!, quiet: ctrl.liveQuiet || ctrl.live.paused)),
        const SizedBox(height: 150),
        const Overline('Meditation of the day'),
        const SizedBox(height: 6),
        Text(m.title, style: AppText.heroTitle.copyWith(color: Colors.white)),
        Text('with ${m.teacher ?? 'Raphael'}', style: AppText.bodyLarge.copyWith(color: Colors.white70)),
        const SizedBox(height: 8),
        Text('${groupNumber(ctrl.practiced)} people practiced this meditation today', key: const Key('practiced'), style: AppText.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        if (m.lengths.isNotEmpty) SegmentedControl<int>(options: m.lengths, value: ctrl.length.value, onChanged: (v) => ctrl.length.value = v, labelOf: (v) => '$v min'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: PrimaryButton('Meditate now', key: const Key('meditate-now'), sub: '${ctrl.length.value} min · on your own', onPressed: ctrl.meditateNow)),
          if (g != null && ctrl.groupOpen) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlineButton(
                'Wait for the group', key: const Key('wait-group'), height: Sizes.primaryButton, onPressed: ctrl.waitForGroup,
                sub: g.state == GroupPhase.live ? '${ctrl.groupTime} · started' : '${ctrl.groupTime} · in ${formatCountdown(ctrl.untilGroup)}'),
            ),
          ],
        ]),
      ]),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.card});
  final ProgramCard? card;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (card == null) {
      return AppCard(key: const Key('program-start'), onTap: () => Get.toNamed(AppRoutes.allPrograms), child: const ListRow(title: 'Start a program', subtitle: 'Multi-day practices, one meditation a day', leading: IconTile(Icons.route_outlined)));
    }
    return AppCard(
      key: const Key('program-card'), onTap: () => Get.toNamed(AppRoutes.programDetail.replaceFirst(':id', card!.id), arguments: {'id': card!.id}),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Overline('Your program · day ${card!.day} of ${card!.days}'), const Spacer()]),
        const SizedBox(height: 6),
        Text(card!.title, style: AppText.navTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 10),
        AppProgressBar(card!.day / card!.days),
      ]),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.p});
  final WeekProgress p;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      key: const Key('progress-card'), onTap: () => Get.toNamed(AppRoutes.yourProgress),
      child: Row(children: [
        Text('${p.minutes}', style: AppText.display.copyWith(color: c.emberText, fontSize: 36)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('minutes this week', style: AppText.navTitle.copyWith(color: c.textPrimary)),
            Text('${p.meditations} meditations · see your progress', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: c.textSecondary),
      ]),
    );
  }
}

class _DailyMessageLine extends StatelessWidget {
  const _DailyMessageLine({required this.m});
  final DailyMessageRef m;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      key: const Key('daily-line'), outlined: true, onTap: () => Get.toNamed('/message/${m.date}', arguments: {'date': m.date}), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Text('DAILY\nMESSAGE', style: AppText.overline.copyWith(color: c.tealText)),
        const SizedBox(width: 14),
        Expanded(child: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))),
      ]),
    );
  }
}

/// 24 Today (free): the premium MOTD is locked on top, then "Free for you", then the locked Silence Room.
class TodayFreePage extends StatelessWidget {
  const TodayFreePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(TodayController());
    return Obx(() {
      final d = ctrl.data.value;
      final catalog = Get.find<CatalogService>().catalog.value;
      final free = catalog?.sessions.where((s) => !s.isPremium).toList() ?? const <SessionSummary>[];
      final pick = d?.freePick;
      return AppScaffold(
        header: tabHeader(), bottom: const AppBottomNav(current: AppTab.today), banner: ctrl.offline.value ? const OfflineBanner() : null,
        body: StateSwitcher(
          state: ctrl.state.value, onRetry: ctrl.load,
          content: () => Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
            Text(DateFormatX.today(), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            Text(greetingFor(DateTime.now(), ctrl.name), key: const Key('greeting'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 16),
            if (d?.motd != null)
              HeroImageCard(
                key: const Key('locked-motd'), image: d!.motd!.cover?.url, height: 300, onTap: () => openPaywall('today_free'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  const Align(alignment: Alignment.topRight, child: AppBadge(BadgeKind.premium)),
                  const SizedBox(height: 70),
                  const Overline('Meditation of the day'),
                  const SizedBox(height: 6),
                  Text(d.motd!.title, style: AppText.heroTitle.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('10, 30 or 45 min${ctrl.liveText == null || ctrl.live.paused ? '' : ' · ${ctrl.liveText}'}', style: AppText.bodySmall.copyWith(color: Colors.white70)),
                  const SizedBox(height: 14),
                  PrimaryButton('Try 7 days free', key: const Key('try-free'), onPressed: () => openPaywall('today_free')),
                ]),
              ),
            if (pick != null || free.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(children: [Text('Free for you', style: AppText.title.copyWith(color: c.textPrimary)), const Spacer(), TextLink('See all', onPressed: () => Get.toNamed(AppRoutes.library))]),
              const SizedBox(height: 4),
              Text('Your free meditations from Raphael’s online library. Find them all in Library under “Free for you”.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              if (pick != null)
                HeroImageCard(
                  key: const Key('free-pick'), image: catalog?.session(pick.sessionId)?.cover?.url, height: 190,
                  onTap: () => Get.toNamed(AppRoutes.freePlayer, arguments: PlayerArgs(kind: 'free', title: pick.title, subtitle: 'Raphael', sessionId: pick.sessionId, youtubeId: pick.youtubeId, coverUrl: catalog?.session(pick.sessionId)?.cover?.url, durationSec: pick.durationSec)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                    const SizedBox(height: 60),
                    const AppBadge(BadgeKind.freeForYou),
                    const SizedBox(height: 6),
                    Text(pick.title, style: AppText.title.copyWith(color: Colors.white)),
                  ]),
                ),
              for (final s in free.where((s) => s.id != pick?.sessionId).take(4))
                FreeItemRow(s: s, onTap: () => Get.toNamed(AppRoutes.freePlayer, arguments: PlayerArgs(kind: 'free', title: s.title, subtitle: 'Raphael', sessionId: s.id, youtubeId: s.youtubeId, coverUrl: s.cover?.url, durationSec: s.durationSec))),
            ],
            const SizedBox(height: 16),
            SilenceRoomRow(locked: true, onTap: () => openPaywall('lock')),
          ])),
        ),
      );
    });
  }
}
