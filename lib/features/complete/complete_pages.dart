import 'dart:io';
import '../../core/utils/countries.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/routes/app_routes.dart';
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
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';
import '../account/views/account_pages.dart';
import '../dedications/controllers/dedications_controllers.dart';
import '../player/controllers/player_controller.dart';
import '../today/views/today_widgets.dart';
import 'complete_controller.dart';

/// 45 Meditation complete · payoff (Stitch). Busy room: presence heat-map, belts, finishers and kudos. Quiet room or
/// solo: the compact summary. Streak and heart-rate cards only when there is real data.
class CompletePage extends StatelessWidget {
  const CompletePage({super.key});
  @override
  Widget build(BuildContext context) {
    if (Get.arguments is! CompleteArgs) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Get.offAllNamed(AppRoutes.todayMember)); // opened without a finished sit: nothing to show
      return const SizedBox.shrink();
    }
    final args = Get.arguments as CompleteArgs;
    final ctrl = Get.put(CompleteController(args));
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Obx(() {
            final busy = ctrl.busy;
            final st = ctrl.streak;
            final hr = ctrl.hrDelta;
            final now = DateTime.now();
            return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutterOnboarding, 8, Gap.gutterOnboarding, 28), children: staggered([
              Center(child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic,
                builder: (_, v, __) => SizedBox(width: 104, height: 104, child: CustomPaint(painter: _CheckRingPainter(v, c.ember, c.track), child: Center(child: Opacity(opacity: v, child: Icon(Icons.check_rounded, size: 40, color: c.emberText))))),
              )),
              Column(children: [
                Text('SIT COMPLETE', style: AppText.overline.copyWith(color: c.emberText)),
                const SizedBox(height: 6),
                Text('You sat ${ctrl.minutes} ${ctrl.minutes == 1 ? 'minute' : 'minutes'}.', key: const Key('complete-title'), textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if (ctrl.togetherLine != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(ctrl.togetherLine!, key: const Key('complete-together'), textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
              ]),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Expanded(child: Text('SESSION LOG', style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5))),
                    Text('Today · ${TimeOfDay.fromDateTime(now).format(context)}', style: AppText.caption.copyWith(color: c.textSecondary)),
                  ]),
                  const SizedBox(height: 12),
                  Text(args.player.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: c.textPrimary, fontSize: 19)),
                  if ((args.player.subtitle ?? '').isNotEmpty) Text(args.player.subtitle!, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  if (busy) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('SYNCHRONOUS NETWORK', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10))), Icon(Icons.public_rounded, size: 14, color: c.success), const SizedBox(width: 4), Text('Global active', style: AppText.caption.copyWith(color: c.success, fontWeight: FontWeight.w600))]),
                        const SizedBox(height: 8),
                        WorldDotMap(hot: ctrl.hot, height: 110),
                        if (!ctrl.belts.isEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: KeyedSubtree(key: const Key('complete-belts'), child: BeltCounts(belts: ctrl.belts))),
                        if (ctrl.minutesToday > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${groupedInt(ctrl.minutesToday)} minutes sat by everyone today', key: const Key('complete-collective'), style: AppText.caption.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _Stat(value: '${ctrl.minutes}:00', label: 'DURATION')),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(value: '${ctrl.daysThisWeek} ${ctrl.daysThisWeek == 1 ? 'day' : 'days'}', label: 'THIS WEEK')),
                    const SizedBox(width: 8),
                    Expanded(child: _Stat(value: '${ctrl.totalMinutes}', label: 'TOTAL MIN')),
                  ]),
                ]),
              ),
              if (st != null)
                AppCard(
                  key: const Key('complete-streak'),
                  child: Row(children: [
                    Icon(Icons.local_fire_department_rounded, color: c.emberText, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${st.current}-day streak${ctrl.streakExtended ? ' · +1 today' : ''}', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                      Text(st.record > st.current ? 'Record ${st.record} days · ${st.goalLine}' : (st.record > 0 ? 'Your record · ${st.goalLine}' : st.goalLine), style: AppText.caption.copyWith(color: c.textSecondary)),
                    ])),
                  ]),
                ),
              if (hr != null)
                AppCard(
                  key: const Key('complete-hr'),
                  child: Row(children: [
                    Icon(Icons.favorite_border_rounded, color: c.emberText),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Heart rate shift', style: AppText.navTitle.copyWith(color: c.textPrimary))),
                    Text('${hr > 0 ? '+' : ''}$hr bpm', style: AppText.title.copyWith(color: c.success, fontFeatures: AppText.tabular)),
                  ]),
                ),
              if (busy && ctrl.finishers > 1)
                AppCard(
                  key: const Key('complete-finishers'),
                  child: Row(children: [
                    Icon(Icons.groups_2_outlined, color: c.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${groupedInt(ctrl.finishers)} finished this sit today', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16, fontFeatures: AppText.tabular))),
                    if (ctrl.canKudos)
                      TextLink(ctrl.kudosSent.value ? 'Kudos sent' : 'Send kudos', key: const Key('send-kudos'), onPressed: ctrl.kudosSent.value ? null : ctrl.sendKudos, color: ctrl.kudosSent.value ? c.textTertiary : c.emberText),
                  ]),
                ),
              _DedicateCard(ctrl: ctrl),
              if (ctrl.player.sessionId != null) OutlineButton('Read today’s dedications', key: const Key('read-dedications'), onPressed: ctrl.readDedications),
              Column(children: [
                PrimaryButton('Share your sit', key: const Key('share-sit'), icon: Icons.ios_share_rounded, onPressed: ctrl.share),
                const SizedBox(height: 10),
                SecondaryButton('Done', key: const Key('complete-done'), onPressed: ctrl.done),
              ]),
            ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList()));
          }),
        ),
      ),
    );
  }
}

class _CheckRingPainter extends CustomPainter {
  _CheckRingPainter(this.v, this.color, this.track);
  final double v;
  final Color color, track;
  @override
  void paint(Canvas canvas, Size s) {
    final r = Rect.fromCircle(center: s.center(Offset.zero), radius: s.width / 2 - 4);
    canvas.drawArc(r, 0, 6.2832, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = track);
    canvas.drawArc(r, -1.5708, 6.2832 * v, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = color);
  }

  @override
  bool shouldRepaint(covariant _CheckRingPainter o) => o.v != v;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5)), const SizedBox(height: 6), FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppText.title.copyWith(color: c.textPrimary, fontSize: 18, fontFeatures: AppText.tabular)))]),
    );
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
          Text(ctrl.dedicateNote, key: const Key('dedicate-note'), style: AppText.bodySmall.copyWith(color: c.textTertiary)),
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
          Overline('Sit complete · ${complete.minutes} min${complete.result != null && complete.result!.togetherPeople > 1 ? ' · ${groupedInt(complete.result!.togetherPeople)} sat with you' : ''}'),
          const SizedBox(height: 8),
          Text('Who or what do you dedicate your practice to today?', style: AppText.title.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text('A family member, a colleague under pressure, or your own quiet resolve. Keep it honest and brief.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
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
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.person_outline_rounded, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text('Shown with your real first name only.', style: AppText.caption.copyWith(color: c.textSecondary))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Icon(ctrl.showPlace.value ? Icons.near_me_rounded : Icons.public_off_rounded, size: 18, color: c.textSecondary),
            const SizedBox(width: 8),
            Expanded(child: Text(ctrl.showPlace.value ? 'Show my city and country' : 'Worldwide: no place shown', key: const Key('location-line'), style: AppText.bodyLarge.copyWith(color: c.textPrimary))),
            AppToggle(key: const Key('location-toggle'), value: ctrl.showPlace.value, onChanged: (v) => ctrl.showPlace.value = v, label: 'Show my city and country'),
          ]),
          const SizedBox(height: 6),
          Text('Text only · monitored for safety and respect · no links or self-promotion. ${ctrl.left.value} of 3 dedications left today.', style: AppText.caption.copyWith(color: c.textSecondary)),
          const SizedBox(height: 14),
          PrimaryButton('Post dedication', key: const Key('post-dedication'), loading: ctrl.busy.value, onPressed: ctrl.valid
              ? () async {
                  final nav = Navigator.of(ctx);
                  final out = await ctrl.post();
                  switch (out) {
                    case PostOutcome.posted || PostOutcome.pending:
                      complete.lastDedication = ctrl.text.value.trim();
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
          Center(child: TextLink('Skip and view feed', key: const Key('dedication-skip'), onPressed: () {
            Navigator.of(ctx).pop();
            Get.toNamed(AppRoutes.together);
          }, color: c.textSecondary)),
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
                    Text('${ctrl.total.value} ${ctrl.total.value == 1 ? 'dedication' : 'dedications'}', key: const Key('ded-count'), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
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
            Expanded(child: Text('${d.firstName}${d.country == null ? '' : ' · ${countryName(d.country)}'}', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15))),
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
class _ShareStat extends StatelessWidget {
  const _ShareStat(this.label, this.value, {super.key, this.accent = false});
  final String label, value;
  final bool accent;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .06), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .08))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppText.overline.copyWith(color: Colors.white54, fontSize: 9)),
          const SizedBox(height: 4),
          Text(value, style: AppText.navTitle.copyWith(color: accent ? const Color(0xFFFF9B70) : Colors.white, fontFeatures: AppText.tabular)),
        ]),
      );
}

class SharePage extends StatefulWidget {
  const SharePage({super.key});
  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final _key = GlobalKey();
  String format = '9x16';
  bool showDedication = true;
  /// Include the heart-rate shift (only offered when the phone supplied one).
  bool includeHr = false;
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
      title: 'Share your sit',
      body: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.gutter), child: SegmentedControl<String>(options: const ['9x16', '1x1'], value: format, onChanged: (v) => setState(() => format = v), labelOf: (v) => v == '9x16' ? 'Story' : 'Post')),
        const SizedBox(height: 12),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: Gap.gutter), child: Center(
          child: FittedBox( // a narrow phone shrinks the preview; the saved image is still 360 wide
            fit: BoxFit.scaleDown,
            child: RepaintBoundary(
            key: _key,
            child: Container(
              width: 360, height: story ? 640 : 360, padding: const EdgeInsets.all(28),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF123C3A), Color(0xFF0B0D0E)])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text('WEHUM', style: AppText.overline.copyWith(color: const Color(0xFFFF9B70), fontSize: 13)),
                  const Spacer(),
                  const PulseDot(color: Color(0xFF4ADE80), size: 4),
                  const SizedBox(width: 6),
                  Text('SAT TODAY', style: AppText.overline.copyWith(color: Colors.white70, fontSize: 10)),
                ]),
                const Spacer(),
                Text('I sat ${complete.minutes} ${complete.minutes == 1 ? 'minute' : 'minutes'} today.', key: const Key('share-minutes'), style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: story ? 30 : 26)),
                const SizedBox(height: 10),
                if (complete.togetherLine != null) Text(complete.togetherLine!.replaceFirst('You sat', 'I sat'), style: AppText.bodyLarge.copyWith(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _ShareStat('DURATION', '${complete.minutes} min')),
                  const SizedBox(width: 10),
                  Expanded(child: _ShareStat('THIS WEEK', '${complete.daysThisWeek} ${complete.daysThisWeek == 1 ? 'day' : 'days'}')),
                ]),
                if ((complete.streak != null && complete.streak!.current > 1) || (includeHr && complete.hrDelta != null)) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    if (complete.streak != null && complete.streak!.current > 1) Expanded(child: _ShareStat('MOMENTUM', 'Day ${complete.streak!.current}', key: const Key('share-streak'), accent: true)),
                    if (complete.streak != null && complete.streak!.current > 1 && includeHr && complete.hrDelta != null) const SizedBox(width: 10),
                    if (includeHr && complete.hrDelta != null) Expanded(child: _ShareStat('CALM SHIFT', '${complete.hrDelta! > 0 ? '+' : ''}${complete.hrDelta} bpm', key: const Key('share-hr'))),
                  ]),
                ],
                const SizedBox(height: 12),
                Text(complete.player.title, style: AppText.title.copyWith(color: Colors.white)),
                if (showDedication && complete.lastDedication != null) ...[
                  const SizedBox(height: 14),
                  Text('“${complete.lastDedication}”', key: const Key('share-dedication'), style: AppText.body.copyWith(color: Colors.white70, fontStyle: FontStyle.italic)),
                ],
                const Spacer(),
                Text('wehum.app', style: AppText.bodySmall.copyWith(color: Colors.white54)),
              ]),
            ),
          ),
          ),
        ))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 20), child: Column(children: [
        if (complete.lastDedication != null) Row(children: [Expanded(child: Text('Show my dedication', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('toggle-dedication'), value: showDedication, onChanged: (v) => setState(() => showDedication = v), label: 'Show my dedication')]),
        if (complete.hrDelta != null) Row(children: [Expanded(child: Text('Include heart-rate shift', style: AppText.bodyLarge.copyWith(color: c.textPrimary))), AppToggle(key: const Key('toggle-hr'), value: includeHr, onChanged: (v) => setState(() => includeHr = v), label: 'Include heart-rate shift')]),
        const SizedBox(height: 8),
        PrimaryButton('Share to Stories or WhatsApp', key: const Key('share-btn'), loading: busy, onPressed: share),
        const SizedBox(height: 8),
        OutlineButton('Save image', key: const Key('save-btn'), onPressed: busy ? null : save),
        ])),
      ]),
    );
  }
}
