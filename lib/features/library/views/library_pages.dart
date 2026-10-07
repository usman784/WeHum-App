import 'package:flutter/material.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
import '../../../core/services/access_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../today/views/today_pages.dart' show tabHeader;
import '../../today/views/today_widgets.dart';
import '../controllers/library_controllers.dart';

IconData themeIcon(String? key) => switch (key) {
      'wind' => Icons.air_rounded, 'moon' => Icons.nightlight_round, 'target' => Icons.center_focus_strong_rounded, 'waves' => Icons.waves_rounded,
      'heart' => Icons.favorite_border_rounded, 'sun' => Icons.wb_sunny_outlined, 'leaf' => Icons.spa_outlined, _ => Icons.self_improvement_rounded,
    };

/// A session row used by lists: cover, title, meta, badges (PREMIUM for members/free alike; free items unlabelled for members).
class SessionRow extends StatelessWidget {
  const SessionRow({super.key, required this.s, required this.onTap, this.showFree = false, this.downloaded = false});
  final SessionSummary s;
  final VoidCallback onTap;
  final bool showFree, downloaded;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ThumbImage(s.cover?.url, blurHash: s.cover?.blurhash, width: 60, height: 60, radius: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)),
              const SizedBox(height: 2),
              Text('${s.isVideo ? 'Video' : (s.isYoutube ? 'Online library' : 'Audio')} · ${s.minutes} min', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            ]),
          ),
          if (downloaded) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.download_done_rounded, size: 18, color: c.tealText)),
          if (s.isPremium) const AppBadge(BadgeKind.premium) else if (showFree) const AppBadge(BadgeKind.freeForYou),
        ]),
      ),
    );
  }
}

/// 31 Library.
class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(LibraryController());
    return AppScaffold(
      header: tabHeader(), bottom: const AppBottomNav(current: AppTab.library),
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final cat = ctrl.c!;
              final member = ctrl.access.isMember;
              final active = ctrl.filters.value.active;
              final list = ctrl.filtered;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
                Text('Library', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      key: const Key('search-field'), onTap: () => Get.toNamed(AppRoutes.search),
                      child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), decoration: BoxDecoration(color: c.surfaceInput, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.border)), child: Row(children: [Icon(Icons.search_rounded, color: c.textSecondary), const SizedBox(width: 8), Flexible(child: Text('Search meditations', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyLarge.copyWith(color: c.textTertiary)))])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(button: true, label: 'Filters', child: GestureDetector(key: const Key('filter-btn'), onTap: () => showFiltersSheet(context, ctrl), child: Container(width: 48, height: 48, decoration: BoxDecoration(color: active ? c.emberTint : c.surface, shape: BoxShape.circle, border: Border.all(color: active ? c.ember : c.border)), child: Icon(Icons.tune_rounded, color: active ? c.emberText : c.textPrimary)))),
                ]),
                const SizedBox(height: 16),
                if (active) ...[
                  Text('${list.length} meditations', key: const Key('filtered-count'), style: AppText.overline.copyWith(color: c.textTertiary)),
                  for (final s in list) SessionRow(s: s, onTap: () => ctrl.open(s), showFree: !member, downloaded: ctrl.downloadedIds.contains(s.id)),
                  if (list.isEmpty) const EmptyState(title: 'No meditations match', body: 'Try changing or resetting the filters.', icon: Icons.filter_alt_off_rounded),
                ] else ...[
                  AdaptiveGrid(
                    baseExtent: 100,
                    children: [
                      _Tile(key: const Key('tile-silence'), icon: Icons.nightlight_round, title: 'Silence Room', badge: member ? null : BadgeKind.premium, onTap: ctrl.goSilence),
                      _Tile(key: const Key('tile-byo'), icon: Icons.tune_rounded, title: 'Build your own', badge: member ? null : BadgeKind.premium, onTap: () => member ? Get.toNamed(AppRoutes.buildYourOwn) : openPaywall('lock')),
                      _Tile(key: const Key('tile-challenges'), icon: Icons.emoji_events_outlined, title: 'Challenges', badge: BadgeKind.comingSoon, onTap: () => Get.toNamed(AppRoutes.challenges)),
                      _Tile(key: const Key('tile-breath'), icon: Icons.air_rounded, title: 'Breathwork', badge: BadgeKind.comingSoon, onTap: () => Get.toNamed(AppRoutes.breathwork)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(children: [Expanded(child: Text('Programs', style: AppText.title.copyWith(color: c.textPrimary))), TextLink('All programs', onPressed: () => Get.toNamed(AppRoutes.allPrograms))]),
                  if (ctrl.programCard.value != null)
                    AppCard(onTap: () => Get.toNamed('/program/${ctrl.programCard.value!.id}', arguments: {'id': ctrl.programCard.value!.id}), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Overline('In progress · day ${ctrl.programCard.value!.day} of ${ctrl.programCard.value!.days}'), const SizedBox(height: 4), Text(ctrl.programCard.value!.title, style: AppText.navTitle.copyWith(color: c.textPrimary)), const SizedBox(height: 8), AppProgressBar(ctrl.programCard.value!.day / ctrl.programCard.value!.days)]))
                  else
                    AppCard(onTap: () => Get.toNamed(AppRoutes.allPrograms), child: const ListRow(title: 'Start a program', subtitle: 'Multi-day practices, one meditation a day', leading: IconTile(Icons.route_outlined))),
                  const SizedBox(height: 20),
                  Text('Themes', key: const Key('themes-title'), style: AppText.title.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 8),
                  AdaptiveGrid(
                    baseExtent: 148,
                    children: [
                      for (final t in cat.themes)
                        AppCard(
                          key: Key('theme-${t.id}'), onTap: () => Get.toNamed('/theme/${t.id}', arguments: {'id': t.id}),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            IconTile(themeIcon(t.iconKey), size: 40),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)), Text(ctrl.catalog.themeLine(t), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary))]),
                          ]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  AppCard(key: const Key('sos-row'), onTap: () => Get.toNamed(AppRoutes.sosHowCanIHelp), child: const ListRow(title: 'SoS', subtitle: '8 short meditations for hard times', leading: IconTile(Icons.favorite_border_rounded))),
                  const SizedBox(height: 20),
                  Text(member ? 'From Raphael’s online library' : 'Free for you', key: const Key('free-heading'), style: AppText.title.copyWith(color: c.textPrimary)),
                  for (final s in ctrl.freeItems.take(5)) SessionRow(s: s, onTap: () => ctrl.open(s), showFree: !member),
                  const SizedBox(height: 12),
                  AppCard(key: const Key('recipes-row'), onTap: () => Get.toNamed(AppRoutes.myMeditations), child: ListRow(title: 'My Meditations', trailing: Text('${ctrl.recipeCount.value}', style: AppText.navTitle.copyWith(color: c.textSecondary)))),
                  const SizedBox(height: 8),
                  AppCard(key: const Key('downloads-row'), onTap: () => Get.toNamed(AppRoutes.downloads), child: ListRow(title: 'Downloads', trailing: Obx(() => Text('${ctrl.downloadedIds.length}', style: AppText.navTitle.copyWith(color: c.textSecondary))))),
                  const SizedBox(height: 16),
                  if (cat.teachers.isNotEmpty)
                    AppCard(key: const Key('teacher-card'), onTap: () => Get.toNamed('/teacher/${cat.teachers.first.id}', arguments: {'id': cat.teachers.first.id}), child: Row(children: [ThumbImage(cat.teachers.first.photoUrl, width: 52, height: 52, radius: 26), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cat.teachers.first.name, style: AppText.navTitle.copyWith(color: c.textPrimary)), Text('About your teacher', style: AppText.bodySmall.copyWith(color: c.textSecondary))])), Icon(Icons.chevron_right_rounded, color: c.textSecondary)])),
                ],
              ]);
            }),
          )),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.icon, required this.title, required this.onTap, this.badge});
  final IconData icon;
  final String title;
  final BadgeKind? badge;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [Icon(icon, color: c.emberText), const SizedBox(width: 6), Expanded(child: Align(alignment: Alignment.centerRight, child: badge == null ? const SizedBox.shrink() : AppBadge(badge!)))]),
        Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)),
      ]),
    );
  }
}

/// 33 Library filters (sheet): the button shows how many meditations match, live.
Future<void> showFiltersSheet(BuildContext context, LibraryController ctrl) async {
  var f = ctrl.filters.value;
  await showAppSheet<void>(context, title: 'Filters', builder: (ctx) {
    final c = ctx.colors;
    return StatefulBuilder(builder: (ctx, set) {
      final cat = ctrl.c!;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(alignment: Alignment.centerRight, child: TextLink('Reset', onPressed: () => set(() => f = const LibraryFilters()), color: c.textSecondary)),
        Text('LENGTH', style: AppText.overline.copyWith(color: c.textTertiary)),
        const SizedBox(height: 8),
        PillGroup<int>(options: const [10, 20, 30, 45], selected: f.lengths, onToggle: (v) => set(() => f = f.copyWith(lengths: f.lengths.contains(v) ? ({...f.lengths}..remove(v)) : {...f.lengths, v})), labelOf: (v) => switch (v) { 10 => 'Up to 10 min', 20 => '10–20 min', 30 => '20–30 min', _ => '30+ min' }),
        const SizedBox(height: 16),
        Text('TEACHERS', style: AppText.overline.copyWith(color: c.textTertiary)),
        const SizedBox(height: 8),
        PillGroup<String>(options: [for (final t in cat.teachers) t.id], selected: {if (f.teacherId != null) f.teacherId!}, onToggle: (id) => set(() => f = f.copyWith(teacherId: f.teacherId == id ? null : id)), labelOf: (id) => cat.teacher(id)?.name ?? id),
        const SizedBox(height: 16),
        Text('TYPE', style: AppText.overline.copyWith(color: c.textTertiary)),
        const SizedBox(height: 8),
        PillGroup<String>(options: const ['all', 'audio', 'video', 'free'], selected: {f.type}, onToggle: (v) => set(() => f = f.copyWith(type: v)), labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}'),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Downloaded only', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Text('Meditations that play without internet', style: AppText.caption.copyWith(color: c.textSecondary))])), AppToggle(value: f.downloadedOnly, onChanged: (v) => set(() => f = f.copyWith(downloadedOnly: v)), label: 'Downloaded only')]),
        const SizedBox(height: 16),
        PrimaryButton('Show ${ctrl.countFor(f)} meditations', key: const Key('show-n'), onPressed: () {
          ctrl.applyFilters(f);
          Navigator.of(ctx).pop();
        }),
      ]);
    });
  });
}

/// 32 Theme page.
class ThemePage extends StatelessWidget {
  const ThemePage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
    final ctrl = Get.put(ThemeScreenController(id), tag: id);
    final c = context.colors;
    final member = Get.find<AccessService>().isMember;
    return AppScaffold(
      title: ctrl.theme?.name ?? 'Theme',
      body: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
            Row(children: [IconTile(themeIcon(ctrl.theme?.iconKey), size: 52), const SizedBox(width: 12), Expanded(child: Text(ctrl.subtitle, key: const Key('theme-sub'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)))]),
            const SizedBox(height: 14),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: PillGroup<String>(options: const ['all', 'premium', 'online', 'video'], selected: {ctrl.tab.value}, onToggle: (v) => ctrl.tab.value = v, labelOf: (v) => switch (v) { 'all' => 'All', 'premium' => 'Premium', 'online' => 'Online library', _ => 'Video' })),
            const SizedBox(height: 8),
            for (final s in ctrl.items) SessionRow(s: s, onTap: () => openSessionDetail(s), showFree: !member),
            if (ctrl.items.isEmpty) const EmptyState(title: 'Nothing here yet', body: 'New meditations are added regularly.', icon: Icons.spa_outlined),
          ])),
    );
  }
}

void openSessionDetail(SessionSummary s) => Get.toNamed('/session/${s.id}', arguments: {'id': s.id});
