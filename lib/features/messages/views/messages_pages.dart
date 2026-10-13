import 'package:flutter/material.dart';
import '../../../core/widgets/sheets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../../core/widgets/motion.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/services/inbox_service.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/painters.dart' show Overline;
import '../../../core/widgets/states.dart';
import '../../../core/widgets/stitch.dart';
import '../../../core/widgets/surfaces.dart';
import '../../today/controllers/today_controller.dart' show groupNumber;
import '../../today/views/today_widgets.dart';
import '../controllers/messages_controllers.dart';

/// 26 Daily message with the interactive transcript (Stitch).
class _ModePill extends StatelessWidget {
  const _ModePill({super.key, required this.icon, required this.label, required this.on, required this.onTap});
  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), decoration: BoxDecoration(color: on ? c.ember : c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: on ? c.onEmber : c.textSecondary), const SizedBox(width: 6), Text(label.toUpperCase(), style: AppText.overline.copyWith(color: on ? c.onEmber : c.textSecondary, fontSize: 10))]),
      ),
    );
  }
}

class DailyMessagePage extends StatelessWidget {
  const DailyMessagePage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? const {};
    final date = (args['date'] ?? Get.parameters['date'] ?? '') as String;
    final ctrl = Get.put(DailyMessageController(date), tag: date);
    final c = context.colors;
    String mmss(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return AppScaffold(
      title: 'Daily message', stitch: true,
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            empty: const EmptyState(title: 'No message yet', body: 'Raphael’s next message will appear here.', icon: Icons.mail_outline_rounded),
            content: () => Obx(() {
              if (ctrl.locked.value) {
                return EmptyState(title: 'This daily message is part of membership', body: 'A short note from Raphael, every day. Some past messages are free.', icon: Icons.lock_outline_rounded, ctaLabel: 'See membership options', onCta: () => openPaywall('lock'));
              }
              final m = ctrl.message.value!;
              final cur = ctrl.currentLine;
              final total = ctrl.duration.value.inSeconds > 0 ? ctrl.duration.value : Duration(seconds: m.durationSec ?? 0);
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: staggered([
                if (ctrl.hasVideoMode || ctrl.hasAudioMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(children: [
                      if (ctrl.hasAudioMode) _ModePill(key: const Key('mode-audio'), icon: Icons.graphic_eq_rounded, label: 'Audio mode', on: !ctrl.videoMode.value, onTap: () => ctrl.videoMode.value = false),
                      if (ctrl.hasVideoMode) ...[const SizedBox(width: 8), _ModePill(key: const Key('mode-video'), icon: Icons.videocam_outlined, label: 'Video mode', on: ctrl.videoMode.value, onTap: () => ctrl.videoMode.value = true)],
                      const SizedBox(width: 8),
                      Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(m.isFree ? Icons.lock_open_rounded : Icons.workspace_premium_outlined, size: 14, color: c.emberText), const SizedBox(width: 5), Flexible(child: Text(m.isFree ? 'FREE' : 'PREMIUM', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)))]))),
                    ]),
                  ),
                Row(children: [
                  Expanded(child: Text(ctrl.dateLine, key: const Key('dm-date'), style: AppText.bodySmall.copyWith(color: c.textSecondary))),
                  if (m.isFree) const AppBadge(BadgeKind.freeForYou),
                ]),
                if (m.themeTag != null) Padding(padding: const EdgeInsets.only(top: 8), child: Overline(m.themeTag!, color: c.tealText)),
                const SizedBox(height: 6),
                Text(m.title, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if (m.imageUrl != null) Padding(padding: const EdgeInsets.only(top: 14), child: ThumbImage(m.imageUrl, height: 180, radius: Radii.card, width: double.infinity)),
                if (m.hasMedia && m.type != 'text') ...[
                  const SizedBox(height: 16),
                  AppCard(
                    key: const Key('dm-player'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        GestureDetector(
                          key: const Key('dm-play'), onTap: ctrl.toggle,
                          child: Container(width: 56, height: 56, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle), child: ctrl.audioLoading.value ? Padding(padding: const EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 3, color: c.onEmber)) : Icon(ctrl.playing.value ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onEmber, size: 32)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(ctrl.videoMode.value ? 'Watch' : 'Listen', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                          Text('${m.durationSec == null ? '' : '${(m.durationSec! / 60).ceil()} min · '}${m.hasVideo || m.type == 'video' ? 'audio & video' : 'audio'}', style: AppText.caption.copyWith(color: c.textSecondary)),
                        ])),
                        if (ctrl.playing.value || ctrl.position.value > Duration.zero) ...[
                          Semantics(button: true, label: 'Back 15 seconds', child: IconButton(onPressed: () => ctrl.skip(-15), icon: const Icon(Icons.replay_10_rounded))),
                          Semantics(button: true, label: 'Forward 15 seconds', child: IconButton(onPressed: () => ctrl.skip(15), icon: const Icon(Icons.forward_10_rounded))),
                        ],
                      ]),
                      if (total > Duration.zero) ...[
                        const SizedBox(height: 12),
                        WaveProgress(progress: ctrl.position.value.inMilliseconds / total.inMilliseconds, seed: m.date, playedColor: c.ember, restColor: c.track, onSeek: (f) => ctrl.seekTo((total.inSeconds * f).round())),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text(mmss(ctrl.position.value), key: const Key('dm-pos'), style: AppText.micro.copyWith(color: c.textTertiary, fontFeatures: AppText.tabular)),
                          const Spacer(),
                          Text('-${mmss(total - ctrl.position.value < Duration.zero ? Duration.zero : total - ctrl.position.value)}', style: AppText.micro.copyWith(color: c.textTertiary, fontFeatures: AppText.tabular)),
                        ]),
                      ],
                      if (ctrl.audioError.value) Padding(padding: const EdgeInsets.only(top: 8), child: Text('This message couldn’t load. Check your connection and try again.', style: AppText.caption.copyWith(color: c.dangerText))),
                    ]),
                  ),
                  if (m.listenersToday > 0) Padding(padding: const EdgeInsets.only(top: 12), child: AppCard(padding: const EdgeInsets.all(14), child: Row(children: [PulseDot(color: c.success, size: 4), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${groupNumber(m.listenersToday)} listened today', key: const Key('dm-listeners'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15, fontFeatures: AppText.tabular)), Text('practitioners completed today’s message', style: AppText.caption.copyWith(color: c.textSecondary))]))]))),
                ],
                if (m.text != null && m.text!.isNotEmpty) ...[const SizedBox(height: 16), Text(m.text!, style: AppText.bodyLarge.copyWith(color: c.textBody, height: 1.6))],
                if (m.transcript.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  Row(children: [
                    Icon(Icons.subject_rounded, size: 18, color: c.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('INTERACTIVE TRANSCRIPT', style: AppText.overline.copyWith(color: c.textSecondary))),
                  ]),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('transcript-search'), onChanged: (v) => ctrl.search.value = v, style: AppText.bodySmall.copyWith(color: c.textPrimary),
                    decoration: InputDecoration(isDense: true, hintText: 'Search the transcript', prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide(color: c.border))),
                  ),
                  const SizedBox(height: 8),
                  for (final i in ctrl.visibleLines)
                    InkWell(
                      key: Key('line-$i'), onTap: () => ctrl.seekTo(m.transcript[i].t),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: i == cur ? c.emberTint : Colors.transparent, borderRadius: BorderRadius.circular(Radii.input), border: Border.all(color: i == cur ? c.ember : c.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Text('${(m.transcript[i].t ~/ 60).toString().padLeft(2, '0')}:${(m.transcript[i].t % 60).toString().padLeft(2, '0')}', style: AppText.micro.copyWith(color: i == cur ? c.emberText : c.textTertiary, fontFeatures: AppText.tabular, fontWeight: FontWeight.w700)),
                            if (m.transcript[i].section != null) ...[const SizedBox(width: 8), Text(m.transcript[i].section!.toUpperCase(), style: AppText.badge.copyWith(color: c.tealText))],
                          ]),
                          const SizedBox(height: 4),
                          Text(m.transcript[i].text, style: AppText.body.copyWith(color: i == cur ? c.textPrimary : c.textBody)),
                        ]),
                      ),
                    ),
                ],
                const SizedBox(height: 16),
                PrimaryButton('Sit with today’s insight', key: const Key('dm-sit'), icon: Icons.self_improvement_rounded, onPressed: () => Get.toNamed(AppRoutes.motdRoom)),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: SecondaryButton(m.saved ? 'Saved to notes' : 'Save to notes', key: const Key('dm-save'), icon: m.saved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, onPressed: ctrl.toggleSave)),
                  const SizedBox(width: 10),
                  Expanded(child: SecondaryButton('Share', key: const Key('dm-share'), icon: Icons.ios_share_rounded, onPressed: ctrl.share)),
                ]),
                if (m.week.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const SectionLabel('This week'),
                  const SizedBox(height: 6),
                  for (final w in m.week)
                    ListRow(
                      key: Key('week-${w.date}'), title: w.title ?? 'Coming ${_short(w.date)}',
                      subtitle: w.state == 'today' ? 'Today' : (w.state == 'upcoming' ? 'Unlocks ${_short(w.date)}' : _short(w.date)),
                      leading: Icon(w.locked ? Icons.lock_outline_rounded : (w.state == 'today' ? Icons.check_circle_rounded : Icons.play_circle_outline_rounded), color: w.state == 'today' ? c.emberText : c.textSecondary),
                      showChevron: !w.locked && w.state != 'today',
                      onTap: w.state == 'upcoming' ? null : (w.locked ? () => openPaywall('lock') : (w.state == 'today' ? null : () => Get.toNamed('/message/${w.date}', arguments: {'date': w.date}))),
                    ),
                ],
                const SizedBox(height: 16),
                OutlineButton('Full archive', key: const Key('dm-archive'), onPressed: () => Get.toNamed(AppRoutes.exploreArchive)),
              ]));
            }),
          )),
    );
  }

  static String _short(String date) {
    final d = DateTime.tryParse(date);
    return d == null ? date : DateFormat('EEE, MMM d').format(d);
  }
}

/// 27 Explore archive.
class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(ArchiveController());
    return AppScaffold(
      title: 'Explore archive',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 8),
          child: TextField(
            key: const Key('archive-search'), onChanged: (v) => ctrl.q.value = v, style: AppText.bodyLarge.copyWith(color: c.textPrimary),
            decoration: InputDecoration(hintText: 'Search by word or date', prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide(color: c.border))),
          ),
        ),
        Obx(() => ctrl.themes.isEmpty
            ? const SizedBox.shrink()
            : SizedBox(
                height: 48,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: Gap.gutter), children: [
                  PillGroup<String>(options: ctrl.themes, selected: {if (ctrl.theme.value != null) ctrl.theme.value!}, onToggle: (t) {
                    ctrl.theme.value = ctrl.theme.value == t ? null : t;
                    ctrl.load();
                  }, labelOf: (s) => s),
                ]),
              )),
        Expanded(
          child: Obx(() => StateSwitcher(
                state: ctrl.state.value, onRetry: ctrl.load,
                empty: EmptyState(title: 'No messages found', body: ctrl.q.value.isEmpty ? 'Messages will appear here.' : 'Try another word.', icon: Icons.search_off_rounded),
                content: () => NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) ctrl.more();
                    return false;
                  },
                  child: ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
                    for (final e in ctrl.byMonth.entries) ...[
                      Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Text(e.key, style: AppText.overline.copyWith(color: c.textTertiary))),
                      for (final m in e.value) _ArchiveRow(m: m),
                    ],
                  ]),
                ),
              )),
        ),
      ]),
    );
  }
}

class _ArchiveRow extends StatelessWidget {
  const _ArchiveRow({required this.m});
  final DailyMessage m;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = DateTime.tryParse(m.date);
    return InkWell(
      onTap: m.locked ? () => openPaywall('lock') : () => Get.toNamed('/message/${m.date}', arguments: {'date': m.date}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 44, child: Column(children: [Text(d == null ? '' : '${d.day}', style: AppText.title.copyWith(color: c.textPrimary)), Text(d == null ? '' : DateFormat('EEE').format(d).toUpperCase(), style: AppText.micro.copyWith(color: c.textTertiary))])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)), Text('${m.type[0].toUpperCase()}${m.type.substring(1)}${m.durationSec == null ? '' : ' · ${(m.durationSec! / 60).ceil()} min'}${m.themeTag == null ? '' : ' · ${m.themeTag}'}${m.isFree ? ' · Free' : ''}', style: AppText.bodySmall.copyWith(color: c.textSecondary))])),
          if (m.locked) Icon(Icons.lock_outline_rounded, size: 18, color: c.textSecondary) else if (m.isFree) const AppBadge(BadgeKind.freeForYou),
        ]),
      ),
    );
  }
}

/// 28 Notifications.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(NotificationsController());
    final inbox = Get.find<InboxService>();
    return AppScaffold(
      title: 'Notifications', action: Obx(() => inbox.unread.value > 0 ? TextLink('Read all', onPressed: inbox.markAllRead, color: c.emberText) : const SizedBox.shrink()),
      body: Obx(() {
        final ViewState st = inbox.loading.value && inbox.items.isEmpty ? ViewState.loading : (inbox.failed.value ? ViewState.offline : (inbox.items.isEmpty ? ViewState.empty : ViewState.content));
        return StateSwitcher(
          state: st, onRetry: inbox.load,
          empty: const EmptyState(title: 'You’re all caught up', body: 'Group meditations, daily messages and news from Raphael show up here.', icon: Icons.notifications_none_rounded),
          content: () => Obx(() => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: Gap.gutter), itemCount: inbox.items.length, separatorBuilder: (_, __) => Divider(color: c.border, height: 1),
                itemBuilder: (_, i) {
                  final n = inbox.items[i];
                  return Slidable(
                    key: ValueKey('slide-${n.id}'),
                    endActionPane: ActionPane(motion: const BehindMotion(), extentRatio: .24, children: [
                      CustomSlidableAction(
                        key: Key('delete-${n.id}'), backgroundColor: c.dangerTint, foregroundColor: c.dangerText,
                        onPressed: (ctx) async {
                          final ok = await showAppSheet<bool>(ctx, title: 'Delete this notification?', builder: (sheet) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                            Text(n.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: sheet.colors.textSecondary)),
                            const SizedBox(height: 16),
                            DangerButton('Delete', key: const Key('confirm-delete-notification'), onPressed: () => Navigator.of(sheet).pop(true)),
                            const SizedBox(height: 8),
                            TextLink('Cancel', onPressed: () => Navigator.of(sheet).pop(false)),
                          ]));
                          if (ok == true) await inbox.remove(n);
                        },
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete_outline_rounded, color: c.dangerText), const SizedBox(height: 4), Text('Delete', style: AppText.caption.copyWith(color: c.dangerText, fontWeight: FontWeight.w700))]),
                      ),
                    ]),
                    child: InkWell(
                    key: Key('inbox-${n.id}'), onTap: () => ctrl.open(n),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(margin: const EdgeInsets.only(top: 6, right: 12), width: 8, height: 8, decoration: BoxDecoration(color: n.read ? Colors.transparent : c.ember, shape: BoxShape.circle)),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                          if (n.body != null) Text(n.body!, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                        ])),
                        const SizedBox(width: 8),
                        Text(_when(n.createdAt), style: AppText.caption.copyWith(color: c.textTertiary)),
                      ]),
                    ),
                  ));
                },
              )),
        );
      }),
    );
  }

  static String _when(DateTime d) {
    final diff = DateTime.now().toUtc().difference(d);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(d.toLocal());
  }
}
