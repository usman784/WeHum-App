import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/routes/app_routes.dart';
import '../../core/config/app_links.dart';
import '../../core/data/models/content.dart';
import '../../core/services/access_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/data/models/activity.dart';
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
      title: 'SoS',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final s = ctrl.sos;
              final help = s.help;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text(s.title, key: const Key('sos-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 6),
                Text('Short sessions for hard moments. Pick one and Raphael’s voice starts right away.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5,
                  children: [
                    for (final t in s.tiles)
                      AppCard(
                        key: Key('sos-${t.feeling}'), onTap: () => ctrl.tap(t),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Row(children: [Text(t.durationSec == null ? '' : '${(t.durationSec! / 60).round()} min', style: AppText.caption.copyWith(color: c.textSecondary)), const Spacer(), if (t.access == Access.premium && !ctrl.access.isMember) Icon(Icons.lock_outline_rounded, size: 16, color: c.textTertiary)]),
                          Text(t.feeling, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                        ]),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
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
              ]);
            }),
          )),
    );
  }
}
