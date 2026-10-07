import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// What the app needs from a provider: the Firebase id token our API verifies, plus Apple's first-login name.
class SocialCredential {
  const SocialCredential({required this.provider, required this.idToken, this.firstName});
  final String provider; // google | apple
  final String idToken;
  final String? firstName;
}

class SocialAuthCancelled implements Exception {
  @override
  String toString() => 'SocialAuthCancelled';
}

/// Google / Apple sign-in through Firebase Auth (decision 2026-10-07). The Firebase id token is sent to `/v1/auth/*`;
/// our API verifies it and issues its own session. Firebase itself is signed out again straight away: our API is the
/// source of truth for who the user is, so no Firebase session lingers on the phone.
abstract class SocialAuth {
  Future<SocialCredential> google();
  Future<SocialCredential> apple();
  Future<void> signOut();
}

class FirebaseSocialAuth extends GetxService implements SocialAuth {
  // The Firebase "web" OAuth client (type 3 in google-services.json): needed to receive an id token on Android.
  static const serverClientId = '717113097844-7grv4tr0q2q89068qcjdp2dj8s1m1a3s.apps.googleusercontent.com';
  bool _googleReady = false;

  @override
  Future<SocialCredential> google() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
        _googleReady = true;
      }
      final acct = await GoogleSignIn.instance.authenticate();
      final idToken = acct.authentication.idToken;
      if (idToken == null) throw StateError('Google returned no id token');
      final cred = await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      final fb = await cred.user!.getIdToken(true);
      final name = acct.displayName?.split(' ').first;
      await signOut();
      return SocialCredential(provider: 'google', idToken: fb!, firstName: name);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw SocialAuthCancelled();
      rethrow;
    }
  }

  @override
  Future<SocialCredential> apple() async {
    final raw = _nonce();
    try {
      final apple = await SignInWithApple.getAppleIDCredential(scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName], nonce: sha256.convert(utf8.encode(raw)).toString());
      final cred = await FirebaseAuth.instance.signInWithCredential(OAuthProvider('apple.com').credential(idToken: apple.identityToken, rawNonce: raw));
      final fb = await cred.user!.getIdToken(true);
      await signOut();
      return SocialCredential(provider: 'apple', idToken: fb!, firstName: apple.givenName); // Apple sends the name only the first time
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw SocialAuthCancelled();
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {/* nothing to sign out */}
  }

  static String _nonce([int len = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
