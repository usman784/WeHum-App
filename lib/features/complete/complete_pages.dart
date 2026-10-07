import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/data/models/content.dart';
import '../../core/services/analytics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/controls.dart';
import '../../core/widgets/painters.dart';
import '../../core/widgets/sheets.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/surfaces.dart';
import '../account/views/account_pages.dart';
import '../dedications/controllers/dedications_controllers.dart';
import '../player/controllers/player_controller.dart';
import '../today/views/today_widgets.dart';
import 'complete_controller.dart';

/// 45 Meditation complete · payoff.
class CompletePage extends StatelessWidget {
  const CompletePage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as CompleteArgs;
    final ctrl = Get.put(CompleteController(args));
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutterOnboarding, 8, Gap.gutterOnboarding, 24), children: [
                const SizedBox(height: 8),
                const WorldDotMap(hot: {'DE': 40, 'US': 80, 'JP': 25, 'BR': 30, 'IN': 50, 'AU': 20, 'GB': 35}, height: 130),
                const SizedBox(height: 16),
                Text('You meditated ${ctrl.minutes} ${ctrl.minutes == 1 ? 'minute' : 'minutes'}.', key: const Key('complete-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                if (ctrl.togetherLine != null) Text(ctrl.togetherLine!, key: const Key('complete-together'), style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _Stat(value: '${ctrl.daysThisWeek} ${ctrl.daysThisWeek == 1 ? 'day' : 'days'}', label: 'This week')),
                  const SizedBox(width: 12),
                  Expanded(child: _Stat(value: '${ctrl.totalMinutes}', label: 'Total minutes')),
                ]),
                const SizedBox(height: 20),
                _DedicateCard(ctrl: ctrl),
                const SizedBox(height: 12),
                if (ctrl.player.sessionId != null) OutlineButton('Read today’s dedications', key: const Key('read-dedications'), onPressed: ctrl.readDedications),
                const SizedBox(height: 12),
                PrimaryButton('Done', key: const Key('complete-done'), onPressed: ctrl.done),
                const SizedBox(height: 8),
                Center(child: TextLink('Share your meditation', onPressed: ctrl.share, color: c.textSecondary)),
              ])),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: AppText.title.copyWith(color: c.textPrimary)), Text(label, style: AppText.bodySmall.copyWith(color: c.textSecondary))]));
  }
}

class _DedicateCard extends StatelessWidget {
  const _DedicateCard({required this.ctrl});
  final CompleteController ctrl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = ctrl.dedicate;
    final enabled = a == DedicateAccess.allowed && ctrl.canDedicate;
    return AppCard(
      key: const Key('dedicate-card'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Dedicate your meditation', style: AppText.navTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 4),
        Text('Who or what was this meditation for?', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
        const SizedBox(height: 12),
        if (enabled)
          PrimaryButton('Dedicate your meditation', key: const Key('dedicate-btn'), onPressed: () => showDedicationSheet(context, ctrl))
        else if (a == DedicateAccess.needsAccount)
          OutlineButton('Add your name to post', key: const Key('dedicate-gate'), icon: Icons.person_add_alt_1_rounded, onPressed: () async {
            if (await showAccountGate(context)) ctrl.access.isGuest.refresh();
          })
        else if (a == DedicateAccess.needsMembership) ...[
          Row(children: [Icon(Icons.lock_outline_rounded, size: 18, color: c.textTertiary), const SizedBox(width: 8), Expanded(child: Text('Members can write dedications. Anyone can read them.', style: AppText.bodySmall.copyWith(color: c.textTertiary)))]),
        ] else
          Text('Dedications are limited for today.', style: AppText.bodySmall.copyWith(color: c.textTertiary)),
      ]),
    );
  }
}

/// 47 Write a dedication (sheet).
Future<void> showDedicationSheet(BuildContext context, CompleteController complete) async {
  final ctrl = Get.put(composerFor(complete), tag: complete.meditationId);
  await showAppSheet<void>(context, title: 'Write a dedication', builder: (ctx) {
    final c = ctx.colors;
    return Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Overline('Dedicate your meditation'),
          const SizedBox(height: 8),
          Text('Who or what do you dedicate this meditation to?', style: AppText.body.copyWith(color: c.textBody)),
          const SizedBox(height: 12),
          TextField(
            key: const Key('dedication-field'), maxLines: 3, onChanged: (v) => ctrl.text.value = v, controller: TextEditingController.fromValue(TextEditingValue(text: ctrl.text.value, selection: TextSelection.collapsed(offset: ctrl.text.value.length))),
            style: AppText.bodyLarge.copyWith(color: c.textPrimary),
            decoration: InputDecoration(filled: true, fillColor: c.surfaceInput, counterText: '', border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border))),
          ),
          Align(alignment: Alignment.centerRight, child: Text('${ctrl.count} / 200', key: const Key('dedication-count'), style: AppText.caption.copyWith(color: ctrl.count > 200 ? c.dangerText : c.textTertiary))),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final s in dedicationSuggestions) ActionChip(label: Text(s), onPressed: () => ctrl.suggest(s))]),
          const SizedBox(height: 10),
          if (ctrl.inlineError != null) Text(ctrl.inlineError!, key: const Key('dedication-error'), style: AppText.bodySmall.copyWith(color: c.dangerText)),
          if (ctrl.showHelp.value) Padding(padding: const EdgeInsets.only(top: 8), child: Text('If you or someone you know is in danger, please contact local emergency services.', style: AppText.bodySmall.copyWith(color: c.textBody))),
          const SizedBox(height: 6),
          Text('Shown with your first name and country under this session. Text only, no links. ${ctrl.left.value} of 3 dedications left today.', style: AppText.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: 14),
          PrimaryButton('Post dedication', key: const Key('post-dedication'), loading: ctrl.busy.value, onPressed: ctrl.valid
              ? () async {
                  final nav = Navigator.of(ctx);
                  final out = await ctrl.post();
                  switch (out) {
                    case PostOutcome.posted || PostOutcome.pending:
                      nav.pop();
                      Get.toNamed('/dedications/${complete.player.sessionId}', arguments: {'sessionId': complete.player.sessionId, 'compose': true});
                    case PostOutcome.accountRequired:
                      nav.pop();
                      if (context.mounted) await showAccountGate(context);
                    case PostOutcome.premiumRequired:
                      nav.pop();
                      openPaywall('lock');
                    default:
                      break;
                  }
                }
              : null),
          Center(child: TextLink('Not now', onPressed: () => Navigator.of(ctx).pop(), color: c.textSecondary)),
        ]));
  });
}

/// 48 Session dedications.
class DedicationsPage extends StatelessWidget {
  const DedicationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final a = (Get.arguments as Map?) ?? const {};
    final sid = (a['sessionId'] ?? Get.parameters['sessionId'] ?? '') as String;
    final ctrl = Get.put(DedicationsController(sid, canCompose: a['compose'] == true), tag: sid);
    final c = context.colors;
    return AppScaffold(
      title: 'Dedications',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            empty: const EmptyState(title: 'No dedications yet', body: 'Be the first to dedicate a meditation.', icon: Icons.favorite_border_rounded),
            content: () => NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n.metrics.pixels > n.metrics.maxScrollExtent - 200) ctrl.more();
                return false;
              },
              child: Obx(() => ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                    Text('${ctrl.total.value} dedications', key: const Key('ded-count'), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                    const SizedBox(height: 8),
                    for (final d in ctrl.items) _DedicationCard(key: Key('ded-${d.id}'), d: d, ctrl: ctrl),
                    const SizedBox(height: 8),
                    Text(ctrl.canCompose ? 'Thank you for dedicating your meditation.' : 'Dedications can be written after you finish a meditation.', style: AppText.caption.copyWith(color: c.textTertiary)),
                  ])),
            ),
          )),
    );
  }
}

class _DedicationCard extends StatelessWidget {
  const _DedicationCard({super.key, required this.d, required this.ctrl});
  final Dedication d;
  final DedicationsController ctrl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 16, backgroundColor: c.teal, child: Text(d.firstName.isEmpty ? '·' : d.firstName[0], style: AppText.navTitle.copyWith(color: c.tealText, fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(child: Text('${d.firstName}${d.country == null ? '' : ' · ${d.country}'}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))),
            IconButton(tooltip: 'Report or block', onPressed: () => showReportSheet(context, ctrl, d), icon: Icon(Icons.more_horiz_rounded, color: c.textSecondary)),
          ]),
          Text('“${d.text}”', style: AppText.body.copyWith(color: c.textBody)),
          const SizedBox(height: 8),
          GestureDetector(
            key: Key('hold-${d.id}'), onTap: () => ctrl.toggleHold(d),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(d.heldByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: d.heldByMe ? c.ember : c.textSecondary), const SizedBox(width: 6), Text('Holding this · ${d.holdingCount}', style: AppText.bodySmall.copyWith(color: d.heldByMe ? c.emberText : c.textSecondary, fontWeight: FontWeight.w600))]),
          ),
        ]),
      ),
    );
  }
}

/// 49 Report a post.
Future<void> showReportSheet(BuildContext context, DedicationsController ctrl, Dedication d) async {
  var reason = 'spam';
  var block = false;
  await showAppSheet<void>(context, title: 'Report this dedication', builder: (ctx) {
    final c = ctx.colors;
    return StatefulBuilder(builder: (ctx, set) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Reports go to Raphael’s team. You won’t see this post again.', style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          RadioGroup<String>(
            groupValue: reason, onChanged: (v) => set(() => reason = v ?? reason),
            child: Column(children: [for (final (id, label) in reportReasons) RadioListTile<String>(key: Key('reason-$id'), value: id, title: Text(label, style: AppText.bodyLarge.copyWith(color: c.textPrimary)), contentPadding: EdgeInsets.zero)]),
          ),
          Row(children: [Expanded(child: Text('Block this person', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(value: block, onChanged: (v) => set(() => block = v), label: 'Block this person')]),
          const SizedBox(height: 10),
          DangerButton('Report', key: const Key('report-submit'), onPressed: () async {
            final nav = Navigator.of(ctx);
            final ok = await ctrl.report(d, reason, block: block);
            nav.pop();
            if (ok && context.mounted) AppSnack.success(context, block ? 'Reported and blocked' : 'Thanks, we’ll take a look');
          }),
          Center(child: TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(), color: c.textSecondary)),
        ]));
  });
}

/// 46 Share your meditation: 9:16 story or 1:1 post, optional dedication, rendered to a PNG at 3× for the share sheet or Photos.
class SharePage extends StatefulWidget {
  const SharePage({super.key});
  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final _key = GlobalKey();
  String format = '9x16';
  bool showDedication = true;
  bool busy = false;
  late final CompleteController complete = Get.arguments as CompleteController;

  /// 1080×1920 (9:16) or 1080×1080 (1:1) PNG bytes (spec §13).
  Future<List<int>> render() async {
    final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final w = format == '9x16' ? 360.0 : 360.0;
    final img = await b.toImage(pixelRatio: 1080 / w);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> share() async {
    setState(() => busy = true);
    final analytics = Get.find<AnalyticsService>()..track('share_format', {'format': format, 'include_dedication': showDedication});
    try {
      final bytes = await render();
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/wehum-meditation-$format.png');
      await f.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], text: 'wehum.app'));
      analytics.track('share_complete', {'format': format, 'include_dedication': showDedication});
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    try {
      if (await Gal.requestAccess()) {
        await Gal.putImageBytes(Uint8List.fromList(await render()));
        if (mounted) AppSnack.success(context, 'Saved to Photos');
      } else if (mounted) {
        AppSnack.error(context, 'Allow Photos access in Settings to save the image.');
      }
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Couldn’t save the image.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final story = format == '9x16';
    return AppScaffold(
      title: 'Share your meditation',
      body: ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
        SegmentedControl<String>(options: const ['9x16', '1x1'], value: format, onChanged: (v) => setState(() => format = v), labelOf: (v) => v == '9x16' ? 'Story' : 'Post'),
        const SizedBox(height: 16),
        Center(
          child: RepaintBoundary(
            key: _key,
            child: Container(
              width: 360, height: story ? 640 : 360, padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF123C3A), Color(0xFF0B0D0E)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WEHUM', style: AppText.overline.copyWith(color: const Color(0xFFFF9B70), fontSize: 13)),
                const Spacer(),
                Text('I meditated ${complete.minutes} ${complete.minutes == 1 ? 'minute' : 'minutes'} today.', key: const Key('share-minutes'), style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: story ? 30 : 26)),
                const SizedBox(height: 10),
                if (complete.togetherLine != null) Text(complete.togetherLine!.replaceFirst('You meditated', 'I meditated'), style: AppText.bodyLarge.copyWith(color: Colors.white70)),
                const SizedBox(height: 12),
                Text('${complete.daysThisWeek} days this week', style: AppText.navTitle.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                Text(complete.player.title, style: AppText.title.copyWith(color: Colors.white)),
                const Spacer(),
                Text('wehum.app', style: AppText.bodySmall.copyWith(color: Colors.white54)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [Expanded(child: Text('Show my dedication', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(value: showDedication, onChanged: (v) => setState(() => showDedication = v), label: 'Show my dedication')]),
        const SizedBox(height: 8),
        PrimaryButton('Share to Stories or WhatsApp', key: const Key('share-btn'), loading: busy, onPressed: share),
        const SizedBox(height: 8),
        OutlineButton('Save image', key: const Key('save-btn'), onPressed: busy ? null : save),
      ]),
    );
  }
}
