import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import '../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/routes/app_routes.dart';
import '../../core/config/app_links.dart';
import '../../core/data/models/content.dart';
import '../../core/services/access_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/data/models/activity.dart';
import '../../core/data/models/soon.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../player/player_args.dart';
import '../today/views/today_widgets.dart';

/// 30 SoS · How can I help? Eight feeling tiles start immediately (Raphael's voice, no intro). Premium for free users.
class SosController extends GetxController {
  late final CatalogService catalog = Get.find();
  late final AccessService access = Get.find();
  final state = ViewState.loading.obs;

  @override
  void onReady() {
    super.onReady();
    Get.find<AnalyticsService>().track('sos_open');
    load();
  }

  Future<void> load() async {
    if (catalog.catalog.value == null) await catalog.load();
    state.value = (catalog.catalog.value?.sos.tiles.isEmpty ?? true) ? (catalog.lastError != null ? ViewState.fromError(catalog.lastError!) : ViewState.empty) : ViewState.content;
  }

  SosInfo get sos => catalog.catalog.value?.sos ?? const SosInfo();

  void tap(SosTile t) {
    Get.find<AnalyticsService>().track('sos_tile_tap', {'feeling': t.feeling});
    if (t.access == Access.premium && !access.isMember) {
      openPaywall('lock');
      return;
    }
    Get.toNamed(AppRoutes.playerPresenceRing, arguments: PlayerArgs(
      kind: 'sos', title: t.feeling, subtitle: 'SoS · Raphael', sessionId: t.sessionId, coverUrl: t.cover?.url, target: PlaySession(t.sessionId), durationSec: t.durationSec));
  }

  Future<void> book() async {
    Get.find<AnalyticsService>().track('sos_book_tap');
    final url = (sos.help['url'] as String?) ?? AppLinks.booking;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class SosPage extends StatelessWidget {
  const SosPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(SosController());
    return AppScaffold(
      title: 'SoS', stitch: true,
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final s = ctrl.sos;
              final help = s.help;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: staggered([
                Row(children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('IMMEDIATE AUDIO DISPATCH', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.success, fontSize: 10.5))),
                  const SizedBox(width: 8),
                  GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => Get.toNamed(AppRoutes.crisisDirectory), child: SizedBox(height: 48, child: Row(children: [Text('Crisis directory', style: AppText.caption.copyWith(color: c.emberText, fontWeight: FontWeight.w700)), const SizedBox(width: 4), Icon(Icons.arrow_downward_rounded, size: 14, color: c.emberText)]))),
                ]),
                const SizedBox(height: 14),
                Text(s.title, key: const Key('sos-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Select what you are feeling. Raphael’s voice begins within two seconds: no intro, no build-up.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 14),
                AppCard(
                  key: const Key('sos-breath'), onTap: () => Get.toNamed(AppRoutes.breathRun, arguments: const BreathPattern(name: 'Sync breath', inhaleSec: 4, exhaleSec: 6, rounds: 24)),
                  semanticLabel: 'Sync breath right now, four minutes',
                  child: Row(children: [
                    Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.ember, width: 3)), child: Icon(Icons.air_rounded, size: 20, color: c.emberText)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SYNC BREATH RIGHT NOW', style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5)),
                      const SizedBox(height: 2),
                      Text('4 s in · 6 s out · 4 min, no audio needed', style: AppText.caption.copyWith(color: c.textSecondary)),
                    ])),
                    const _InhaleCue(),
                  ]),
                ),
                const SizedBox(height: 14),
                AdaptiveGrid(
                  baseExtent: 150,
                  children: [
                    for (final t in s.tiles)
                      AppCard(
                        key: Key('sos-${t.feeling}'), onTap: () => ctrl.tap(t),
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Text(t.durationSec == null ? '' : '${t.minutes} min', style: AppText.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600))),
                            const Spacer(),
                            if (t.access == Access.premium && !ctrl.access.isMember) Icon(Icons.lock_outline_rounded, size: 18, color: c.textTertiary) else Container(width: 30, height: 30, decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle), child: Icon(Icons.play_arrow_rounded, size: 18, color: c.emberText)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.feeling, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 17)),
                            if ((t.subtitle ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(t.subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary))),
                          ]),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                AppCard(
                  key: const Key('sos-crisis'), onTap: () => Get.toNamed(AppRoutes.crisisDirectory),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(Icons.support_agent_rounded, color: c.dangerText),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Need immediate human support?', style: AppText.navTitle.copyWith(color: c.textPrimary))),
                      Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                    ]),
                    const SizedBox(height: 6),
                    Text('If you are in crisis, you are not alone. Professional help is free, confidential and available 24/7.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 8),
                    Text('Open the crisis directory', style: AppText.caption.copyWith(color: c.emberText, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  key: const Key('sos-help'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((help['title'] as String?) ?? 'Need more help?', style: AppText.title.copyWith(color: c.textPrimary)),
                    const SizedBox(height: 4),
                    Text('With Raphael, one to one', style: AppText.overline.copyWith(color: c.tealText)),
                    const SizedBox(height: 8),
                    Text((help['body'] as String?) ?? 'You can contact us and book a personal session with Raphael.', style: AppText.body.copyWith(color: c.textBody)),
                    const SizedBox(height: 14),
                    PrimaryButton('Book a personal session', onPressed: ctrl.book),
                    const SizedBox(height: 8),
                    OutlineButton('Contact us', onPressed: () => launchUrl(Uri.parse(AppLinks.support), mode: LaunchMode.externalApplication)),
                  ]),
                ),
              ]));
            }),
          )),
    );
  }
}


/// "Inhale (4s)" / "Exhale (6s)" in step with the breath (4 s in, 6 s out), like the card says.
class _InhaleCue extends StatefulWidget {
  const _InhaleCue();
  @override
  State<_InhaleCue> createState() => _InhaleCueState();
}

class _InhaleCueState extends State<_InhaleCue> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(animation: _c, builder: (_, __) => Text(_c.value < .4 ? 'Inhale (4s)' : 'Exhale (6s)', style: AppText.navTitle.copyWith(color: c.emberText, fontSize: 14)));
  }
}
