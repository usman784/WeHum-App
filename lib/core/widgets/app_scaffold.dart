import 'package:flutter/material.dart';
import 'brand_mark.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../theme/app_colors.dart';
import 'flex_scroll.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

class SosPill extends StatelessWidget {
  const SosPill({super.key, this.onTap});
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true, label: 'SoS, how can I help',
      child: GestureDetector(
        onTap: onTap ?? () => Get.toNamed(AppRoutes.sosHowCanIHelp),
        child: Container(
          height: Sizes.touch, padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text('SoS', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 15)),
          ]),
        ),
      ),
    );
  }
}

/// The top-right Settings button: a gear that opens Settings directly (the You tab is already in the bottom bar).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key, this.size = Sizes.touch, this.onTap});
  final double size;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true, label: 'Settings',
      child: GestureDetector(
        key: const Key('open-settings'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Get.toNamed(AppRoutes.settings),
        // the circle can be smaller than the tap area (48 pt minimum)
        child: SizedBox(width: Sizes.touch, height: Sizes.touch, child: Center(child: Container(width: size, height: size, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)), child: Icon(Icons.settings_outlined, size: size * .5, color: c.textPrimary)))),
      ),
    );
  }
}

/// Tab header: logo + SoS + bell (unread dot) + settings.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, this.unread = 0, this.onBell, this.onSettings});
  final int unread;
  final VoidCallback? onBell, onSettings;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClampedText(child: Padding(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, 12, Gap.gutter, 8),
      child: Row(children: [
        const BrandMark(size: 30),
        const SizedBox(width: 10),
        // Expanded, not Flexible + Spacer: those two would split the free space and cut the name to "We…"
        Expanded(child: Obx(() => Text(brandName(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title.copyWith(color: c.textPrimary)))),
        const SizedBox(width: 8),
        const SosPill(),
        const SizedBox(width: 8),
        Semantics(
          button: true, label: unread > 0 ? 'Notifications, $unread new' : 'Notifications',
          child: GestureDetector(
            onTap: onBell ?? () => Get.toNamed(AppRoutes.notifications),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: Sizes.touch, height: Sizes.touch, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)), child: Icon(Icons.notifications_none_rounded, color: c.textPrimary)),
              if (unread > 0) Positioned(right: 2, top: 2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle, border: Border.all(color: c.bg, width: 2)))),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        SettingsButton(onTap: onSettings),
      ]),
    ));
  }
}

/// Header of the Stitch sub screens: back arrow, centered title, the SoS pill and the Settings button (64 px high).
class StitchHeader extends StatelessWidget {
  const StitchHeader({super.key, required this.title, this.onBack, this.sos = true});
  final String title;
  final bool sos;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClampedText(child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: onBack ?? () => Get.back<void>(), icon: Icon(Icons.arrow_back_rounded, size: 22, color: c.textPrimary)),
            const BrandMark(size: 26),
            Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary))),
            if (sos) const SosPill(),
            const SizedBox(width: 8),
            const SettingsButton(size: 40),
            const SizedBox(width: 10),
          ]),
        ),
      ),
    ));
  }
}

/// Sub header: back, centered title, optional right action.
class SubHeader extends StatelessWidget implements PreferredSizeWidget {
  const SubHeader({super.key, required this.title, this.action, this.onBack, this.transparent = false});
  final String title;
  final Widget? action;
  final VoidCallback? onBack;
  final bool transparent;
  @override
  Size get preferredSize => const Size.fromHeight(Sizes.navBar + 8);
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClampedText(child: SafeArea(
      bottom: false,
      child: SizedBox(
        height: Sizes.navBar + 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: onBack ?? () => Get.back<void>(), icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.textPrimary)),
            Expanded(child: Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary))),
            ConstrainedBox(constraints: const BoxConstraints(minWidth: Sizes.touch + 4), child: action ?? const SizedBox.shrink()),
          ]),
        ),
      ),
    ));
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.title, this.action, this.header, this.bottom, this.banner, this.resize = true, this.stitch = false, this.sos = true});
  final Widget body;
  final String? title;
  final Widget? action;
  /// Replaces the sub header (e.g. [TabHeader]).
  final Widget? header;
  final Widget? bottom;
  final Widget? banner;
  final bool resize;
  /// Header with the logo, the SoS pill and the profile photo (Stitch sub screens).
  final bool stitch;
  /// The SoS pill in the Stitch header (off on the sit screens, where it only distracts).
  final bool sos;

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: resize,
        bottomNavigationBar: bottom,
        body: SafeArea(
          bottom: bottom == null,
          child: Column(children: [
            if (header != null) header! else if (title != null) (stitch ? StitchHeader(title: title!, sos: sos) : SubHeader(title: title!, action: action)),
            if (banner != null) banner!,
            Expanded(child: body),
          ]),
        ),
      );
}

enum AppTab { today, library, together, you }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.current});
  final AppTab current;

  static const _items = [
    (AppTab.today, Icons.wb_sunny_outlined, 'Today', AppRoutes.todayMember),
    (AppTab.library, Icons.grid_view_rounded, 'Library', AppRoutes.library),
    (AppTab.together, Icons.groups_2_outlined, 'Together', AppRoutes.together),
    (AppTab.you, Icons.person_outline_rounded, 'You', AppRoutes.you),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClampedText(child: Container(
      decoration: BoxDecoration(color: c.bg, border: Border(top: BorderSide(color: c.border))),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: IntrinsicHeight(child: Row(children: [
            for (final (tab, icon, label, route) in _items)
              Expanded(
                child: Semantics(
                  button: true, selected: tab == current, label: label,
                  child: InkWell(
                    onTap: tab == current ? null : () => Get.offAllNamed(route),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, color: tab == current ? c.ember : c.textSecondary),
                      const SizedBox(height: 4),
                      Text(label, style: AppText.micro.copyWith(fontWeight: FontWeight.w600, color: tab == current ? c.ember : c.textSecondary)),
                    ]),
                  ),
                ),
              ),
          ])),
        ),
      ),
    ));
  }
}
