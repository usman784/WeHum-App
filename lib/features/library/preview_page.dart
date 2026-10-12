import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/audio/audio_engine.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/content.dart';
import '../../core/data/models/stitch.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/purchase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';

/// 30-second preview of a locked premium meditation (Stitch preview sheet). The clip comes from
/// `POST /v1/media/preview-url`; the player stops at the cut-off whatever the file length is.
class PreviewController extends GetxController {
  PreviewController(this.sessionId);
  final String sessionId;

  static const defaultCutoff = 30;
  late final MediaRepository _media = Get.find();
  late final CatalogService catalog = Get.find();
  late final PurchaseService purchases = Get.find();
  AudioEngine? _engine;
  final List<StreamSubscription<dynamic>> _subs = [];

  final state = ViewState.loading.obs;
  final position = Duration.zero.obs;
  final playing = false.obs;
  final ended = false.obs;
  final practicedToday = 0.obs;
  int cutoffSec = defaultCutoff;
  PreviewUrl? _url;

  SessionSummary? get session => catalog.catalog.value?.session(sessionId);

  @override
  void onInit() {
    super.onInit();
    Get.find<AnalyticsService>().track('preview_start', {'session_id': sessionId});
    _load();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      practicedToday.value = (await Get.find<CatalogRepository>().session(sessionId)).practicedToday;
    } catch (_) {/* the line simply stays hidden */}
  }

  Future<void> _load() async {
    try {
      _url = await _media.previewUrl(sessionId);
      if (_url!.fullAccess) {
        // already a member (entitlement arrived meanwhile): go straight to the full meditation
        Get.back<void>();
        return;
      }
      cutoffSec = _url!.previewSec ?? defaultCutoff;
      state.value = ViewState.content;
      await _play();
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  Future<void> _play() async {
    final u = _url?.url;
    if (u == null) return;
    final e = _engine ??= Get.find<PlayerEngines>().audio();
    for (final s in _subs) {
      s.cancel();
    }
    _subs
      ..clear()
      ..add(e.position.listen((p) {
        position.value = p;
        if (p >= Duration(seconds: cutoffSec) && !ended.value) _finish();
      }))
      ..add(e.playing.listen((v) => playing.value = v))
      ..add(e.status.listen((s) {
        if (s == EngineStatus.completed && !ended.value) _finish();
      }));
    ended.value = false;
    position.value = Duration.zero;
    await e.open(UrlSource(u));
    await e.seek(Duration.zero);
    await e.play();
  }

  void _finish() {
    ended.value = true;
    _engine?.pause();
    Get.find<AnalyticsService>().track('preview_end', {'session_id': sessionId, 'seconds': cutoffSec});
  }

  Future<void> replay() => _play();

  void unlock() {
    Get.find<AnalyticsService>().track('preview_unlock_tap', {'session_id': sessionId});
    Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': 'preview'});
  }

  Future<void> togglePlay() async {
    final e = _engine;
    if (e == null || ended.value) return;
    e.isPlaying ? await e.pause() : await e.play();
  }

  @override
  void onClose() {
    for (final s in _subs) {
      s.cancel();
    }
    _engine?.dispose();
    super.onClose();
  }
}

class PreviewPage extends StatelessWidget {
  const PreviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
    final ctrl = Get.put(PreviewController(id), tag: id);
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bgDeep,
      body: SafeArea(
        child: Obx(() => StateSwitcher(
              state: ctrl.state.value, onRetry: () => ctrl._load(),
              content: () => Obx(() {
                final s = ctrl.session;
                final pos = ctrl.position.value.inSeconds.clamp(0, ctrl.cutoffSec);
                String mmss(int v) => '${(v ~/ 60)}:${(v % 60).toString().padLeft(2, '0')}';
                final a = ctrl.purchases.offer.value?.annual, m = ctrl.purchases.offer.value?.monthly;
                return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
                  Row(children: [
                    Semantics(button: true, label: 'Close', child: GestureDetector(key: const Key('preview-close'), onTap: () => Get.back<void>(), child: Container(width: 44, height: 44, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)), child: Icon(Icons.close_rounded, color: c.textPrimary)))),
                    const Spacer(),
                    const AppBadge(BadgeKind.premium),
                  ]),
                  const SizedBox(height: 18),
                  Text(ctrl.ended.value ? '30-SECOND PREVIEW ENDED' : '30-SECOND FREE PREVIEW', key: const Key('preview-state'), style: AppText.overline.copyWith(color: c.emberText)),
                  const SizedBox(height: 8),
                  Text(s?.title ?? 'Meditation', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 4),
                  Text('with Raphael${s == null ? '' : ' · ${s.minutes} min'}', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 22),
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        GestureDetector(
                          key: const Key('preview-play'), onTap: ctrl.togglePlay,
                          child: Container(width: 52, height: 52, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle), child: Icon(ctrl.playing.value ? Icons.pause_rounded : Icons.play_arrow_rounded, color: c.onEmber, size: 30)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text('${mmss(pos)} / ${mmss(ctrl.cutoffSec)}', key: const Key('preview-time'), style: AppText.title.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular))),
                        Text('${ctrl.cutoffSec - pos} s left', style: AppText.caption.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
                      ]),
                      const SizedBox(height: 14),
                      AppProgressBar(pos / ctrl.cutoffSec),
                      const SizedBox(height: 6),
                      Row(children: [
                        Text('0:00', style: AppText.micro.copyWith(color: c.textTertiary)),
                        const Spacer(),
                        Text('${mmss(ctrl.cutoffSec)} preview ends', style: AppText.micro.copyWith(color: c.textTertiary)),
                      ]),
                    ]),
                  ),
                  if (ctrl.practicedToday.value > 0) ...[
                    const SizedBox(height: 12),
                    Text('${groupedInt(ctrl.practicedToday.value)} people sat this today', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  ],
                  const SizedBox(height: 22),
                  const SectionLabel('Free vs membership'),
                  const SizedBox(height: 10),
                  const _Matrix(),
                  const SizedBox(height: 22),
                  PrimaryButton(s == null ? 'Unlock the full meditation' : 'Unlock the full ${s.minutes} min', key: const Key('preview-unlock'), onPressed: ctrl.unlock),
                  if (a != null) ...[
                    const SizedBox(height: 8),
                    Center(child: Text('${a.trialDays}-day free trial, then ${a.priceString}/year${m == null ? '' : ' · or ${m.priceString}/month'}', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textSecondary))),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlineButton('Replay 30 s', key: const Key('preview-replay'), onPressed: ctrl.replay)),
                    const SizedBox(width: 12),
                    Expanded(child: OutlineButton('Back to library', onPressed: () => Get.back<void>())),
                  ]),
                ]);
              }),
            )),
      ),
    );
  }
}

class _Matrix extends StatelessWidget {
  const _Matrix();
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget col(String head, List<String> rows, {required bool on}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: on ? c.emberTint : c.surface, borderRadius: BorderRadius.circular(Radii.tile), border: Border.all(color: on ? c.ember : c.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(head.toUpperCase(), style: AppText.overline.copyWith(color: on ? c.emberText : c.textSecondary)),
              const SizedBox(height: 8),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(on ? Icons.check_circle_rounded : Icons.remove_circle_outline_rounded, size: 16, color: on ? c.emberText : c.textTertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r, style: AppText.caption.copyWith(color: c.textBody))),
                  ]),
                ),
            ]),
          ),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      col('Free', const ['30-second previews', 'Online streaming only', 'Free library from Raphael'], on: false),
      const SizedBox(width: 10),
      col('Membership', const ['Full-length meditations', 'Offline downloads', 'Group sits & daily message'], on: true),
    ]);
  }
}
