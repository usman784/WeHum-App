import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/stitch.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';

/// Crisis support directory: lines for the person's region (set in the CMS), a region switcher, international numbers.
/// No medical claims: it only lists organisations and how to reach them.
class CrisisDirectoryController extends GetxController {
  final state = ViewState.loading.obs;
  final dir = Rxn<CrisisDirectory>();
  final region = RxnString();

  @override
  void onInit() {
    super.onInit();
    Get.find<AnalyticsService>().track('crisis_directory_open', {'region': ''});
    load();
  }

  Future<void> load({String? country}) async {
    try {
      final d = await Get.find<CatalogRepository>().crisisDirectory(country: country);
      dir.value = d;
      region.value = d.regionCode;
      state.value = ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  /// Switches region: asks for that region's lines (the code of a region is one of its countries).
  Future<void> pickRegion(String code) async {
    region.value = code;
    await load(country: code);
  }

  Future<void> act(CrisisLine line, CrisisAction a) async {
    Get.find<AnalyticsService>().track('crisis_line_tap', {'region': region.value ?? '', 'line_id': line.id});
    final scheme = a.isCall ? 'tel' : 'sms';
    await launchUrl(Uri(scheme: scheme, path: a.value));
  }

  Future<void> dial(String number) => launchUrl(Uri(scheme: 'tel', path: number));
}

class CrisisDirectoryPage extends StatelessWidget {
  const CrisisDirectoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(CrisisDirectoryController());
    return AppScaffold(
      title: 'Crisis support', stitch: true,
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final d = ctrl.dir.value!;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: staggered([
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 36, height: 36, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle), child: Icon(Icons.favorite_rounded, size: 18, color: c.tealText)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('You are not alone', key: const Key('crisis-title'), style: AppText.title.copyWith(color: c.textPrimary, fontSize: 19)),
                      const SizedBox(height: 4),
                      Text('If you are in severe distress or feeling unsafe, please reach out to a person now. These lines are free and confidential.', style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.5)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Icon(Icons.public_rounded, size: 18, color: c.emberText),
                    const SizedBox(width: 10),
                    Expanded(child: Row(children: [
                      Text('Region: ', style: AppText.caption.copyWith(color: c.textSecondary)),
                      Flexible(child: Text(d.regionName, key: const Key('crisis-region'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 14))),
                    ])),
                    if (d.regions.length > 1)
                      PopupMenuButton<String>(
                        key: const Key('crisis-change'), tooltip: 'Change region', onSelected: ctrl.pickRegion,
                        itemBuilder: (_) => [for (final r in d.regions) PopupMenuItem(value: r.code, child: Text(r.name))],
                        child: Text('CHANGE', style: AppText.overline.copyWith(color: c.emberText, fontSize: 10.5)),
                      ),
                  ]),
                ),
                if (d.availability.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(d.availability, style: AppText.caption.copyWith(color: c.textSecondary))),
                const SizedBox(height: 14),
                for (final l in d.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AppCard(
                      key: Key('line-${l.id}'),
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(child: Text('AVAILABLE 24/7 · FREE · CONFIDENTIAL', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.success, fontSize: 10))),
                          if (l.kind.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Text(l.kind.toUpperCase(), style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5))),
                        ]),
                        const SizedBox(height: 8),
                        Text(l.name, style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
                        if (l.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.description, style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.45))),
                        const SizedBox(height: 14),
                        Row(children: [
                          for (final (i, a) in l.actions.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: GestureDetector(
                              key: Key('act-${l.id}-${a.type}'), onTap: () => ctrl.act(l, a),
                              child: Pressable(child: Container(
                                height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: i == 0 ? c.ember : c.surfaceAlt, borderRadius: BorderRadius.circular(99)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(a.isCall ? Icons.call_rounded : Icons.sms_rounded, size: 18, color: i == 0 ? c.onEmber : c.textPrimary), const SizedBox(width: 8), Flexible(child: Text(a.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.button.copyWith(color: i == 0 ? c.onEmber : c.textPrimary, fontSize: 15)))]),
                              )),
                            )),
                          ],
                        ]),
                      ]),
                    ),
                  ),
                if (d.international.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const SectionLabel('International helplines'),
                  const SizedBox(height: 4),
                  for (final x in d.international)
                    ListRow(
                      key: Key('intl-${x.country}'), title: x.country, subtitle: x.line, showChevron: false,
                      trailing: IconButton(tooltip: 'Call ${x.country}', onPressed: () => ctrl.dial(x.value), icon: Icon(Icons.call_rounded, color: c.emberText)),
                    ),
                ],
                if (d.tip.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    outlined: true, key: const Key('crisis-tip'),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.self_improvement_rounded, color: c.tealText),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('A grounding tip while you wait', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(d.tip, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                      ])),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                OutlineButton('Back to SoS', onPressed: () => Get.back<void>()),
              ]));
            }),
          )),
    );
  }
}
