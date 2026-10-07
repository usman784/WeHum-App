import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/errors/error_code.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/onboarding_store.dart';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');
bool isEmail(String v) => _emailRe.hasMatch(v.trim());

/// Password rule shown to the user (the API also rejects very common passwords).
String? passwordError(String v) => v.length < 8 ? 'At least 8 characters' : (v.length > 128 ? 'At most 128 characters' : null);

/// Friendly text for a failed account call. Never reveals whether an email exists (except on sign-up, where it must).
String accountErrorText(AccountFailed f) => switch (f.error.code) {
      ErrorCode.invalidCredentials => 'Email or password is wrong',
      ErrorCode.rateLimited => 'Too many attempts. Try again in a few minutes.',
      ErrorCode.network || ErrorCode.timeout => "You're offline. Check your connection and try again.",
      ErrorCode.validationFailed => f.error.message ?? 'Please check what you entered',
      ErrorCode.tokenInvalid => 'This link has expired or was already used',
      _ => 'Something went wrong. Please try again.',
    };

/// Shared by 13, 16 (save progress), 18 (log in) and the sheet 21.
class SocialFlowController extends GetxController {
  SocialFlowController({this.login = false});
  final bool login;
  final busy = RxnString();
  final error = RxnString();
  final existsProvider = RxnString();

  AccountService get _acct => Get.find<AccountService>();

  /// Returns true when the person is now signed in (so the caller can continue).
  Future<bool> continueWith(String provider) async {
    if (busy.value != null) return false;
    busy.value = provider;
    error.value = null;
    final r = login ? await _acct.loginSocial(provider) : await _acct.linkSocial(provider);
    busy.value = null;
    switch (r) {
      case AccountOk():
        return true;
      case AccountCancelled():
        return false;
      case AccountExists():
        existsProvider.value = provider; // → "You already have an account. Log in to bring your progress over."
        return false;
      case AccountFailed():
        error.value = accountErrorText(r);
        return false;
    }
  }

  /// "Log in" on the exists prompt: same provider, but as a login (merges this phone's data).
  Future<bool> loginAfterExists() async {
    final p = existsProvider.value;
    if (p == null) return false;
    existsProvider.value = null;
    busy.value = p;
    final r = await _acct.loginSocial(p);
    busy.value = null;
    if (r is AccountOk) return true;
    if (r is AccountFailed) error.value = accountErrorText(r);
    return false;
  }
}

/// 17 Sign up with email (link to the guest).
class EmailSignUpController extends GetxController {
  final first = ''.obs, email = ''.obs, password = ''.obs;
  final busy = false.obs;
  final submitted = false.obs;
  final error = RxnString();
  final exists = false.obs;

  String? get emailError => submitted.value && !isEmail(email.value) ? 'Enter a valid email address' : null;
  String? get passwordErr => submitted.value ? passwordError(password.value) : null;
  String? get firstError => submitted.value && first.value.trim().isEmpty ? 'Please enter your first name' : null;
  bool get valid => isEmail(email.value) && passwordError(password.value) == null && first.value.trim().isNotEmpty && first.value.trim().length <= 30;

  @override
  void onInit() {
    super.onInit();
    first.value = Get.find<OnboardingStore>().name;
  }

  Future<bool> submit() async {
    submitted.value = true;
    error.value = null;
    exists.value = false;
    if (!valid || busy.value) return false;
    busy.value = true;
    final r = await Get.find<AccountService>().linkEmail(email: email.value.trim().toLowerCase(), password: password.value, firstName: first.value.trim());
    busy.value = false;
    switch (r) {
      case AccountOk():
        Get.offNamed(AppRoutes.checkYourEmail, arguments: {'email': email.value.trim().toLowerCase(), 'purpose': 'verify'});
        return true;
      case AccountExists():
        exists.value = true;
      case AccountFailed():
        error.value = accountErrorText(r);
      case AccountCancelled():
        break;
    }
    return false;
  }
}

/// 18 Log in with email + password.
class EmailLoginController extends GetxController {
  final email = ''.obs, password = ''.obs;
  final busy = false.obs;
  final error = RxnString();

  Future<bool> submit() async {
    error.value = null;
    if (!isEmail(email.value) || password.value.isEmpty) {
      error.value = 'Enter your email and password';
      return false;
    }
    busy.value = true;
    final r = await Get.find<AccountService>().loginEmail(email: email.value.trim().toLowerCase(), password: password.value);
    busy.value = false;
    if (r is AccountOk) return true;
    if (r is AccountFailed) error.value = accountErrorText(r);
    return false;
  }
}

/// 19 Forgot password: always the same generic success (no account enumeration).
class ForgotController extends GetxController {
  final email = ''.obs;
  final busy = false.obs;
  final error = RxnString();

  Future<void> submit() async {
    error.value = null;
    if (!isEmail(email.value)) {
      error.value = 'Enter a valid email address';
      return;
    }
    busy.value = true;
    try {
      await Get.find<AccountService>().forgotPassword(email.value);
    } catch (_) {/* same message either way */}
    busy.value = false;
    Get.toNamed(AppRoutes.checkYourEmail, arguments: {'email': email.value.trim().toLowerCase(), 'purpose': 'reset'});
  }
}

/// 20 Check your email: resend with a 60 s cooldown (the API has the same cooldown).
class CheckEmailController extends GetxController {
  CheckEmailController(this.email, this.purpose);
  final String email, purpose; // reset | verify | magic
  final cooldown = 0.obs;
  final resent = false.obs;

  Future<void> resend() async {
    if (cooldown.value > 0) return;
    cooldown.value = 60;
    resent.value = true;
    try {
      final a = Get.find<AccountService>();
      purpose == 'reset' ? await a.forgotPassword(email) : await a.sendMagicLink(email);
    } catch (_) {}
    for (var i = 0; i < 60 && !isClosed; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (isClosed) return;
      cooldown.value = 59 - i;
    }
  }
}

/// New password after the reset link.
class ResetPasswordController extends GetxController {
  ResetPasswordController(this.token);
  final String token;
  final password = ''.obs;
  final busy = false.obs;
  final error = RxnString();
  final done = false.obs;

  Future<void> submit() async {
    final e = passwordError(password.value);
    if (e != null) {
      error.value = e;
      return;
    }
    busy.value = true;
    error.value = null;
    try {
      await Get.find<AccountService>().resetPassword(token, password.value);
      done.value = true;
    } catch (ex) {
      error.value = ex is Exception ? 'This link has expired or was already used' : 'Something went wrong';
    }
    busy.value = false;
  }
}

/// `https://wehum.app/auth/sign-in?token=` and `verify-email?token=`.
class AuthLinkController extends GetxController {
  AuthLinkController(this.kind, this.token);
  final String kind, token;
  final state = 'working'.obs; // working | ok | failed

  @override
  void onReady() {
    super.onReady();
    run();
  }

  Future<void> run() async {
    state.value = 'working';
    final a = Get.find<AccountService>();
    try {
      if (kind == 'verify-email') {
        await a.verifyEmail(token);
        state.value = 'ok';
        return;
      }
      final r = await a.verifyMagicLink(token);
      state.value = r is AccountOk ? 'ok' : 'failed';
    } catch (_) {
      state.value = 'failed';
    }
  }
}
