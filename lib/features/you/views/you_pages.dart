import '../../../core/widgets/brand_mark.dart';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/data/models/stitch.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/stitch.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/widgets/username_field.dart';
import '../../onboarding/views/setup_pages.dart' show TimeWheel;
import '../../today/views/today_pages.dart' show tabHeader;
import '../controllers/you_controllers.dart';

/// 54 You: the personal dashboard (Stitch): profile, forgiving streak, weekly cadence, lifetime volume, settings and offline.
class YouPage extends StatelessWidget {
  const YouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(YouController());
    return AppScaffold(
      header: tabHeader(), bottom: const AppBottomNav(current: AppTab.you),
      body: Obx(() {
        final p = ctrl.profile.value;
        final guest = ctrl.access.isGuest.value;
        final live = Get.isRegistered<LiveService>() ? (Get.find<LiveService>().agg.value?.total ?? 0) : 0;
        final life = ctrl.lifetime.value;
        final l = life?.lifetime;
        final label = ctrl.access.isMember ? (p?.entitlement.isFounding == true ? 'FOUNDING MEMBER' : (ctrl.access.isTrial ? 'MEMBER · FREE TRIAL' : 'MEMBER')) : 'FREE';
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 28), children: staggered([
          // ── profile
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Stack(children: [
                  UserAvatar(url: p?.avatarUrl, initial: ctrl.initials, size: 64, fontSize: 26),
                  Positioned(right: 0, bottom: 0, child: Container(width: 16, height: 16, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle, border: Border.all(color: c.surface, width: 3)))),
                ]),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.displayName.isNotEmpty == true ? p!.displayName : (ctrl.name.isEmpty ? 'You' : ctrl.name), key: const Key('you-name'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
                  if ((p?.username ?? '').isNotEmpty) Text('@${p!.username}', key: const Key('you-username'), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.emberDeep, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (label.startsWith('FOUNDING')) ...[Icon(Icons.local_fire_department_rounded, size: 12, color: c.emberText), const SizedBox(width: 4)],
                    Text(label, key: const Key('you-plan'), style: AppText.overline.copyWith(color: c.emberText, fontSize: 10)),
                  ])),
                ])),
                TextLink('Edit', onPressed: () => Get.toNamed(AppRoutes.editProfile)),
              ]),
              if (live > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    PulseDot(color: c.success, size: 3.5),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Live now', style: AppText.navTitle.copyWith(color: c.success, fontSize: 13))),
                    Text('${groupedInt(live)} sitting now', style: AppText.caption.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
                  ]),
                ),
              ],
            ]),
          ),
          if (guest)
            AppCard(
              key: const Key('guest-card'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Save your progress', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text('Keep your minutes safe and use ${brandName()} on another phone.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: PrimaryButton('Save progress', onPressed: () => Get.toNamed(ctrl.access.isMember ? AppRoutes.saveYourProgressOptional : AppRoutes.saveYourProgressFreeUser))), const SizedBox(width: 10), Expanded(child: OutlineButton('Log in', onPressed: () => Get.toNamed(AppRoutes.logIn)))]),
              ]),
            ),
          // ── streak
          if (ctrl.streak != null) ...[
            const _SecHead(Icons.event_available_outlined, 'Practice ritual & forgiving streaks', 'PROTOCOL'),
            _StreakBlock(streak: ctrl.streak!),
          ],
          AppCard(
            key: const Key('week-chart'), onTap: () => Get.toNamed(AppRoutes.yourProgress), padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('WEEKLY CADENCE (MINUTES)', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5))),
                Text('${ctrl.week.value?.minutes ?? 0}', key: const Key('week-minutes'), style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
                Text(' MIN TOTAL', style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 10.5)),
              ]),
              const SizedBox(height: 14),
              _WeekBars(bars: ctrl.week.value?.bars ?? const [], strip: ctrl.streak?.week ?? const []),
            ]),
          ),
          // ── lifetime
          const _SecHead(Icons.show_chart_rounded, 'Lifetime volume & practice depth', 'METRICS'),
          Row(children: [
            Expanded(child: _Metric('TOTAL SITS', '${l?.sits ?? life?.meditations ?? 0}', null, Icons.self_improvement_rounded)),
            const SizedBox(width: 10),
            Expanded(child: _Metric('TOTAL TIME', _hm(l?.minutes ?? life?.minutes ?? 0), null, Icons.timer_outlined)),
          ]),
          Row(children: [
            Expanded(child: _Metric('GROUP SITS', '${l?.together ?? life?.together ?? 0}', l == null ? 'Sat live with others' : 'Sat live with others (${l.togetherPct}%)', Icons.groups_2_outlined)),
            const SizedBox(width: 10),
            Expanded(child: _Metric('AVG. LENGTH', l == null ? '${life?.average ?? 0}' : l.avgMin.toStringAsFixed(1), 'Minutes per sit', Icons.donut_large_rounded)),
          ]),
          if (l?.hrShiftBpm != null)
            AppCard(
              key: const Key('hr-shift'),
              child: Row(children: [
                Container(width: 40, height: 40, decoration: BoxDecoration(color: c.emberDeep, shape: BoxShape.circle), child: Icon(Icons.monitor_heart_outlined, color: c.emberText)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mean heart-rate shift', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                  Text('Across the sits where your phone supplied it', style: AppText.caption.copyWith(color: c.textSecondary)),
                ])),
                Text('${l!.hrShiftBpm! > 0 ? '+' : ''}${l.hrShiftBpm} bpm', style: AppText.title.copyWith(color: c.success, fontFeatures: AppText.tabular)),
              ]),
            ),
          // ── settings & offline
          const _SecHead(Icons.tune_rounded, 'Account, practice settings & offline', 'PREFERENCES'),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: Gap.x16, vertical: 4),
            child: Column(children: [
              for (final (key, title, sub, route, badge) in [
                ('r-downloads', 'Downloaded meditations', 'Listen without internet', AppRoutes.downloads, null),
                ('r-reminders', 'Reminders & sounds', 'Daily sit reminder, bells, group warnings', AppRoutes.reminders, null),
                ('r-membership', 'Membership', ctrl.access.isMember ? (ctrl.access.isTrial ? 'Free trial' : 'Active') : 'Free plan', AppRoutes.manageMembership, null),
                ('r-recipes', 'My meditations', 'Your saved blends', AppRoutes.myMeditations, null),
                ('r-notifications', 'Notifications', 'Messages from Raphael and group sits', AppRoutes.notifications, null),
                ('r-challenges', 'Challenges', 'Cohort sprints with a grace day', AppRoutes.challenges, !ctrl.challengesOn),
                ('r-milestones', 'Milestones', 'Badges for first sit, streaks, minutes and group sits', AppRoutes.milestones, true),
                ('r-breath', 'Breathwork', 'Guided breathing lessons', AppRoutes.breathwork, true),
                ('r-privacy', 'Data sovereignty & privacy', 'Export your data, anonymous presence', AppRoutes.privacyData, null),
                ('r-help', 'Help & about', 'Contact, terms, version', AppRoutes.helpAbout, null),
              ])
                ListRow(key: Key(key), title: title, subtitle: sub, trailing: badge == true ? const AppBadge(BadgeKind.comingSoon) : null, onTap: () => Get.toNamed(route)),
            ]),
          ),
          if (!guest || p != null) DangerButton('Sign out', key: const Key('sign-out'), loading: ctrl.signingOut.value, onPressed: () async {
            final ok = await showAppSheet<bool>(context, title: 'Sign out?', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Your downloads stay on this phone. You can log in again any time.', style: AppText.body.copyWith(color: ctx.colors.textSecondary)),
              const SizedBox(height: 16),
              DangerButton('Sign out', key: const Key('confirm-sign-out'), onPressed: () => Navigator.of(ctx).pop(true)),
              TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
            ]));
            if (ok == true) await ctrl.signOut();
          }),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList()));
      }),
    );
  }
}

String _hm(int minutes) => minutes >= 60 ? '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m' : '${minutes}m';

class _SecHead extends StatelessWidget {
  const _SecHead(this.icon, this.title, this.tag);
  final IconData icon;
  final String title, tag;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Icon(icon, size: 20, color: c.emberText),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 17, height: 1.25))),
        const SizedBox(width: 8),
        Text(tag, style: AppText.overline.copyWith(color: c.textTertiary, fontSize: 10)),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.sub, this.icon);
  final String label, value;
  final String? sub;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10))), Icon(icon, size: 16, color: c.textSecondary)]),
        const SizedBox(height: 10),
        CountUp(value: int.tryParse(value) ?? -1, builder: (_, n) => Text(int.tryParse(value) == null ? value : '$n', style: AppText.display.copyWith(color: c.emberText, fontSize: 30, fontFeatures: AppText.tabular))),
        if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary)),
      ]),
    );
  }
}

/// Current run, record and the weekly grace day, with an honest explainer.
class _StreakBlock extends StatelessWidget {
  const _StreakBlock({required this.streak});
  final StreakInfo streak;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget tile(String label, IconData icon, String value, String unit, {bool accent = false}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(icon, size: 13, color: accent ? c.emberText : c.textSecondary), const SizedBox(width: 4), Flexible(child: Text(label, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)))]),
              const SizedBox(height: 6),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(value, style: AppText.display.copyWith(color: c.textPrimary, fontSize: 34, fontFeatures: AppText.tabular)),
                const SizedBox(width: 4),
                Text(unit, style: AppText.overline.copyWith(color: c.emberText, fontSize: 10)),
              ])),
            ]),
          ),
        );
    return AppCard(
      key: const Key('streak-block'), padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          tile('CURRENT', Icons.local_fire_department_rounded, '${streak.current}', streak.current == 1 ? 'DAY' : 'DAYS', accent: true),
          const SizedBox(width: 8),
          tile('RECORD', Icons.emoji_events_outlined, '${streak.record}', 'DAYS'),
          const SizedBox(width: 8),
          tile('GRACE', Icons.chevron_left_rounded, '${streak.graceLeft}', 'LEFT'),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.verified_user_outlined, size: 18, color: c.success),
            const SizedBox(width: 10),
            Expanded(child: Text(
              streak.graceLeft > 0 ? 'One grace day each week. A missed day uses it first, so the run keeps going without a punitive reset.' : 'Your grace day is used this week. Sit tomorrow to keep the run.',
              style: AppText.caption.copyWith(color: c.textSecondary, height: 1.45))),
          ]),
        ),
      ]),
    );
  }
}

/// Minutes per day for the week: ember bars, a check on rest days, a dot for days to come.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.bars, required this.strip});
  final List<ProgressBar> bars;
  final List<StreakDay> strip;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = bars.fold<int>(1, (m, b) => b.minutes > m ? b.minutes : m);
    return SizedBox(
      height: 112,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, b) in bars.indexed)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (i < strip.length && strip[i].state == DayState.rest)
                Text('REST', style: AppText.badge.copyWith(color: c.tealText))
              else
                Text(b.minutes > 0 ? '${b.minutes}m' : '', style: AppText.micro.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: b.minutes == 0 ? 0 : (b.minutes / max)), duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic,
                builder: (_, v, __) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4), height: 6 + 58 * v, alignment: Alignment.center,
                  decoration: BoxDecoration(color: b.minutes == 0 ? (b.current ? c.teal : c.surfaceAlt) : (b.current ? c.ember : c.ember.withValues(alpha: .9)), borderRadius: BorderRadius.circular(6)),
                  child: b.minutes == 0 && b.current ? Container(width: 5, height: 5, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle)) : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(b.label.isEmpty ? '' : b.label.substring(0, 1), style: AppText.overline.copyWith(color: b.current ? c.emberText : c.textSecondary, fontSize: 11)),
            ]),
          ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label, [this.hint]);
  final String value, label;
  final String? hint;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: AppText.title.copyWith(color: c.emberText)), Text(label, style: AppText.caption.copyWith(color: c.textSecondary)), if (hint != null) Text(hint!, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textTertiary, fontSize: 10))]));
  }
}

class BarsMini extends StatelessWidget {
  const BarsMini({super.key, required this.bars});
  final List<ProgressBar> bars;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final max = bars.fold<int>(1, (m, b) => b.minutes > m ? b.minutes : m);
    return ExcludeSemantics(child: SizedBox(width: 80, height: 28, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [for (final b in bars) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1), child: Container(height: 3 + 25 * b.minutes / max, decoration: BoxDecoration(color: b.current ? c.ember : c.track, borderRadius: BorderRadius.circular(2)))))])));
  }
}

/// 55 Your progress.
class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(ProgressController());
    return AppScaffold(
      title: 'Your progress', banner: Obx(() => ctrl.offline.value ? const OfflineBanner(text: 'Your progress works offline and syncs when you’re back.') : const SizedBox.shrink()),
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: () => ctrl.load(ctrl.period.value),
            content: () => Obx(() {
              final d = ctrl.data.value!;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                Text('${ctrl.dots.where((x) => x).length}', key: const Key('days-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 56)),
                Text('days meditated this week', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 12),
                WeekDots(done: ctrl.dots),
                const SizedBox(height: 20),
                SegmentedControl<Period>(options: Period.values, value: ctrl.period.value, onChanged: ctrl.select, labelOf: (p) => switch (p) { Period.week => 'Week', Period.month => 'Month', Period.year => 'Year', Period.all => 'Lifetime' }),
                const SizedBox(height: 16),
                AdaptiveGrid(baseExtent: 112, children: [
                  _Tile('${d.minutes}', 'MINUTES', 'Time you sat'), _Tile('${d.meditations}', 'MEDITATIONS', 'Sits you finished'), _Tile('${d.together}', 'GROUP SITS', 'Sat live with others'), _Tile('${d.average}', 'AVG. MINUTES', 'Per meditation'),
                ]),
                const SizedBox(height: 16),
                Text(ctrl.chartTitle, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                SizedBox(height: 160, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final b in d.bars) Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 6 + 90 * b.minutes / (d.bars.fold<int>(1, (m, x) => x.minutes > m ? x.minutes : m)), decoration: BoxDecoration(color: b.current ? c.ember : c.track, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 4), Text(b.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.micro.copyWith(color: c.textTertiary))])),
                ])),
              ]);
            }),
          )),
    );
  }
}

/// 56 Edit profile.
class EditProfilePage extends StatelessWidget {
  const EditProfilePage({super.key});

  InputDecoration _dec(AppColors c, String label, {String? error, String? helper}) => InputDecoration(
      labelText: label, errorText: error, helperText: helper, helperMaxLines: 3, filled: true, fillColor: c.surfaceInput,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)));

  void _photoSheet(BuildContext context, EditProfileController ctrl) {
    showModalBottomSheet<void>(
      context: context, backgroundColor: context.colors.surface, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 8),
        ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from library'), onTap: () { Get.back<void>(); ctrl.pickPhoto(ImageSource.gallery); }),
        ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Take a photo'), onTap: () { Get.back<void>(); ctrl.pickPhoto(ImageSource.camera); }),
        if (ctrl.avatarUrl.value != null) ListTile(leading: Icon(Icons.delete_outline_rounded, color: context.colors.dangerText), title: Text('Remove photo', style: TextStyle(color: context.colors.dangerText)), onTap: () { Get.back<void>(); ctrl.removePhoto(); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(EditProfileController());
    return AppScaffold(
      title: 'Edit profile',
      body: Obx(() => ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
            Center(child: GestureDetector(
              key: const Key('profile-photo'), onTap: () => _photoSheet(context, ctrl),
              child: Stack(children: [
                UserAvatar(url: ctrl.avatarUrl.value, initial: ctrl.first.value.trim().isEmpty ? '' : ctrl.first.value.trim().substring(0, 1).toUpperCase(), size: 96, fontSize: 34),
                Positioned(right: 0, bottom: 0, child: Container(width: 32, height: 32, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 3)), child: ctrl.photoBusy.value ? Padding(padding: const EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2, color: c.onEmber)) : Icon(Icons.edit_rounded, size: 16, color: c.onEmber))),
              ]),
            )),
            const SizedBox(height: 6),
            Center(child: TextLink('Change photo', onPressed: () => _photoSheet(context, ctrl))),
            const SizedBox(height: 14),
            TextFormField(key: const Key('profile-first'), controller: ctrl.firstField, onChanged: (v) {
              ctrl.first.value = v;
              ctrl.saved.value = false;
            }, textCapitalization: TextCapitalization.words, style: AppText.bodyLarge.copyWith(color: c.textPrimary), decoration: _dec(c, 'First name', error: ctrl.error.value != null && ctrl.firstError != null ? ctrl.error.value : null)),
            const SizedBox(height: 14),
            TextFormField(key: const Key('profile-last'), controller: ctrl.lastField, onChanged: (v) {
              ctrl.last.value = v;
              ctrl.saved.value = false;
            }, textCapitalization: TextCapitalization.words, style: AppText.bodyLarge.copyWith(color: c.textPrimary), decoration: _dec(c, 'Last name (optional)', error: ctrl.lastError)),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('profile-bio'), controller: ctrl.bioField, maxLength: 200, maxLines: 4, minLines: 2, textCapitalization: TextCapitalization.sentences,
              onChanged: (v) {
                ctrl.bio.value = v;
                ctrl.saved.value = false;
              },
              style: AppText.bodyLarge.copyWith(color: c.textPrimary), decoration: _dec(c, 'Short bio (optional)'),
            ),
            const SizedBox(height: 14),
            UsernameField(
              fieldKey: const Key('profile-username'), autoFill: false, initial: ctrl.savedUsername.value, seed: ctrl.first.value, enabled: !ctrl.usernameLocked,
              helper: ctrl.usernameLocked
                  ? 'You can change your username again on ${DateFormat.MMMd().format(ctrl.nextUsernameChange.value!)}.'
                  : 'Shown next to your dedications. You can change it once every 7 days.',
              onChanged: (v, ok) {
                ctrl.username.value = v;
                ctrl.usernameOk.value = ok || v == ctrl.savedUsername.value;
                ctrl.saved.value = false;
              },
            ),
            if (ctrl.email.value != null) ...[
              const SizedBox(height: 14),
              InputDecorator(decoration: _dec(c, 'Email', helper: ctrl.emailNote), child: Row(children: [
                Expanded(child: Text(ctrl.email.value!, style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
                Icon(Icons.lock_outline_rounded, size: 18, color: c.textTertiary),
              ])),
            ],
            const SizedBox(height: 20),
            Text('THEME', style: AppText.overline.copyWith(color: c.textTertiary)),
            const SizedBox(height: 8),
            SegmentedControl<String>(options: const ['dark', 'light', 'system'], value: ctrl.theme.value, onChanged: ctrl.setTheme, labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}'),
            if (ctrl.error.value != null && ctrl.firstError == null) Padding(padding: const EdgeInsets.only(top: 14), child: Text(ctrl.error.value!, key: const Key('profile-error'), style: AppText.bodySmall.copyWith(color: c.dangerText))),
            const SizedBox(height: 24),
            PrimaryButton(ctrl.saved.value ? 'Saved' : 'Save', key: const Key('profile-save'), loading: ctrl.busy.value, onPressed: ctrl.save),
          ])),
    );
  }
}

/// 57 Reminders & sounds.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(RemindersController());
    return AppScaffold(
      title: 'Reminders & sounds',
      body: Obx(() => ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
            if (ctrl.notificationsOff)
              Container(key: const Key('notif-off'), margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: c.infoBg, borderRadius: BorderRadius.circular(Radii.tile)), child: Row(children: [Icon(Icons.notifications_off_outlined, color: c.infoText), const SizedBox(width: 10), Expanded(child: Text('Notifications are off.', style: AppText.bodySmall.copyWith(color: c.infoText, fontWeight: FontWeight.w600))), TextLink('Open Settings', onPressed: () => launchUrl(Uri.parse('app-settings:')))])),
            Text('REMINDERS', style: AppText.overline.copyWith(color: c.textTertiary)),
            _Switch(title: 'Daily meditation reminder', value: ctrl.reminderOn, onChanged: ctrl.setReminder, fieldKey: const Key('sw-daily')),
            ListRow(key: const Key('daily-time'), title: 'Daily meditation time', trailing: Text(ctrl.time, style: AppText.navTitle.copyWith(color: c.textSecondary)), onTap: () => _pickTime(context, ctrl)),
            _Switch(title: 'Group meditation warning', subtitle: '10 minutes before the group starts', value: ctrl.groupWarning, onChanged: ctrl.setGroupWarning, fieldKey: const Key('sw-group')),
            _Switch(title: 'Daily message', subtitle: 'A note from Raphael each morning', value: ctrl.dailyMessage, onChanged: ctrl.setDailyMessage, fieldKey: const Key('sw-message')),
            const SizedBox(height: 12),
            Text('DOWNLOADS', style: AppText.overline.copyWith(color: c.textTertiary)),
            _Switch(title: 'Wi-Fi only', subtitle: 'Download only when connected to Wi-Fi', value: ctrl.wifiOnly.value, onChanged: (v) async => ctrl.setWifiOnly(v), fieldKey: const Key('sw-wifi')),
            const SizedBox(height: 8),
            ListRow(title: 'See what the notifications look like', onTap: () => Get.toNamed(AppRoutes.pushPreview)),
            const SizedBox(height: 12),
            Text('Times follow your phone’s time zone, so travelling doesn’t break them. We never send offers or marketing here.', style: AppText.caption.copyWith(color: c.textTertiary)),
          ])),
    );
  }

  Future<void> _pickTime(BuildContext context, RemindersController ctrl) async {
    final p = ctrl.time.split(':');
    final h = (int.tryParse(p[0]) ?? 7).obs, m = (int.tryParse(p[1]) ?? 0).obs;
    await showAppSheet<void>(context, title: 'Daily meditation time', builder: (ctx) => Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [TimeWheel(count: 24, value: h, label: 'Hour'), const SizedBox(width: 8), TimeWheel(count: 60, step: 5, value: m, label: 'Minute')]),
          const SizedBox(height: 12),
          PrimaryButton('Save', key: const Key('time-save'), onPressed: () {
            ctrl.setTime('${h.value.toString().padLeft(2, '0')}:${m.value.toString().padLeft(2, '0')}');
            Navigator.of(ctx).pop();
          }),
        ]));
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.title, required this.value, required this.onChanged, this.subtitle, this.fieldKey});
  final String title;
  final String? subtitle;
  final bool value;
  final Future<void> Function(bool) onChanged;
  final Key? fieldKey;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.bodyLarge.copyWith(color: c.textPrimary)), if (subtitle != null) Text(subtitle!, style: AppText.caption.copyWith(color: c.textSecondary))])), AppToggle(key: fieldKey, value: value, onChanged: (v) => onChanged(v), label: title)]));
  }
}

/// 29 Push notifications (lock-screen preview).
class PushPreviewPage extends StatelessWidget {
  const PushPreviewPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(PushPreviewController());
    return AppScaffold(
      title: 'Push notifications',
      body: Obx(() => ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
            // the person's own name, reminder time and (from the server) the group time: nothing here is sample data
            for (final (title, body, at) in ctrl.items)
              Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.card)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const BrandLogo(size: 16), const SizedBox(width: 6), Text('WEHUM', style: AppText.overline.copyWith(color: c.textTertiary)), const Spacer(), Text(at, style: AppText.caption.copyWith(color: c.textTertiary))]),
                const SizedBox(height: 6),
                Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                Text(body, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              ])),
            Text('You choose the daily time. Group warnings are optional. No marketing, ever.', style: AppText.caption.copyWith(color: c.textTertiary)),
          ])),
    );
  }
}

/// 59 Privacy & data (Stitch "data sovereignty"): what is kept and where, export, cache purge, anonymise, delete.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(PrivacyController());
    const matrix = [
      (Icons.timer_outlined, 'Practice history', 'Your sits, minutes and streak. Kept on our servers, linked to your account, so they follow you to a new phone.', 'ACCOUNT'),
      (Icons.groups_outlined, 'Collective presence', 'Only your country, and only while you sit. No GPS, no device fingerprint. Switch it off below.', 'EPHEMERAL'),
      (Icons.volunteer_activism_outlined, 'Dedications', 'Your first name and, if you chose it, your city. You can strip both from every past post here.', 'YOU DECIDE'),
      (Icons.favorite_border_rounded, 'Heart rate (optional)', 'Read on your phone from Apple Health or Health Connect. Only one number per sit leaves the phone, and only if you allow it.', 'DEVICE ONLY'),
    ];
    String mb(int b) => '${(b / 1048576).round()} MB';
    return AppScaffold(
      title: 'Privacy & data', stitch: true,
      body: Obx(() {
        final bytes = ctrl.cacheBytes;
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 6, Gap.gutter, 28), children: staggered([
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.shield_outlined, color: c.emberText)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)), const SizedBox(width: 6), Text('PROTOCOL ACTIVE', style: AppText.overline.copyWith(color: c.success, fontSize: 10))]),
                const SizedBox(height: 4),
                Text('Your practice belongs to you.', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
                const SizedBox(height: 6),
                Text('No advertising trackers. No data brokers. Your email is never shown to other people.', style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.45)),
              ])),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AUDIT REGISTRY', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text('What we keep, and where', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
            const SizedBox(height: 12),
            for (final (icon, t, why, tag) in matrix)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Icon(icon, color: c.emberText, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Text(tag, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5))),
                    ]),
                    const SizedBox(height: 8),
                    Text(why, style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.45)),
                  ]),
                ),
              ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your choices', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
            const SizedBox(height: 8),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Count me in live presence', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Text('Adds your country to “sitting now” numbers', style: AppText.caption.copyWith(color: c.textSecondary))])), AppToggle(key: const Key('sw-presence'), value: ctrl.showCountry, onChanged: ctrl.setShowCountry, label: 'Count me in live presence')]),
            ),
          ]),
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('PORTABILITY RIGHTS', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)),
              const SizedBox(height: 4),
              Text('Complete practice archive', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 17)),
              const SizedBox(height: 6),
              Text('A structured archive of your practice: telemetry.json and clean CSV tables, sent as a ZIP link to your email.', style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.45)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('SCHEMA', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5)), Text('telemetry.json', style: AppText.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700))]))),
                const SizedBox(width: 8),
                Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('RECORDS', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 9.5)), Text('sits_history.csv', style: AppText.caption.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700))]))),
              ]),
              const SizedBox(height: 14),
              PrimaryButton(ctrl.exportState.value == 'working' ? 'Preparing your archive…' : (ctrl.exportState.value == 'done' ? 'Your archive is ready' : 'Request my archive (.zip)'), key: const Key('export'), icon: Icons.send_outlined, loading: ctrl.exportState.value == 'working', onPressed: ctrl.exportData),
              if (ctrl.exportState.value == 'done') Padding(padding: const EdgeInsets.only(top: 8), child: TextLink('Open the archive (valid 24 hours)', onPressed: () => launchUrl(Uri.parse(ctrl.exportUrl.value!), mode: LaunchMode.externalApplication))),
              if (ctrl.exportState.value == 'failed') Text('Couldn’t prepare your data. Try again later.', style: AppText.bodySmall.copyWith(color: c.dangerText)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('ACCOUNT CONTROL', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10.5)),
            const SizedBox(height: 4),
            Text('Data erasure & sovereignty', style: AppText.title.copyWith(color: c.textPrimary, fontSize: 20)),
            const SizedBox(height: 10),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                ListRow(
                  key: const Key('purge-cache'), title: 'Purge offline audio', subtitle: ctrl.purged.value ? 'Cleared' : 'Frees ${mb(bytes)} on this phone', showChevron: false,
                  leading: const IconTile(Icons.cleaning_services_outlined),
                  trailing: TextLink(ctrl.purged.value ? 'Done' : 'Purge ${mb(bytes)}', onPressed: ctrl.purged.value || bytes == 0 ? null : ctrl.purgeCache, color: c.emberText)),
                ListRow(
                  key: const Key('anonymize'), title: 'Anonymise past dedications', subtitle: ctrl.anonymized.value == null ? 'Remove your name and place from everything you posted' : '${ctrl.anonymized.value} ${ctrl.anonymized.value == 1 ? 'post' : 'posts'} anonymised', showChevron: false,
                  leading: const IconTile(Icons.visibility_off_outlined),
                  trailing: TextLink('Anonymise', onPressed: ctrl.anonymized.value != null ? null : ctrl.anonymize, color: c.emberText)),
              ]),
            ),
            if (ctrl.anonymizeFailed.value) Text('Couldn’t anonymise right now. Try again later.', style: AppText.bodySmall.copyWith(color: c.dangerText)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('DESTRUCTIVE OPERATION', style: AppText.overline.copyWith(color: c.dangerText, fontSize: 10)),
            const SizedBox(height: 8),
            DangerButton('Delete my account', key: const Key('delete'), onPressed: () => _confirmDelete(context, ctrl)),
            const SizedBox(height: 12),
            Center(child: TextLink('Read the full privacy policy', onPressed: () => launchUrl(Uri.parse(AppLinks.privacy), mode: LaunchMode.externalApplication), color: c.textSecondary)),
          ]),
        ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 16), child: w)).toList()));
      }),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PrivacyController ctrl) async {
    final ok = await showAppSheet<bool>(context, title: 'Delete your account?', builder: (ctx) {
      final c = ctx.colors;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('This removes your account, meditations, progress, dedications and gratitude posts for good. It does not cancel your ${Platform.isIOS ? 'App Store' : 'Google Play'} subscription: cancel that in your store account.', style: AppText.body.copyWith(color: c.textBody)),
        const SizedBox(height: 16),
        DangerButton('Delete for good', key: const Key('confirm-delete-account'), onPressed: () => Navigator.of(ctx).pop(true)),
        const SizedBox(height: 8),
        PrimaryButton('Keep my account', onPressed: () => Navigator.of(ctx).pop(false)),
      ]);
    });
    if (ok == true) {
      if (await ctrl.deleteAccount()) {
        Get.offAllNamed(AppRoutes.splash);
      } else if (context.mounted) {
        AppSnack.error(context, ctrl.deleteError.value ?? 'Couldn’t delete the account.');
      }
    }
  }
}

/// 60 Help & about.
class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(HelpController());
    Future<void> open(String u) => launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    return AppScaffold(
      title: 'Help & about',
      body: ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
        ListRow(title: 'Watch the intro again', onTap: () => Get.toNamed(AppRoutes.intro1Welcome, arguments: {'replay': true})),
        ListRow(title: 'Restore purchase', onTap: () => Get.toNamed(AppRoutes.restorePurchase)),
        ListRow(title: 'Questions & answers', onTap: () => open(AppLinks.faq)),
        ListRow(title: 'Contact support', onTap: () => open(AppLinks.support)),
        ListRow(title: 'Terms of use', onTap: () => open(AppLinks.terms)),
        ListRow(title: 'Privacy policy', onTap: () => open(AppLinks.privacy)),
        const SizedBox(height: 24),
        Center(child: Column(children: [Text('${brandName()} by Raphael Reiter', style: AppText.navTitle.copyWith(color: c.textPrimary)), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () async { if (await ctrl.versionTapped() && context.mounted) AppSnack.success(context, 'Test event sent'); }, child: Obx(() => Text(ctrl.version.value, key: const Key('version'), style: AppText.bodySmall.copyWith(color: c.textSecondary)))), const SizedBox(height: 4), Text('Transcendence & Connection', style: AppText.caption.copyWith(color: c.textTertiary))])),
      ]),
    );
  }
}
