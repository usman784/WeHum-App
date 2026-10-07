import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';

/// Bottom sheet with a grabber and optional title; scrim is `bgDeep` (spec §8).
Future<T?> showAppSheet<T>(BuildContext context, {String? title, required WidgetBuilder builder, bool scrollable = true}) {
  final c = context.colors;
  return showModalBottomSheet<T>(
    context: context, isScrollControlled: scrollable, backgroundColor: c.surface, barrierColor: c.overlayScrim,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Gap.gutter, 12, Gap.gutter, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.borderOutline, borderRadius: BorderRadius.circular(2)))),
          if (title != null) ...[const SizedBox(height: 16), Text(title, style: AppText.title.copyWith(color: c.textPrimary))],
          const SizedBox(height: 16),
          Flexible(child: SingleChildScrollView(child: builder(ctx))),
        ]),
      ),
    ),
  );
}
