import 'package:get/get.dart';
import '../data/contracts/auth_repository.dart';
import '../data/contracts/repositories.dart';
import '../data/models/session.dart';
import '../errors/error_code.dart';
import '../network/api_client.dart';
import '../realtime/socket_service.dart';
import 'access_service.dart';
import 'analytics_service.dart';
import 'auth_service.dart';
import 'config_service.dart';
import 'notification_service.dart';
import 'purchase_service.dart';
import 'social_auth_service.dart';

sealed class AccountResult {
  const AccountResult();
}

class AccountOk extends AccountResult {
  const AccountOk(this.me, {this.merged = false});
  final Me me;
  final bool merged;
}

class AccountCancelled extends AccountResult {
  const AccountCancelled();
}

/// The email / social identity already has an account: log in to bring this phone's progress over.
class AccountExists extends AccountResult {
  const AccountExists(this.provider, this.mergeToken);
  final String provider;
  final String? mergeToken;
}

class AccountFailed extends AccountResult {
  const AccountFailed(this.error);
  final ApiException error;
}

/// Account flows (spec §9, §12 rows 3 and 8): link Apple/Google/email to the guest, log in, merge, sign out.
/// Keeps purchases, push registration and the socket consistent whenever the signed-in user changes.
class AccountService extends GetxService {
  AccountService({
    required this.auth, required this.repo, required this.social, required this.access, required this.purchases, required this.config,
    required this.me, required this.socket, required this.notifications, required this.analytics,
  });
  final AuthService auth;
  final AuthRepository repo;
  final SocialAuth social;
  final AccessService access;
  final PurchaseService purchases;
  final ConfigService config;
  final MeRepository me;
  final SocketService socket;
  final NotificationService notifications;
  final AnalyticsService analytics;

  Future<SocialCredential> _credential(String provider) => provider == 'apple' ? social.apple() : social.google();

  /// "Save your progress": attach to the current guest. Existing account → [AccountExists].
  Future<AccountResult> linkSocial(String provider) async {
    try {
      final c = await _credential(provider);
      final s = await repo.linkSocial(provider, c.idToken, firstName: c.firstName);
      return _done(s, provider);
    } on SocialAuthCancelled {
      return const AccountCancelled();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<AccountResult> linkEmail({required String email, required String password, String? firstName}) async {
    try {
      return _done(await repo.linkEmail(email: email, password: password, firstName: firstName), 'email');
    } catch (e) {
      return _fail(e, provider: 'email');
    }
  }

  /// Log in with Google/Apple. A guest's data is merged into the account automatically.
  Future<AccountResult> loginSocial(String provider) async {
    try {
      final c = await _credential(provider);
      return _done(await repo.social(provider, c.idToken, firstName: c.firstName), provider, login: true);
    } on SocialAuthCancelled {
      return const AccountCancelled();
    } catch (e) {
      return _fail(e);
    }
  }

  Future<AccountResult> loginEmail({required String email, required String password}) async {
    try {
      return _done(await repo.emailLogin(email: email, password: password), 'email', login: true);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<AccountResult> verifyMagicLink(String token) async {
    try {
      return _done(await repo.verifyMagicLink(token), 'email', login: true);
    } catch (e) {
      return _fail(e);
    }
  }

  Future<void> forgotPassword(String email) => repo.forgotPassword(email.trim().toLowerCase());
  Future<void> sendMagicLink(String email) => repo.sendMagicLink(email.trim().toLowerCase());
  Future<void> resetPassword(String token, String password) => repo.resetPassword(token: token, password: password);
  Future<void> verifyEmail(String token) => repo.verifyEmail(token);

  /// Common tail of every successful sign-in: new session → merge guest data → RevenueCat id → profile, bootstrap,
  /// socket and push registration for the (possibly new) user.
  Future<AccountResult> _done(AuthSession s, String provider, {bool login = false}) async {
    final user = auth.applySession(s);
    var merged = false;
    if (s.mergeToken != null) {
      try {
        await repo.merge(s.mergeToken!); // the account's token is active now; moves the guest's meditations and stats
        merged = true;
      } catch (_) {/* the token lives 15 minutes; the guest data is not lost, the next login offers it again */}
    }
    await purchases.logIn(user.id); // purchases stay attached (same id on link) or transfer (merge)
    access.isGuest.value = user.isGuest; // the session already says it; the profile refresh below confirms
    access.hasAccount.value = !user.isGuest;
    await _refreshWorld(user.isGuest);
    analytics.track('account_link', {'provider': provider});
    return AccountOk(user, merged: merged);
  }

  Future<void> _refreshWorld(bool stillGuest) async {
    try {
      final p = await me.me();
      access.setFromProfile(p);
      if (!stillGuest) {
        access.isGuest.value = false;
        access.hasAccount.value = true;
      }
      await config.refresh();
    } catch (_) {}
    await socket.disconnect(); // the socket handshake carries the access token: reconnect as the new user
    await socket.connect();
    notifications.registerDevice();
  }

  AccountResult _fail(Object e, {String? provider}) {
    final a = ApiClient.map(e);
    if (a.code == ErrorCode.accountExists) {
      final d = a.details is Map ? (a.details as Map) : const {};
      return AccountExists((d['provider'] ?? provider ?? '') as String, d['mergeToken'] as String?);
    }
    return AccountFailed(a);
  }

  /// Sign out: the server drops the device token and the push topic; this phone also gets a fresh push token,
  /// Firebase/RevenueCat are cleared, and a new guest is created. Downloads stay (spec §10).
  Future<void> signOut() async {
    await auth.signOut();
    await notifications.onSignedOut();
    await purchases.signedOut();
    await social.signOut();
    await socket.disconnect();
    access.sdkPremium.value = false;
    final p = await me.me().catchError((_) => auth.profileFallback());
    access.setFromProfile(p);
    await socket.connect();
  }
}
