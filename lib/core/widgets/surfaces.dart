import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Gap.x16), this.color, this.radius = Radii.card, this.outlined = false, this.semanticLabel});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final bool outlined;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Material(
      color: outlined ? Colors.transparent : (color ?? c.surface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: c.border)),
      child: InkWell(customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)), onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return onTap == null ? card : Semantics(button: true, label: semanticLabel, child: card);
  }
}

/// Image with a blurhash placeholder; bundled `assets/…` paths and network URLs both work.
class ThumbImage extends StatelessWidget {
  const ThumbImage(this.src, {super.key, this.blurHash, this.width, this.height, this.radius = 0, this.fit = BoxFit.cover});
  final String? src, blurHash;
  final double? width, height, radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = ColoredBox(color: c.surfaceAlt);
    Widget img;
    if (src == null || src!.isEmpty) {
      img = fallback;
    } else if (src!.startsWith('assets/')) {
      img = Image.asset(src!, fit: fit, width: width, height: height, excludeFromSemantics: true, errorBuilder: (_, __, ___) => fallback);
    } else {
      img = CachedNetworkImage(
        imageUrl: src!, fit: fit, width: width, height: height,
        placeholder: (_, __) => blurHash != null ? BlurHash(hash: blurHash!) : fallback,
        errorWidget: (_, __, ___) => fallback, fadeInDuration: Motion.state,
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius ?? 0), child: SizedBox(width: width, height: height, child: img));
  }
}

/// Image + gradient + content (Today hero, MOTD room, program cards).
class HeroImageCard extends StatelessWidget {
  const HeroImageCard({super.key, required this.image, required this.child, this.height, this.onTap, this.radius = Radii.cardLarge, this.blurHash});
  final String? image, blurHash;
  final Widget child;
  final double? height;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final body = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(children: [
        Positioned.fill(child: ThumbImage(image, blurHash: blurHash)),
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: AppColors.imageGradient))),
        Padding(padding: const EdgeInsets.all(Gap.x20), child: ConstrainedBox(constraints: BoxConstraints(minHeight: ((height ?? 0) - 2 * Gap.x20).clamp(0.0, double.infinity)), child: child)),
      ]),
    );
    // `height` is a minimum: at large text sizes the card grows with its content instead of overflowing
    final sized = height == null ? body : ConstrainedBox(constraints: BoxConstraints(minHeight: height!), child: body);
    return onTap == null ? sized : GestureDetector(onTap: onTap, child: sized);
  }
}

/// Icon tile + title + subtitle + trailing chevron/badge/play.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap, this.showChevron = true, this.destructive = false});
  final String title;
  final String? subtitle;
  final Widget? leading, trailing;
  final VoidCallback? onTap;
  final bool showChevron, destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null, label: subtitle == null ? title : '$title, $subtitle',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: destructive ? c.dangerText : c.textPrimary)),
                  if (subtitle != null) Text(subtitle!, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
                ]),
              ),
              if (trailing != null) trailing!,
              if (showChevron && onTap != null) Icon(Icons.chevron_right_rounded, color: c.textSecondary),
            ]),
          ),
        ),
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.size = 44, this.tint});
  final IconData icon;
  final double size;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: size, height: size, decoration: BoxDecoration(color: tint ?? c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.input)),
      child: Icon(icon, size: size * .5, color: c.emberText),
    );
  }
}

enum BadgeKind { premium, comingSoon, live, freeForYou, video, audio }

class AppBadge extends StatelessWidget {
  const AppBadge(this.kind, {super.key, this.label});
  final BadgeKind kind;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (text, bg, fg) = switch (kind) {
      BadgeKind.premium => ('PREMIUM', c.emberTint, c.emberText),
      BadgeKind.comingSoon => ('COMING SOON', c.surfaceAlt, c.textSecondary),
      BadgeKind.live => ('LIVE', c.success.withValues(alpha: .18), c.success),
      BadgeKind.freeForYou => ('FREE FOR YOU', c.tealSoft.withValues(alpha: .18), c.tealText),
      BadgeKind.video => ('VIDEO', c.infoBg, c.infoText),
      BadgeKind.audio => ('AUDIO', c.surfaceAlt, c.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
      child: Text(label ?? text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: AppText.badge.copyWith(color: fg)),
    );
  }
}

/// Dot + text. Busy (green) / quiet (grey) per the empty-room rule; paused shows "Live counts paused".
class LivePill extends StatelessWidget {
  const LivePill({super.key, required this.text, this.quiet = false, this.onTap});
  final String text;
  final bool quiet;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: text, button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: c.bgDeep.withValues(alpha: .7), borderRadius: BorderRadius.circular(Radii.pill)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: quiet ? c.textTertiary : c.success, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Flexible(child: Text(text, style: AppText.bodySmall.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}

/// Progress, no streak semantics.
class AppProgressBar extends StatelessWidget {
  const AppProgressBar(this.value, {super.key, this.height = 6});
  final double value;
  final double height;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      value: '${(value * 100).round()} percent',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.pill),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: height, backgroundColor: c.track, color: c.ember),
      ),
    );
  }
}

/// Days meditated this week. Filled = meditated; no streak or rest-day meaning.
class WeekDots extends StatelessWidget {
  const WeekDots({super.key, required this.done, this.labels = const ['M', 'T', 'W', 'T', 'F', 'S', 'S']});
  final List<bool> done;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '${done.where((d) => d).length} of 7 days meditated this week',
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 7; i++)
          Column(children: [
            Container(width: 28, height: 28, decoration: BoxDecoration(color: done[i] ? c.ember : c.track, shape: BoxShape.circle)),
            const SizedBox(height: 6),
            Text(labels[i], style: AppText.micro.copyWith(color: c.textSecondary)),
          ]),
      ]),
    );
  }
}
