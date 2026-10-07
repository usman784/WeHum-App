import 'package:flutter/material.dart';
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
import '../../../core/widgets/surfaces.dart';
import '../../today/views/today_widgets.dart';
import '../controllers/messages_controllers.dart';

/// 26 Daily message.
class DailyMessagePage extends StatelessWidget {
  const DailyMessagePage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? const {};
    final date = (args['date'] ?? Get.parameters['date'] ?? '') as String;
    final ctrl = Get.put(DailyMessageController(date), tag: date);
    final c = context.colors;
    return AppScaffold(
      title: 'Daily message',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            empty: const EmptyState(title: 'No message yet', body: 'Raphael’s next message will appear here.', icon: Icons.mail_outline_rounded),
            content: () => Obx(() {
              if (ctrl.locked.value) {
                return EmptyState(title: 'The daily message is part of membership', body: 'A short note from Raphael, every day.', icon: Icons.lock_outline_rounded, ctaLabel: 'See membership options', onCta: () => openPaywall('lock'));
              }
              final m = ctrl.message.value!;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text(ctrl.dateLine, key: const Key('dm-date'), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                if (m.themeTag != null) Padding(padding: const EdgeInsets.only(top: 8), child: Overline(m.themeTag!, color: c.tealText)),
                const SizedBox(height: 6),
                Text(m.title, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if (m.imageUrl != null) Padding(padding: const EdgeInsets.only(top: 14), child: ThumbImage(m.imageUrl, height: 180, radius: Radii.card, width: double.infinity)),
                if (m.hasMedia && m.type != 'text') ...[
                  const SizedBox(height: 16),
                  PrimaryButton(m.type == 'video' ? 'Watch${m.durationSec == null ? '' : ' · ${(m.durationSec! / 60).ceil()} min'}' : 'Listen${m.durationSec == null ? '' : ' · ${(m.durationSec! / 60).ceil()} min'}', key: const Key('dm-play'), icon: Icons.play_arrow_rounded, onPressed: ctrl.play),
                ],
                if (m.text != null) ...[const SizedBox(height: 16), Text(m.text!, style: AppText.bodyLarge.copyWith(color: c.textBody, height: 1.6))],
                const SizedBox(height: 24),
                OutlineButton('Explore archive', onPressed: () => Get.toNamed(AppRoutes.exploreArchive)),
              ]);
            }),
          )),
    );
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
      onTap: () => Get.toNamed('/message/${m.date}', arguments: {'date': m.date}),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          SizedBox(width: 44, child: Column(children: [Text(d == null ? '' : '${d.day}', style: AppText.title.copyWith(color: c.textPrimary)), Text(d == null ? '' : DateFormat('EEE').format(d).toUpperCase(), style: AppText.micro.copyWith(color: c.textTertiary))])),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)), Text('${m.type[0].toUpperCase()}${m.type.substring(1)}${m.themeTag == null ? '' : ' · ${m.themeTag}'}', style: AppText.bodySmall.copyWith(color: c.textSecondary))])),
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
                  return InkWell(
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
                  );
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
