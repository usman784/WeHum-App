import 'package:flutter/material.dart';

/// A column that fills the screen (so `Spacer`s still push things apart) but scrolls when the content is taller,
/// e.g. at 200 % text size (spec §15). Use for centred / bottom-anchored layouts.
class FlexScroll extends StatelessWidget {
  const FlexScroll({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child; // usually a Column with Spacers
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(constraints: BoxConstraints(minHeight: box.maxHeight - padding.vertical), child: IntrinsicHeight(child: child)),
        ),
      );
}

/// Two-column (or n-column) grid whose rows are as tall as their content needs at the current text size.
class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({super.key, required this.children, this.columns = 2, this.baseExtent = 96, this.spacing = 10});
  final List<Widget> children;
  final int columns;
  /// Row height at text scale 1.0; grows with the text scale.
  final double baseExtent;
  final double spacing;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.2);
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: children.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: spacing, crossAxisSpacing: spacing, mainAxisExtent: baseExtent * scale),
      itemBuilder: (_, i) => children[i],
    );
  }
}

/// Chrome (headers, tab bar) stays usable at huge text sizes: it grows, but never past 1.3×.
class ClampedText extends StatelessWidget {
  const ClampedText({super.key, required this.child, this.max = 1.3});
  final Widget child;
  final double max;
  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(maxScaleFactor: max, child: child);
}
