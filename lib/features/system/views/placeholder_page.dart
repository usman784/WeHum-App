import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';

/// Stand-in for a screen that a later phase builds. Shows the route key so navigation can be checked end to end.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage(this.name, {super.key});
  final String name;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: context.colors.textPrimary),
        body: Center(child: Text(name, key: const Key('placeholder-name'), style: AppText.title.copyWith(color: context.colors.textSecondary))),
      );
}
