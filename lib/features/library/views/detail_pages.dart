import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/content.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/painters.dart' show Overline;
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../controllers/library_controllers.dart';
import 'library_pages.dart';

/// 34 Search: local, debounced 300 ms, recent searches.
class SearchPage extends StatelessWidget {
  const SearchPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(LibrarySearchController());
    final member = Get.find<AccessService>().isMember;
    return AppScaffold(
      title: 'Search',
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.gutter),
          child: TextField(
            key: const Key('search-input'), autofocus: true, onChanged: (v) => ctrl.q.value = v, onSubmitted: (_) => ctrl.remember(), style: AppText.bodyLarge.copyWith(color: c.textPrimary),
            decoration: InputDecoration(hintText: 'Search meditations', prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.pill), borderSide: BorderSide(color: c.border))),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (ctrl.q.value.trim().isEmpty) {
              return ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
                if (ctrl.recent.isNotEmpty) ...[
                  Row(children: [Text('RECENT', style: AppText.overline.copyWith(color: c.textTertiary)), const Spacer(), TextLink('Clear', onPressed: ctrl.clearRecent, color: c.textSecondary)]),
                  for (final r in ctrl.recent) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.history_rounded), title: Text(r), onTap: () => ctrl.q.value = r),
                ] else
                  Text('Search by title, theme or word.', style: AppText.body.copyWith(color: c.textSecondary)),
              ]);
            }
            if (ctrl.doneFor.value != ctrl.q.value.trim()) return const SizedBox.shrink(); // results for this text are still being found
            return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
              Text('MEDITATIONS · ${ctrl.results.length}', key: const Key('result-count'), style: AppText.overline.copyWith(color: c.textTertiary)),
              for (final s in ctrl.results) SessionRow(s: s, onTap: () {
                ctrl.remember();
                openSessionDetail(s);
              }, showFree: !member),
              if (ctrl.results.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text('No meditations found. Try another word.', style: AppText.body.copyWith(color: c.textSecondary))),
              if (ctrl.messages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('DAILY MESSAGES · ${ctrl.messages.length}', style: AppText.overline.copyWith(color: c.textTertiary)),
                for (final m in ctrl.messages) ListTile(contentPadding: EdgeInsets.zero, title: Text(m.title), subtitle: Text(m.date), onTap: () => Get.toNamed('/message/${m.date}', arguments: {'date': m.date})),
              ],
            ]);
          }),
        ),
      ]),
    );
  }
}

/// 35 All programs.
class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(ProgramsController());
    return AppScaffold(
      title: 'Programs',
      body: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
            Text('Multi-day practices. One session opens each day.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(height: 16),
            if (ctrl.inProgress.isNotEmpty) ...[
              Text('IN PROGRESS', style: AppText.overline.copyWith(color: c.textTertiary)),
              for (final p in ctrl.inProgress) _ProgramCard(p: p, progress: p.progress!.currentDay / (p.days.isEmpty ? 1 : p.days.length)),
            ],
            const SizedBox(height: 12),
            Text('AVAILABLE', style: AppText.overline.copyWith(color: c.textTertiary)),
            for (final p in ctrl.available) _ProgramCard(p: p),
            if (ctrl.available.isEmpty && ctrl.inProgress.isEmpty) const EmptyState(title: 'No programs yet', body: 'New programs are on their way.', icon: Icons.route_outlined),
          ])),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.p, this.progress});
  final Program p;
  final double? progress;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        key: Key('program-${p.id}'), onTap: () => Get.toNamed('/program/${p.id}', arguments: {'id': p.id}),
        child: Row(children: [
          ThumbImage(p.cover?.url, seed: p.id, width: 64, height: 64, radius: 14),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Overline('${p.days.length} days'),
            Text(p.title, style: AppText.navTitle.copyWith(color: c.textPrimary)),
            if (progress != null) Padding(padding: const EdgeInsets.only(top: 6), child: AppProgressBar(progress!)),
          ])),
          const SizedBox(width: 8),
          if (p.access == Access.premium) const AppBadge(BadgeKind.premium),
        ]),
      ),
    );
  }
}

/// 36 Program detail.
class ProgramDetailPage extends StatelessWidget {
  const ProgramDetailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
    final ctrl = Get.put(ProgramDetailController(id), tag: id);
    final c = context.colors;
    return AppScaffold(
      title: 'Program',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final p = ctrl.program.value!;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Row(children: [if (p.access == Access.premium) const AppBadge(BadgeKind.premium), const SizedBox(width: 8), Text('${p.days.length} DAYS', style: AppText.overline.copyWith(color: c.textTertiary))]),
                const SizedBox(height: 8),
                Text(p.title, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if (p.description != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(p.description!, style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
                const SizedBox(height: 16),
                if (p.started) ...[
                  Text('Day ${ctrl.currentDay} of ${p.days.length}', key: const Key('day-of'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                  Text('${p.days.length - ctrl.doneCount} meditations left', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  AppProgressBar(ctrl.fraction),
                  const SizedBox(height: 16),
                ],
                for (final d in p.days)
                  ListRow(
                    key: Key('day-${d.day}'), title: 'Day ${d.day}${d.title == null ? '' : ' · ${d.title}'}', subtitle: d.session == null ? null : '${d.session!.title} · ${d.session!.minutes} min', showChevron: false,
                    leading: CircleAvatar(radius: 18, backgroundColor: ctrl.statusOf(d.day) == 'done' ? c.success : (ctrl.statusOf(d.day) == 'today' ? c.ember : c.track), child: Icon(ctrl.statusOf(d.day) == 'done' ? Icons.check_rounded : (ctrl.statusOf(d.day) == 'locked' ? Icons.lock_outline_rounded : Icons.play_arrow_rounded), size: 18, color: c.onEmber)),
                  ),
                const SizedBox(height: 16),
                PrimaryButton(p.started ? 'Start day ${ctrl.currentDay}' : 'Start day 1', key: const Key('start-day'), loading: ctrl.busy.value, onPressed: ctrl.startDay),
                const SizedBox(height: 16),
                Builder(builder: (_) {
                  final t = Get.find<CatalogService>().catalog.value?.teachers.firstOrNull;
                  return t == null ? const SizedBox.shrink() : AppCard(onTap: () => Get.toNamed('/teacher/${t.id}', arguments: {'id': t.id}), child: Row(children: [ThumbImage(t.photoUrl, width: 44, height: 44, radius: 22), const SizedBox(width: 12), Expanded(child: Text('Led by ${t.name}', style: AppText.navTitle.copyWith(color: c.textPrimary))), Text('See bio', style: AppText.bodySmall.copyWith(color: c.emberText))]));
                }),
              ]);
            }),
          )),
    );
  }
}

/// 37 Teacher bio.
class TeacherPage extends StatefulWidget {
  const TeacherPage({super.key});
  @override
  State<TeacherPage> createState() => _TeacherPageState();
}

class _TeacherPageState extends State<TeacherPage> {
  final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
  late Future<Teacher> _teacher = Get.find<CatalogRepository>().teacher(id);
  Worker? _catalog;

  @override
  void initState() {
    super.initState();
    // the CMS changed something (socket `catalog:changed` → new catalog): show it without leaving the screen
    _catalog = ever(Get.find<CatalogService>().catalog, (_) {
      if (mounted) setState(() => _teacher = Get.find<CatalogRepository>().teacher(id));
    });
  }

  @override
  void dispose() {
    _catalog?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppScaffold(
      title: 'Teacher',
      body: FutureBuilder<Teacher>(
        future: _teacher,
        builder: (ctx, snap) {
          // keep what is on screen while a refresh is on its way (no flash back to the skeleton)
          if (snap.data == null && snap.connectionState != ConnectionState.done) return const SkeletonList(rows: 3);
          if (snap.data == null) return ErrorState(offline: true, onRetry: () => setState(() => _teacher = Get.find<CatalogRepository>().teacher(id)));
          final t = snap.data!;
          return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
            Center(child: ThumbImage(t.photoUrl, seed: t.id, width: 120, height: 120, radius: 60)),
            const SizedBox(height: 14),
            Center(child: Text(t.name, style: AppText.heroTitle.copyWith(color: c.textPrimary))),
            if (t.role != null) Center(child: Text(t.role!, style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
            if (t.bio != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(t.bio!, style: AppText.bodyLarge.copyWith(color: c.textBody))),
            const SizedBox(height: 16),
            for (final (label, url) in [('YouTube', t.youtubeUrl), ('Instagram', t.instagramUrl), ('Website', t.websiteUrl)])
              if (url != null) ListRow(title: label, subtitle: url.replaceFirst(RegExp(r'^https?://'), ''), onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
            const SizedBox(height: 12),
            Text('Sessions by ${t.name.split(' ').first}', style: AppText.title.copyWith(color: c.textPrimary)),
            for (final s in t.sessions) SessionRow(s: s, onTap: () => openSessionDetail(s), showFree: !Get.find<AccessService>().isMember),
          ]);
        },
      ),
    );
  }
}
