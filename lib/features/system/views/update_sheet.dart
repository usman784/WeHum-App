import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_links.dart';
import '../../../core/data/models/bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';

/// "A new version is available": dismissible, shown once per version. The store link comes from the server
/// (`bootstrap.update.storeUrl`) so it can be fixed without a release; the built-in link is the fallback.
Future<void> showUpdateSheet(BuildContext context, AppUpdate u, {required VoidCallback onLater}) async {
  final go = await showAppSheet<bool>(context, title: 'A new version is ready', builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('WeHum ${u.latest ?? ''} has fixes and improvements. Update when you like. Your progress and downloads stay as they are.', style: AppText.body.copyWith(color: ctx.colors.textSecondary)),
        const SizedBox(height: 16),
        PrimaryButton('Update', key: const Key('update-now'), onPressed: () => Navigator.of(ctx).pop(true)),
        TextLink('Later', key: const Key('update-later'), onPressed: () => Navigator.of(ctx).pop(false)),
      ]));
  if (go == true) {
    final url = u.storeUrl ?? (Platform.isIOS ? AppLinks.iosStore : AppLinks.androidStore);
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } else {
    onLater();
  }
}
