import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../theme/app_colors.dart';
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

/// Tab header: logo + SoS + bell (unread dot) + avatar.
class TabHeader extends StatelessWidget {
  const TabHeader({super.key, this.initials = '', this.unread = 0, this.onBell, this.onAvatar});
  final String initials;
  final int unread;
  final VoidCallback? onBell, onAvatar;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.gutter, 12, Gap.gutter, 8),
      child: Row(children: [
        Icon(Icons.track_changes_rounded, color: c.ember, size: 30),
        const SizedBox(width: 10),
        Text('WeHum', style: AppText.title.copyWith(color: c.textPrimary)),
        const Spacer(),
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
        Semantics(
          button: true, label: 'Profile',
          child: GestureDetector(
            onTap: onAvatar ?? () => Get.toNamed(AppRoutes.you),
            child: Container(width: Sizes.touch, height: Sizes.touch, alignment: Alignment.center, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle), child: Text(initials.isEmpty ? '·' : initials, style: AppText.navTitle.copyWith(color: c.tealText, fontSize: 15))),
          ),
        ),
      ]),
    );
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
    return SafeArea(
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
    );
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({super.key, required this.body, this.title, this.action, this.header, this.bottom, this.banner, this.resize = true});
  final Widget body;
  final String? title;
  final Widget? action;
  /// Replaces the sub header (e.g. [TabHeader]).
  final Widget? header;
  final Widget? bottom;
  final Widget? banner;
  final bool resize;

  @override
  Widget build(BuildContext context) => Scaffold(
        resizeToAvoidBottomInset: resize,
        bottomNavigationBar: bottom,
        body: SafeArea(
          bottom: bottom == null,
          child: Column(children: [
            if (header != null) header! else if (title != null) SubHeader(title: title!, action: action),
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
    return Container(
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
    );
  }
}
