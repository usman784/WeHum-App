import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/audio/download_engine.dart';
import '../../../core/data/api/caching_media.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/content.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/play_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../player/player_args.dart';
import '../../together/views/together_pages.dart' show DedicationLine;
import '../../today/controllers/today_controller.dart';

String formatBytes(int b) => b >= 1048576 ? '${(b / 1048576).toStringAsFixed(b >= 10 * 1048576 ? 0 : 1)} MB' : '${(b / 1024).round()} KB';

/// 41 Session detail. Prefetches the signed URL so Play starts at once; the MOTD session offers its three lengths.
class SessionDetailController extends GetxController {
  SessionDetailController(this.id);
  final String id;
  late final CatalogRepository _repo = Get.find();
  late final CatalogService catalog = Get.find();
  late final AccessService access = Get.find();
  late final DownloadService downloads = Get.find();

  final state = ViewState.loading.obs;
  final detail = Rxn<SessionDetail>();
  final motd = Rxn<MotdLike>();
  final length = 10.obs;
  final message = RxnString();

  SessionSummary? get s => detail.value?.summary ?? catalog.catalog.value?.session(id);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    // the catalog already knows the title: show it at once, fill in the rest from the API
    if (s != null) state.value = ViewState.content;
    try {
      detail.value = await _repo.session(id);
      state.value = ViewState.content;
    } catch (e) {
      if (s == null) state.value = ViewState.fromError(e);
    }
    try {
      final t = await Get.find<TodayRepository>().today(localDate());
      if (t.motd?.sessionId == id && t.motd!.lengths.isNotEmpty) {
        motd.value = MotdLike(t.motd!.date, t.motd!.lengths);
        length.value = t.motd!.lengths.first;
      }
    } catch (_) {}
    _prefetch();
  }

  void _prefetch() {
    final x = s;
    if (x == null || !access.isMember || !x.isPremium || x.isYoutube) return;
    final t = motd.value != null ? PlayMotd(motd.value!.date, length.value) : PlaySession(id);
    Get.find<CachingMediaRepository>().prefetch(t);
  }

  DownloadKey get key => motd.value != null ? DownloadKey('motd:${motd.value!.date}', length.value) : DownloadKey(id);
  bool get downloaded => downloads.isDownloaded(key.id, key.variant);
  double? get downloadProgress => downloads.progress['${key.id}#${key.variant}'];
  bool get downloading => downloads.find(key.id, key.variant)?.status == 'running';
  bool get canDownload => access.isMember && (s?.downloadable ?? false);

  void play() {
    final x = s;
    if (x == null) return;
    final m = motd.value;
    if (m != null && access.isMember) {
      Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
        kind: 'motd', title: x.title, subtitle: 'with Raphael', sessionId: id, coverUrl: x.cover?.url, date: m.date, lengthMin: length.value, target: PlayMotd(m.date, length.value), durationSec: length.value * 60));
      return;
    }
    launchSession(x);
  }

  Future<void> toggleDownload() async {
    message.value = null;
    if (downloaded || downloading) {
      await downloads.remove(key);
      return;
    }
    try {
      await downloads.start(key, title: '${s?.title ?? ''}${motd.value != null ? ' · ${length.value} min' : ''}', estimatedBytes: ((s?.durationSec ?? 0) * 16000));
    } on NotEnoughSpace catch (e) {
      message.value = 'Not enough space (needs ${formatBytes(e.needed)}).';
    }
  }
}

class MotdLike {
  const MotdLike(this.date, this.lengths);
  final String date;
  final List<int> lengths;
}

class SessionDetailPage extends StatelessWidget {
  const SessionDetailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
    final ctrl = Get.put(SessionDetailController(id), tag: id);
    final c = context.colors;
    return AppScaffold(
      title: '',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final s = ctrl.s!;
              final d = ctrl.detail.value;
              final member = ctrl.access.isMember;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                HeroImageCard(image: s.cover?.url, blurHash: s.cover?.blurhash, height: 220, child: Align(alignment: Alignment.topLeft, child: Row(children: [if (s.isPremium) const AppBadge(BadgeKind.premium), const SizedBox(width: 8), AppBadge(s.isVideo ? BadgeKind.video : BadgeKind.audio)]))),
                const SizedBox(height: 14),
                Text(s.title, key: const Key('session-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                Text('${d?.teacher?.name ?? 'Raphael'}${d?.theme == null ? '' : ' · ${d!.theme!.name}'} · ${ctrl.motd.value != null ? ctrl.motd.value!.lengths.map((l) => '$l').join(', ') : '${s.minutes}'} min', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                if (ctrl.motd.value != null && member) Padding(padding: const EdgeInsets.only(top: 12), child: SegmentedControl<int>(options: ctrl.motd.value!.lengths, value: ctrl.length.value, onChanged: (v) => ctrl.length.value = v, labelOf: (v) => '$v min')),
                if (s.description != null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(s.description!, style: AppText.bodyLarge.copyWith(color: c.textBody))),
                const SizedBox(height: 16),
                PrimaryButton(s.isPremium && !member ? 'Try 7 days free' : 'Play', key: const Key('session-play'), icon: Icons.play_arrow_rounded, onPressed: ctrl.play),
                if (ctrl.canDownload) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Download', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Text(ctrl.downloaded ? 'Plays without internet' : (ctrl.downloading ? 'Downloading… ${((ctrl.downloadProgress ?? 0) * 100).round()}%' : 'Listen without internet'), key: const Key('dl-note'), style: AppText.caption.copyWith(color: c.textSecondary))])),
                    AppToggle(key: const Key('dl-toggle'), value: ctrl.downloaded || ctrl.downloading, onChanged: (_) => ctrl.toggleDownload(), label: 'Download'),
                  ]),
                  if (ctrl.message.value != null) Text(ctrl.message.value!, key: const Key('dl-error'), style: AppText.bodySmall.copyWith(color: c.dangerText)),
                ],
                const SizedBox(height: 16),
                if (d != null) Text('${groupNumber(d.practicedToday)} people meditated this today', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                if (d != null && d.dedications.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(children: [Text('Dedications', style: AppText.title.copyWith(color: c.textPrimary)), const Spacer(), TextLink('See all', onPressed: () => Get.toNamed('/dedications/${s.id}', arguments: {'sessionId': s.id}))]),
                  for (final x in d.dedications.take(2)) DedicationLine(x),
                ],
              ]);
            }),
          )),
    );
  }
}

/// 58 Downloads.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dl = Get.find<DownloadService>();
    final online = Get.find<ConnectivityService>().online;
    return AppScaffold(
      title: 'Downloads',
      banner: Obx(() => online.value ? const SizedBox.shrink() : const OfflineBanner()),
      body: Obx(() {
        final items = dl.items.toList();
        if (items.isEmpty) {
          return EmptyState(title: 'No downloads yet', body: 'Download a session to listen without internet. Look for the download button on any session.', icon: Icons.download_for_offline_outlined, ctaLabel: 'Browse the library', onCta: () => Get.offAllNamed(AppRoutes.library));
        }
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
          Text(formatBytes(dl.usedBytes), key: const Key('used'), style: AppText.title.copyWith(color: c.textPrimary)),
          Text('on this phone', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: 4),
          Text('Downloaded sessions play without internet.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          for (final d in items)
            Dismissible(
              key: Key('dl-${d.sessionId}-${d.variant}'), direction: DismissDirection.endToStart,
              confirmDismiss: (_) async => await _confirm(context, 'Delete this download?'),
              onDismissed: (_) => dl.remove(DownloadKey(d.sessionId, d.variant)),
              background: Container(color: c.dangerTint, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete_outline_rounded, color: c.dangerText)),
              child: ListRow(
                title: d.title.isEmpty ? d.sessionId : d.title, subtitle: d.status == 'done' ? formatBytes(d.bytes) : (dl.errors['${d.sessionId}#${d.variant}'] ?? '${d.status[0].toUpperCase()}${d.status.substring(1)}${d.status == 'running' ? ' ${((dl.progress['${d.sessionId}#${d.variant}'] ?? 0) * 100).round()}%' : ''}'),
                leading: IconTile(d.status == 'done' ? Icons.download_done_rounded : Icons.downloading_rounded), showChevron: d.status == 'done',
                trailing: d.status == 'failed' || d.status == 'paused' ? TextLink('Retry', onPressed: () => dl.start(DownloadKey(d.sessionId, d.variant), title: d.title)) : null,
                onTap: d.status == 'done' ? () => _play(d.sessionId, d.variant) : null,
              ),
            ),
          const SizedBox(height: 16),
          DangerButton('Clear all downloads', key: const Key('clear-all'), onPressed: () async {
            if (await _confirm(context, 'Delete all downloads?')) await dl.clearAll();
          }),
        ]);
      }),
    );
  }

  static Future<bool> _confirm(BuildContext context, String title) async =>
      await showAppSheet<bool>(context, title: title, builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DangerButton('Delete', key: const Key('confirm-delete'), onPressed: () => Navigator.of(ctx).pop(true)),
            const SizedBox(height: 8),
            TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
          ])) ??
      false;

  void _play(String id, int variant) {
    final cat = Get.find<CatalogService>().catalog.value;
    if (id.startsWith('motd:')) {
      final date = id.substring(5);
      Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(kind: 'motd', title: 'Meditation of the Day', date: date, lengthMin: variant, target: PlayMotd(date, variant), durationSec: variant * 60));
      return;
    }
    final s = cat?.session(id);
    if (s != null) launchSession(s);
  }
}
