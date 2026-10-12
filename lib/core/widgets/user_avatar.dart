import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// A person's photo (uploaded or from Google), or their initial on a teal disc when there is none or it cannot load.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.initial = '', this.size = 44, this.fontSize});
  final String? url;
  final String initial;
  final double size;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fallback = Container(
      width: size, height: size, alignment: Alignment.center, decoration: BoxDecoration(color: c.teal, shape: BoxShape.circle),
      child: Text(initial.isEmpty ? '·' : initial, style: AppText.navTitle.copyWith(color: c.tealText, fontSize: fontSize ?? size * 0.36)),
    );
    if (url == null || url!.isEmpty) return fallback;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url!, width: size, height: size, fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        placeholder: (_, __) => fallback, errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}
