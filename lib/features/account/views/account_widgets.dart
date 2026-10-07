import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/services/access_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../controllers/account_controllers.dart';

/// Where to go after signing in: Today for members, Today (free) otherwise.
String todayRoute() => Get.find<AccessService>().isMember ? AppRoutes.todayMember : AppRoutes.todayFree;

/// Apple / Google / email. Apple only on iOS (on Android it needs a web flow that is not set up).
class SocialButtons extends StatelessWidget {
  const SocialButtons({super.key, required this.flow, required this.onSuccess, this.onEmail, this.emailLabel = 'Continue with email'});
  final SocialFlowController flow;
  final VoidCallback onSuccess;
  final VoidCallback? onEmail;
  final String emailLabel;

  Future<void> _go(BuildContext context, String provider) async {
    if (await flow.continueWith(provider)) onSuccess();
    if (flow.existsProvider.value != null && context.mounted) {
      final login = await showAppSheet<bool>(context, title: 'You already have an account', builder: (ctx) {
        final c = ctx.colors;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('This ${provider == 'apple' ? 'Apple' : 'Google'} account is already registered. Log in to bring your progress over.', style: AppText.body.copyWith(color: c.textBody)),
          const SizedBox(height: 20),
          PrimaryButton('Log in and keep my progress', onPressed: () => Navigator.of(ctx).pop(true)),
          const SizedBox(height: 8),
          TextLink('Cancel', onPressed: () => Navigator.of(ctx).pop(false), color: c.textSecondary),
        ]);
      });
      if (login == true && await flow.loginAfterExists()) onSuccess();
      flow.existsProvider.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (Platform.isIOS) ...[
            _SocialBtn(key: const Key('btn-apple'), label: 'Continue with Apple', icon: Icons.apple, loading: flow.busy.value == 'apple', onTap: flow.busy.value == null ? () => _go(context, 'apple') : null),
            const SizedBox(height: 10),
          ],
          _SocialBtn(key: const Key('btn-google'), label: 'Continue with Google', icon: Icons.g_mobiledata_rounded, loading: flow.busy.value == 'google', onTap: flow.busy.value == null ? () => _go(context, 'google') : null),
          if (onEmail != null) ...[const SizedBox(height: 10), _SocialBtn(key: const Key('btn-email'), label: emailLabel, icon: Icons.mail_outline_rounded, onTap: onEmail)],
          if (flow.error.value != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(flow.error.value!, key: const Key('social-error'), style: AppText.bodySmall.copyWith(color: c.dangerText))),
        ]));
  }
}

class _SocialBtn extends StatelessWidget {
  const _SocialBtn({super.key, required this.label, required this.icon, this.onTap, this.loading = false});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  @override
  Widget build(BuildContext context) => OutlineButton(label, icon: icon, onPressed: onTap, loading: loading, height: Sizes.primaryButton);
}

class LegalLine extends StatelessWidget {
  const LegalLine({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = AppText.caption.copyWith(color: c.textSecondary);
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('By continuing you agree to the ', style: s),
      GestureDetector(onTap: () => launchUrl(Uri.parse(AppLinks.terms)), child: Text('Terms', style: s.copyWith(color: c.textPrimary, decoration: TextDecoration.underline))),
      Text(' and ', style: s),
      GestureDetector(onTap: () => launchUrl(Uri.parse(AppLinks.privacy)), child: Text('Privacy Policy', style: s.copyWith(color: c.textPrimary, decoration: TextDecoration.underline))),
      Text('.', style: s),
    ]);
  }
}

class Benefit extends StatelessWidget {
  const Benefit(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.check_rounded, size: 20, color: c.tealText),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: AppText.bodyLarge.copyWith(color: c.textBody))),
      ]),
    );
  }
}

/// Labelled field with an inline error.
class AppField extends StatelessWidget {
  const AppField({super.key, required this.label, required this.onChanged, this.error, this.obscure = false, this.keyboard, this.fieldKey, this.initial, this.action, this.onSubmit, this.autofill, this.caps = TextCapitalization.none});
  final String label;
  final ValueChanged<String> onChanged;
  final String? error, initial;
  final bool obscure;
  final TextInputType? keyboard;
  final Key? fieldKey;
  final TextInputAction? action;
  final VoidCallback? onSubmit;
  final Iterable<String>? autofill;
  final TextCapitalization caps;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TextFormField(
      key: fieldKey, initialValue: initial, obscureText: obscure, keyboardType: keyboard, onChanged: onChanged, textInputAction: action, autofillHints: autofill, textCapitalization: caps,
      onFieldSubmitted: (_) => onSubmit?.call(), style: AppText.bodyLarge.copyWith(color: c.textPrimary),
      decoration: InputDecoration(
        labelText: label, errorText: error, filled: true, fillColor: c.surfaceInput,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)),
      ),
    );
  }
}
