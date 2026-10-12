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
      title: 'Crisis support',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final d = ctrl.dir.value!;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: staggered([
                Text('You are not alone', key: const Key('crisis-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                Text('If you are in severe distress or feeling unsafe, please reach out to a person now. These lines are free and confidential.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 14),
                AppCard(
                  child: Row(children: [
                    Icon(Icons.public_rounded, color: c.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Region', style: AppText.caption.copyWith(color: c.textSecondary)),
                      Text(d.regionName, key: const Key('crisis-region'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                    ])),
                    if (d.regions.length > 1)
                      PopupMenuButton<String>(
                        key: const Key('crisis-change'), tooltip: 'Change region', onSelected: ctrl.pickRegion,
                        itemBuilder: (_) => [for (final r in d.regions) PopupMenuItem(value: r.code, child: Text(r.name))],
                        child: Text('Change', style: AppText.bodySmall.copyWith(color: c.emberText, fontWeight: FontWeight.w700)),
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
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (l.kind.isNotEmpty) Text(l.kind.toUpperCase(), style: AppText.overline.copyWith(color: c.tealText)),
                        const SizedBox(height: 4),
                        Text(l.name, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                        if (l.description.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.description, style: AppText.bodySmall.copyWith(color: c.textSecondary))),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          for (final a in l.actions)
                            ActionChip(
                              key: Key('act-${l.id}-${a.type}'), avatar: Icon(a.isCall ? Icons.call_rounded : Icons.sms_rounded, size: 18),
                              label: Text(a.label), onPressed: () => ctrl.act(l, a)),
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
