import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/data/models/activity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../onboarding/views/setup_pages.dart' show TimeWheel;
import '../../today/views/today_pages.dart' show tabHeader;
import '../controllers/you_controllers.dart';

/// 54 You.
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
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: [
          Row(children: [
            CircleAvatar(radius: 28, backgroundColor: c.teal, child: Text(ctrl.initials.isEmpty ? '·' : ctrl.initials, style: AppText.title.copyWith(color: c.tealText))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctrl.name.isEmpty ? 'You' : ctrl.name, key: const Key('you-name'), style: AppText.title.copyWith(color: c.textPrimary)),
              Text(ctrl.access.isMember ? (ctrl.access.isTrial ? 'Member · free trial' : 'Member') : 'Free', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            ])),
            TextLink('Edit', onPressed: () => Get.toNamed(AppRoutes.editProfile)),
          ]),
          const SizedBox(height: 16),
          if (guest)
            AppCard(
              key: const Key('guest-card'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Save your progress', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 4),
                Text('Keep your minutes safe and use WeHum on another phone.', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                const SizedBox(height: 12),
                Row(children: [Expanded(child: PrimaryButton('Save progress', onPressed: () => Get.toNamed(ctrl.access.isMember ? AppRoutes.saveYourProgressOptional : AppRoutes.saveYourProgressFreeUser))), const SizedBox(width: 10), Expanded(child: OutlineButton('Log in', onPressed: () => Get.toNamed(AppRoutes.logIn)))]),
              ]),
            ),
          if (guest) const SizedBox(height: 16),
          AdaptiveGrid(baseExtent: 92, children: [
            _Tile('${ctrl.daysThisWeek}', 'days this week'),
            _Tile('${ctrl.lifetime.value?.minutes ?? 0}', 'minutes'),
            _Tile('${ctrl.lifetime.value?.meditations ?? 0}', 'meditations'),
            _Tile('${ctrl.lifetime.value?.together ?? 0}', 'together'),
          ]),
          const SizedBox(height: 8),
          AppCard(key: const Key('week-chart'), onTap: () => Get.toNamed(AppRoutes.yourProgress), child: Row(children: [Expanded(child: Text('Your progress', style: AppText.navTitle.copyWith(color: c.textPrimary))), BarsMini(bars: ctrl.week.value?.bars ?? const []), const SizedBox(width: 8), Icon(Icons.chevron_right_rounded, color: c.textSecondary)])),
          const SizedBox(height: 12),
          for (final (key, title, route, badge) in [
            ('r-challenges', 'Challenges', AppRoutes.challenges, true), ('r-milestones', 'Milestones', AppRoutes.milestones, true), ('r-breath', 'Breathwork', AppRoutes.breathwork, true),
            ('r-reminders', 'Reminders', AppRoutes.reminders, false), ('r-membership', 'Membership', AppRoutes.manageMembership, false), ('r-downloads', 'Downloads', AppRoutes.downloads, false),
            ('r-recipes', 'My Meditations', AppRoutes.myMeditations, false), ('r-notifications', 'Notifications', AppRoutes.notifications, false), ('r-privacy', 'Privacy & data', AppRoutes.privacyData, false), ('r-help', 'Help', AppRoutes.helpAbout, false),
          ])
            ListRow(key: Key(key), title: title, trailing: badge ? const AppBadge(BadgeKind.comingSoon) : null, onTap: () => Get.toNamed(route)),
          const SizedBox(height: 8),
          if (!guest || p != null) DangerButton('Sign out', key: const Key('sign-out'), loading: ctrl.signingOut.value, onPressed: () async {
            final ok = await showAppSheet<bool>(context, title: 'Sign out?', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Your downloads stay on this phone. You can log in again any time.', style: AppText.body.copyWith(color: ctx.colors.textSecondary)),
              const SizedBox(height: 16),
              DangerButton('Sign out', key: const Key('confirm-sign-out'), onPressed: () => Navigator.of(ctx).pop(true)),
              TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(false)),
            ]));
            if (ok == true) await ctrl.signOut();
          }),
        ]);
      }),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.value, this.label);
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: AppText.title.copyWith(color: c.emberText)), Text(label, style: AppText.caption.copyWith(color: c.textSecondary))]));
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
                AdaptiveGrid(baseExtent: 92, children: [
                  _Tile('${d.minutes}', 'MINUTES'), _Tile('${d.meditations}', 'MEDITATIONS'), _Tile('${d.together}', 'TOGETHER'), _Tile('${d.average}', 'AVERAGE'),
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
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(EditProfileController());
    return AppScaffold(
      title: 'Edit profile',
      body: Obx(() => ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
            TextFormField(key: const Key('profile-first'), controller: ctrl.firstField, onChanged: (v) {
              ctrl.first.value = v;
              ctrl.saved.value = false;
            }, textCapitalization: TextCapitalization.words, style: AppText.bodyLarge.copyWith(color: c.textPrimary), decoration: InputDecoration(labelText: 'First name', errorText: ctrl.error.value, helperText: 'Shown with your dedications and gratitude posts.', filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)))),
            if (ctrl.email.value != null) ...[
              const SizedBox(height: 16),
              InputDecorator(decoration: InputDecoration(labelText: 'Email', helperText: ctrl.emailNote, filled: true, fillColor: c.surfaceInput, border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border))), child: Text(ctrl.email.value!, style: AppText.bodyLarge.copyWith(color: c.textSecondary))),
            ],
            const SizedBox(height: 20),
            Text('THEME', style: AppText.overline.copyWith(color: c.textTertiary)),
            const SizedBox(height: 8),
            SegmentedControl<String>(options: const ['dark', 'light', 'system'], value: ctrl.theme.value, onChanged: ctrl.setTheme, labelOf: (v) => '${v[0].toUpperCase()}${v.substring(1)}'),
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

/// 59 Privacy & data.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ctrl = Get.put(PrivacyController());
    const collect = [('Your first name', 'To greet you and sign your dedications.'), ('Your country', 'To show where meditations happen, never your exact location.'), ('Your meditations', 'To show your progress and count the world together.'), ('Your email (optional)', 'To sign in and send links. Never shown to others.')];
    return AppScaffold(
      title: 'Privacy & data',
      body: Obx(() => ListView(padding: const EdgeInsets.all(Gap.gutter), children: [
            Text('What we collect', style: AppText.title.copyWith(color: c.textPrimary)),
            for (final (t, why) in collect) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)), Text(why, style: AppText.bodySmall.copyWith(color: c.textSecondary))])),
            const SizedBox(height: 12),
            Text('Your choices', style: AppText.title.copyWith(color: c.textPrimary)),
            Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Count me in live presence', style: AppText.bodyLarge.copyWith(color: c.textPrimary)), Text('Adds your country to “meditating now” numbers', style: AppText.caption.copyWith(color: c.textSecondary))])), AppToggle(key: const Key('sw-presence'), value: ctrl.showCountry, onChanged: ctrl.setShowCountry, label: 'Count me in live presence')]),
            const SizedBox(height: 12),
            Text('What we never do', style: AppText.title.copyWith(color: c.textPrimary)),
            for (final t in ['Sell your data', 'Track your exact location', 'Show your email to other people']) Text('· $t', style: AppText.body.copyWith(color: c.textSecondary)),
            const SizedBox(height: 20),
            OutlineButton(ctrl.exportState.value == 'working' ? 'Preparing your data…' : (ctrl.exportState.value == 'done' ? 'Your data is ready' : 'Download my data'), key: const Key('export'), loading: ctrl.exportState.value == 'working', onPressed: ctrl.exportData),
            if (ctrl.exportState.value == 'done') Padding(padding: const EdgeInsets.only(top: 8), child: TextLink('Open the file (valid 24 hours)', onPressed: () => launchUrl(Uri.parse(ctrl.exportUrl.value!), mode: LaunchMode.externalApplication))),
            if (ctrl.exportState.value == 'failed') Text('Couldn’t prepare your data. Try again later.', style: AppText.bodySmall.copyWith(color: c.dangerText)),
            const SizedBox(height: 10),
            DangerButton('Delete my account', key: const Key('delete'), onPressed: () => _confirmDelete(context, ctrl)),
            const SizedBox(height: 12),
            Center(child: TextLink('Read the full privacy policy', onPressed: () => launchUrl(Uri.parse(AppLinks.privacy), mode: LaunchMode.externalApplication), color: c.textSecondary)),
          ])),
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
        ListRow(title: 'Watch the intro again', onTap: () => Get.toNamed(AppRoutes.intro1Welcome)),
        ListRow(title: 'Restore purchase', onTap: () => Get.toNamed(AppRoutes.restorePurchase)),
        ListRow(title: 'Questions & answers', onTap: () => open(AppLinks.faq)),
        ListRow(title: 'Contact support', onTap: () => open(AppLinks.support)),
        ListRow(title: 'Terms of use', onTap: () => open(AppLinks.terms)),
        ListRow(title: 'Privacy policy', onTap: () => open(AppLinks.privacy)),
        const SizedBox(height: 24),
        Center(child: Column(children: [Text('WeHum by Raphael Reiter', style: AppText.navTitle.copyWith(color: c.textPrimary)), GestureDetector(behavior: HitTestBehavior.opaque, onTap: () async { if (await ctrl.versionTapped() && context.mounted) AppSnack.success(context, 'Test event sent'); }, child: Obx(() => Text(ctrl.version.value, key: const Key('version'), style: AppText.bodySmall.copyWith(color: c.textSecondary)))), const SizedBox(height: 4), Text('Meditation training, not therapy.', style: AppText.caption.copyWith(color: c.textTertiary))])),
      ]),
    );
  }
}
