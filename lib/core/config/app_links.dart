import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// External links (terms, privacy, store management). Not prices, not copy that the CMS controls.
abstract final class AppLinks {
  static const supportEmail = 'raphael@raphaelreiter.com';
  static const terms = 'https://wehum.app/terms';
  static const privacy = 'https://wehum.app/privacy';
  static const support = 'mailto:$supportEmail';
  static const faq = 'https://wehum.app/faq';
  static const appStoreSubscriptions = 'https://apps.apple.com/account/subscriptions';
  static const playSubscriptions = 'https://play.google.com/store/account/subscriptions';
  static const iosStore = 'https://apps.apple.com/app/id0000000000';
  static const androidStore = 'https://play.google.com/store/apps/details?id=app.wehum.meditation';

  /// "Contact us": opens the mail app addressed to Raphael. A phone without a mail account gets the address copied instead.
  static Future<void> emailSupport() async {
    var ok = false;
    try {
      ok = await launchUrl(Uri(scheme: 'mailto', path: supportEmail), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(const ClipboardData(text: supportEmail));
      Get.snackbar('WeHum', 'No mail app found. The address $supportEmail was copied.', snackPosition: SnackPosition.BOTTOM);
    }
  }
}
