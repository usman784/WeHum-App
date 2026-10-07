import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import 'byo_controller.dart';

ByoController _ctrl() {
  if (Get.isRegistered<ByoController>()) return Get.find<ByoController>();
  final c = Get.put(ByoController());
  final slug = (Get.arguments as Map?)?['slug'] as String?;
  if (slug != null) c.loadShared(slug); // wehum.app/r/{slug}
  return c;
}

/// 39 Build your own.
class ByoPage extends StatelessWidget {
  const ByoPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) Get.delete<ByoController>(force: true);
      },
      child: AppScaffold(
        title: 'Build your own',
        body: Obx(() => StateSwitcher(
              state: ctrl.state.value, onRetry: () => Get.back<void>(),
              content: () => Column(children: [
                Expanded(
                  child: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 16), children: [
                        const _Step('1 · LENGTH'),
                        PillGroup<int>(options: ByoController.lengths, selected: {ctrl.length.value}, onToggle: (v) => ctrl.length.value = v, labelOf: (v) => '$v min'),
                        const _Step('2 · OPENING'),
                        if (ctrl.openings.isEmpty) const _Missing('Openings are not available yet.') else PillGroup<String?>(options: [null, ...ctrl.openings.map((b) => b.id)], selected: {ctrl.openingId.value}, onToggle: (v) => ctrl.openingId.value = v, labelOf: (id) => id == null ? 'None' : ctrl.block(id)?.name ?? ''),
                        const _Step('3 · SOUND'),
                        if (ctrl.sounds.isEmpty) const _Missing('Background sounds are not available yet.') else ...[
                          PillGroup<String?>(options: [null, ...ctrl.sounds.map((b) => b.id)], selected: {ctrl.soundId.value}, onToggle: (v) => ctrl.soundId.value = v, labelOf: (id) => id == null ? 'Silence' : ctrl.block(id)?.name ?? ''),
                          if (ctrl.soundId.value != null) ...[
                            const SizedBox(height: 8),
                            Row(children: [Text('Level', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Expanded(child: Slider(key: const Key('level'), value: ctrl.soundLevel.value.toDouble(), min: 0, max: 100, divisions: 20, onChanged: (v) => ctrl.soundLevel.value = v.round(), activeColor: c.ember))]),
                            SegmentedControl<String>(options: const ['simple', 'rich'], value: ctrl.texture.value, onChanged: (v) => ctrl.texture.value = v, labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}'),
                          ],
                        ],
                        const _Step('4 · BELLS'),
                        Row(children: [Expanded(child: Text('At the start', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(value: ctrl.bellStart.value, onChanged: (v) => ctrl.bellStart.value = v, label: 'Bell at the start')]),
                        Row(children: [Expanded(child: Text('At the end', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(value: ctrl.bellEnd.value, onChanged: (v) => ctrl.bellEnd.value = v, label: 'Bell at the end')]),
                        PillGroup<int>(options: ByoController.intervals, selected: {ctrl.bellInterval.value}, onToggle: (v) => ctrl.bellInterval.value = v, labelOf: (v) => v == 0 ? 'No interval bell' : 'Every $v min'),
                        const SizedBox(height: 20),
                        AppCard(key: const Key('advanced'), onTap: () => Get.toNamed(AppRoutes.buildYourOwnAdvanced), child: const ListRow(title: 'Advanced builder', subtitle: 'Several blocks, OM and mantra loops, share by link', leading: IconTile(Icons.tune_rounded))),
                      ])),
                ),
                _Footer(ctrl: ctrl),
              ]),
            )),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 8), child: Text(text, style: AppText.overline.copyWith(color: context.colors.textTertiary)));
}

class _Missing extends StatelessWidget {
  const _Missing(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Opacity(opacity: .6, child: Text(text, key: const Key('missing'), style: AppText.bodySmall.copyWith(color: context.colors.textSecondary)));
}

/// Sticky summary + Save / Build it.
class _Footer extends StatelessWidget {
  const _Footer({required this.ctrl});
  final ByoController ctrl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, 12, Gap.gutter, 16), decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: Obx(() => Column(mainAxisSize: MainAxisSize.min, children: [
              Text(ctrl.summary, key: const Key('summary'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15)),
              if (ctrl.message.value != null) Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlineButton('Save', key: const Key('byo-save'), loading: ctrl.busy.value, onPressed: () => _askName(context, ctrl))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: PrimaryButton('Build it', key: const Key('byo-build'), onPressed: ctrl.build)),
              ]),
            ])),
      ),
    );
  }
}

Future<void> _askName(BuildContext context, ByoController ctrl) async {
  var text = ctrl.name.value;
  final ok = await showAppSheet<bool>(context, title: 'Name your meditation', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(key: const Key('byo-name'), initialValue: text, autofocus: true, maxLength: 60, onChanged: (v) => text = v, decoration: const InputDecoration(hintText: 'e.g. Sunday morning')),
        const SizedBox(height: 8),
        PrimaryButton('Save', key: const Key('byo-name-ok'), onPressed: () => Navigator.of(ctx).pop(true)),
      ]));
  if (ok == true && text.trim().isNotEmpty) {
    if (await ctrl.save(text.trim()) && context.mounted) AppSnack.success(context, 'Saved to My Meditations');
  }
}

/// 40 Build your own · advanced.
class ByoAdvancedPage extends StatelessWidget {
  const ByoAdvancedPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = _ctrl();
    return AppScaffold(
      title: 'Advanced builder',
      body: Column(children: [
        Expanded(
          child: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 16), children: [
                TextFormField(key: const Key('adv-name'), initialValue: ctrl.name.value, onChanged: (v) => ctrl.name.value = v, decoration: InputDecoration(labelText: 'Name', filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)))),
                const _Step('BLOCKS · DRAG TO REORDER'),
                ReorderableListView(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), onReorderItem: ctrl.reorder,
                  children: [
                    for (final (i, b) in ctrl.blocks.indexed)
                      ListTile(
                        key: ValueKey('blk-$i-${b['blockId'] ?? 'silence'}'), contentPadding: EdgeInsets.zero,
                        title: Text(b['type'] == 'silence' ? 'Silence' : ctrl.block(b['blockId'] as String?)?.name ?? 'Missing sound', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)),
                        subtitle: Text(b['type'] == 'silence' ? 'Fills the time that is left' : (ctrl.block(b['blockId'] as String?)?.kind ?? ''), style: AppText.caption.copyWith(color: c.textSecondary)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (b['type'] == 'block') ...[
                            IconButton(tooltip: 'Fewer', onPressed: () => ctrl.setCount(i, ((b['count'] as num?)?.toInt() ?? 1) - 1), icon: const Icon(Icons.remove_circle_outline_rounded)),
                            Text('×${b['count'] ?? 1}', key: Key('count-$i'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
                            IconButton(tooltip: 'More', onPressed: () => ctrl.setCount(i, ((b['count'] as num?)?.toInt() ?? 1) + 1), icon: const Icon(Icons.add_circle_outline_rounded)),
                          ],
                          IconButton(tooltip: 'Remove', onPressed: () => ctrl.removeAt(i), icon: const Icon(Icons.close_rounded)),
                        ]),
                      ),
                  ],
                ),
                OutlineButton('Add block · voice, OM, humming, mantra, silence', key: const Key('add-block'), onPressed: () => showAppSheet<void>(context, title: 'Add block', builder: (ctx) => Column(children: [
                      for (final b in ctrl.advancedBlocks) ListTile(key: Key('add-${b.id}'), title: Text(b.name), subtitle: Text(b.kind), onTap: () {
                            ctrl.addBlock(b.id);
                            Navigator.of(ctx).pop();
                          }),
                      ListTile(key: const Key('add-silence'), title: const Text('Silence'), onTap: () {
                        ctrl.addSilence();
                        Navigator.of(ctx).pop();
                      }),
                    ]))),
                const _Step('SHARE THIS RECIPE'),
                AppCard(child: Row(children: [
                  Expanded(child: Text(ctrl.shareUrl.value ?? 'wehum.app/r/…', key: const Key('share-url'), style: AppText.bodySmall.copyWith(color: c.textSecondary))),
                  TextLink('Copy', onPressed: () async {
                    if (ctrl.shareUrl.value == null) await ctrl.share();
                    if (ctrl.shareUrl.value != null) await Clipboard.setData(ClipboardData(text: ctrl.shareUrl.value!));
                  }),
                ])),
                const SizedBox(height: 6),
                Text('Anyone with the app can open it and play the same blocks. The link holds only the recipe, never your name.', style: AppText.caption.copyWith(color: c.textTertiary)),
              ])),
        ),
        _Footer(ctrl: ctrl),
      ]),
    );
  }
}

/// 38 My Meditations.
class MyMeditationsPage extends StatelessWidget {
  const MyMeditationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(MyMeditationsController());
    return AppScaffold(
      title: 'My Meditations',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            empty: EmptyState(title: 'Nothing saved yet', body: 'Meditations you build and save show up here, one tap to play.', icon: Icons.tune_rounded, ctaLabel: 'Build a new one', onCta: () => Get.offNamed(AppRoutes.buildYourOwn)),
            content: () => Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                  Text('Meditations you built and saved. Tap play and it starts, no setup.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 8),
                  for (final r in ctrl.items)
                    Dismissible(
                      key: Key('r-${r.id}'), direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async => await showAppSheet<bool>(context, title: 'Delete “${r.name}”?', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [DangerButton('Delete', key: const Key('confirm-recipe-delete'), onPressed: () => Navigator.of(ctx).pop(true)), TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(false))])) ?? false,
                      onDismissed: (_) => ctrl.delete(r),
                      background: Container(color: c.dangerTint, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Icon(Icons.delete_outline_rounded, color: c.dangerText)),
                      child: ListRow(key: Key('recipe-${r.id}'), title: r.name, subtitle: '${r.lengthMin} min · ${r.blocks.isEmpty ? 'simple' : '${r.blocks.length} blocks'}', leading: const IconTile(Icons.play_arrow_rounded), onTap: () => ctrl.play(r)),
                    ),
                  const SizedBox(height: 12),
                  OutlineButton('Build a new one', key: const Key('build-new'), onPressed: () => Get.toNamed(AppRoutes.buildYourOwn)),
                ])),
          )),
    );
  }
}
