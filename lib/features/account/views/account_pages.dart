import 'package:flutter/material.dart';
import '../../../core/widgets/flex_scroll.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../controllers/account_controllers.dart';
import 'account_widgets.dart';

/// 13 (member) and 16 (free): "Save your progress".
class SaveProgressPage extends StatelessWidget {
  const SaveProgressPage({super.key, required this.free});
  final bool free;

  @override
  Widget build(BuildContext context) {
    final flow = Get.put(SocialFlowController(), tag: free ? 'save-free' : 'save');
    final c = context.colors;
    return AppScaffold(
      title: '', action: TextLink('Not now', onPressed: () => Get.offAllNamed(todayRoute()), color: c.textSecondary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gap.gutterOnboarding, 8, Gap.gutterOnboarding, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(free ? 'FREE · OPTIONAL' : 'OPTIONAL', style: AppText.overline.copyWith(color: c.emberText)),
          const SizedBox(height: 10),
          Text('Save your progress', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Text(free ? 'You can keep using the free meditations without an account. A free account lets you:' : 'Your membership already works on this phone. A free account lets you:', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          if (free) ...const [Benefit('Keep your progress and minutes safe'), Benefit('Pick up on another phone')] else ...const [Benefit('Keep your progress if you change phones'), Benefit('Use WeHum on iPhone and Android'), Benefit('Post dedications')],
          const SizedBox(height: 24),
          SocialButtons(flow: flow, onSuccess: () => Get.offAllNamed(todayRoute()), onEmail: () => Get.toNamed(AppRoutes.signUpWithEmail)),
          const SizedBox(height: 16),
          const Center(child: LegalLine()),
          const SizedBox(height: 12),
          Center(child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Already have an account? ', style: AppText.bodySmall.copyWith(color: c.textSecondary)), TextLink('Log in', onPressed: () => Get.toNamed(AppRoutes.logIn))])),
        ]),
      ),
    );
  }
}

/// 17 Sign up with email.
class EmailSignUpPage extends StatelessWidget {
  const EmailSignUpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EmailSignUpController());
    final c = context.colors;
    return AppScaffold(
      title: 'Sign up with email',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.gutterOnboarding),
        child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AppField(label: 'First name', fieldKey: const Key('su-first'), initial: ctrl.first.value, onChanged: (v) => ctrl.first.value = v, error: ctrl.firstError, caps: TextCapitalization.words, action: TextInputAction.next),
              const SizedBox(height: 14),
              AppField(label: 'Email', fieldKey: const Key('su-email'), onChanged: (v) => ctrl.email.value = v, error: ctrl.emailError, keyboard: TextInputType.emailAddress, action: TextInputAction.next, autofill: const [AutofillHints.email]),
              const SizedBox(height: 14),
              AppField(label: 'Password', fieldKey: const Key('su-password'), obscure: true, onChanged: (v) => ctrl.password.value = v, error: ctrl.passwordErr, action: TextInputAction.done, onSubmit: ctrl.submit, autofill: const [AutofillHints.newPassword]),
              const SizedBox(height: 20),
              if (ctrl.exists.value)
                Container(
                  key: const Key('su-exists'), padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: c.infoBg, borderRadius: BorderRadius.circular(Radii.tile)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('This email already has an account.', style: AppText.navTitle.copyWith(color: c.infoText)),
                    const SizedBox(height: 4),
                    Text('Log in to bring this phone’s progress over.', style: AppText.bodySmall.copyWith(color: c.infoText)),
                    TextLink('Log in', onPressed: () => Get.offNamed(AppRoutes.logIn)),
                  ]),
                ),
              if (ctrl.error.value != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(ctrl.error.value!, style: AppText.bodySmall.copyWith(color: c.dangerText))),
              PrimaryButton('Create account', loading: ctrl.busy.value, onPressed: ctrl.submit),
              const SizedBox(height: 12),
              Center(child: Text('We’ll send a link to confirm your email.', style: AppText.caption.copyWith(color: c.textSecondary))),
            ])),
      ),
    );
  }
}

/// 18 Log in.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final flow = Get.put(SocialFlowController(login: true), tag: 'login');
    final ctrl = Get.put(EmailLoginController());
    final c = context.colors;
    void done() => Get.offAllNamed(todayRoute());
    return AppScaffold(
      title: 'Log in',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.gutterOnboarding),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Welcome back', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 20),
          SocialButtons(flow: flow, onSuccess: done),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: Divider(color: c.border)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('OR', style: AppText.overline.copyWith(color: c.textTertiary))), Expanded(child: Divider(color: c.border))]),
          const SizedBox(height: 16),
          AppField(label: 'Email', fieldKey: const Key('li-email'), onChanged: (v) => ctrl.email.value = v, keyboard: TextInputType.emailAddress, action: TextInputAction.next, autofill: const [AutofillHints.email]),
          const SizedBox(height: 14),
          AppField(label: 'Password', fieldKey: const Key('li-password'), obscure: true, onChanged: (v) => ctrl.password.value = v, action: TextInputAction.done, autofill: const [AutofillHints.password], onSubmit: () async => await ctrl.submit() ? done() : null),
          Align(alignment: Alignment.centerRight, child: TextLink('Forgot password?', onPressed: () => Get.toNamed(AppRoutes.forgotPassword))),
          Obx(() => ctrl.error.value == null ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(ctrl.error.value!, key: const Key('li-error'), style: AppText.bodySmall.copyWith(color: c.dangerText)))),
          Obx(() => PrimaryButton('Log in', loading: ctrl.busy.value, onPressed: () async => await ctrl.submit() ? done() : null)),
          const SizedBox(height: 16),
          Center(child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('New to WeHum? ', style: AppText.bodySmall.copyWith(color: c.textSecondary)), TextLink('Create an account', onPressed: () => Get.toNamed(AppRoutes.signUpWithEmail))])),
        ]),
      ),
    );
  }
}

/// 19 Forgot password.
class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ForgotController());
    final c = context.colors;
    return AppScaffold(
      title: 'Forgot password',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.gutterOnboarding),
        child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Reset your password', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 10),
              Text('Enter the email you signed up with. We’ll send you a link to set a new password.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 24),
              AppField(label: 'Email', fieldKey: const Key('fp-email'), onChanged: (v) => ctrl.email.value = v, error: ctrl.error.value, keyboard: TextInputType.emailAddress, action: TextInputAction.done, onSubmit: ctrl.submit),
              const SizedBox(height: 20),
              PrimaryButton('Send reset link', loading: ctrl.busy.value, onPressed: ctrl.submit),
            ])),
      ),
    );
  }
}

/// 20 Check your email.
class CheckEmailPage extends StatelessWidget {
  const CheckEmailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = (Get.arguments as Map?) ?? const {};
    final email = (args['email'] ?? '') as String;
    final ctrl = Get.put(CheckEmailController(email, (args['purpose'] ?? 'reset') as String));
    final c = context.colors;
    return AppScaffold(
      title: 'Check your email',
      body: FlexScroll(padding: const EdgeInsets.all(Gap.gutterOnboarding), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Center(child: Icon(Icons.mark_email_unread_outlined, size: 64, color: c.ember)),
          const SizedBox(height: 20),
          Text('Check your email', textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Text('We sent a link to $email. Tap the link in that email to finish.', key: const Key('check-body'), textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 28),
          PrimaryButton('Open email app', onPressed: () => launchUrl(Uri.parse('message://'), mode: LaunchMode.externalApplication).catchError((_) => launchUrl(Uri.parse('mailto:')))),
          const SizedBox(height: 8),
          Center(child: TextLink('Back to log in', onPressed: () => Get.offAllNamed(AppRoutes.logIn), color: c.textSecondary)),
          const Spacer(),
          Obx(() => Center(
                child: ctrl.cooldown.value > 0
                    ? Text('Send again in ${ctrl.cooldown.value} s', key: const Key('resend-wait'), style: AppText.bodySmall.copyWith(color: c.textTertiary))
                    : Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [Text('Didn’t get it? ', style: AppText.bodySmall.copyWith(color: c.textSecondary)), TextLink('Send again', onPressed: ctrl.resend)]),
              )),
        ]),
      ),
    );
  }
}

/// 21 Account needed to post (sheet). Returns true when the person signed in.
Future<bool> showAccountGate(BuildContext context) async {
  final flow = Get.put(SocialFlowController(), tag: 'gate');
  final ok = await showAppSheet<bool>(context, title: 'Add your name to post', builder: (ctx) {
    final c = ctx.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Dedications are shown with your first name, so posting needs an account. It takes one tap and your membership moves with you.', style: AppText.body.copyWith(color: c.textBody)),
      const SizedBox(height: 20),
      SocialButtons(flow: flow, onSuccess: () => Navigator.of(ctx).pop(true), onEmail: () {
        Navigator.of(ctx).pop(false);
        Get.toNamed(AppRoutes.signUpWithEmail);
      }),
      const SizedBox(height: 8),
      Center(child: TextLink('Not now', onPressed: () => Navigator.of(ctx).pop(false), color: c.textSecondary)),
    ]);
  });
  return ok == true;
}

/// New password after the reset link.
class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key});
  @override
  Widget build(BuildContext context) {
    final token = ((Get.arguments as Map?)?['token'] ?? '') as String;
    final ctrl = Get.put(ResetPasswordController(token));
    final c = context.colors;
    return AppScaffold(
      title: 'New password',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.gutterOnboarding),
        child: Obx(() => ctrl.done.value
            ? Column(children: [
                const SizedBox(height: 40),
                Icon(Icons.check_circle_outline_rounded, size: 64, color: c.success),
                const SizedBox(height: 16),
                Text('Password updated', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 8),
                Text('You were signed out everywhere. Log in with your new password.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
                const SizedBox(height: 24),
                PrimaryButton('Log in', onPressed: () => Get.offAllNamed(AppRoutes.logIn)),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Choose a new password', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 20),
                AppField(label: 'New password', fieldKey: const Key('rp-password'), obscure: true, onChanged: (v) => ctrl.password.value = v, error: ctrl.error.value, onSubmit: ctrl.submit, autofill: const [AutofillHints.newPassword]),
                const SizedBox(height: 20),
                PrimaryButton('Save password', loading: ctrl.busy.value, onPressed: ctrl.submit),
              ])),
      ),
    );
  }
}

/// Email links: sign in with the link / confirm the address.
class AuthLinkPage extends StatelessWidget {
  const AuthLinkPage({super.key});
  @override
  Widget build(BuildContext context) {
    final a = (Get.arguments as Map?) ?? const {};
    final ctrl = Get.put(AuthLinkController((a['kind'] ?? 'sign-in') as String, (a['token'] ?? '') as String));
    final c = context.colors;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Obx(() {
            switch (ctrl.state.value) {
              case 'working':
                return const CircularProgressIndicator();
              case 'ok':
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_outline_rounded, size: 64, color: c.success),
                  const SizedBox(height: 16),
                  Text(ctrl.kind == 'verify-email' ? 'Email confirmed' : 'You’re signed in', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 24),
                  PrimaryButton('Go to Today', key: const Key('auth-link-continue'), onPressed: () => Get.offAllNamed(todayRoute()), fullWidth: false),
                ]);
              default:
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.error_outline_rounded, size: 64, color: c.textTertiary),
                  const SizedBox(height: 16),
                  Text('This link has expired', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Links work once and for a short time. Request a new one.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 24),
                  PrimaryButton('Back to log in', onPressed: () => Get.offAllNamed(AppRoutes.logIn), fullWidth: false),
                ]);
            }
          }),
        ),
      ),
    );
  }
}

/// Test hook.
Future<bool> showAccountGateForTest(BuildContext c) => showAccountGate(c);
