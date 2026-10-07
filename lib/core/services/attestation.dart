import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import '../config/env.dart';

/// Proof that this is a real install of the real app (App Attest on iOS, Play Integrity on Android), bound to a
/// one-time server [challenge]. Sent with `POST /v1/auth/guest`; the server decides what to do with it (spec §P10).
abstract class AttestationProvider {
  /// The body fragment for the guest call, or null when the device can't attest (simulator, no Play Services).
  Future<Map<String, dynamic>?> prove(String challenge);
}

class PlatformAttestation implements AttestationProvider {
  PlatformAttestation([MethodChannel? channel]) : _ch = channel ?? const MethodChannel('app.wehum/attest');
  final MethodChannel _ch;

  @override
  Future<Map<String, dynamic>?> prove(String challenge) async {
    try {
      if (Platform.isIOS) {
        final r = await _ch.invokeMapMethod<String, String>('attest', {'challenge': challenge});
        if (r == null) return null;
        return {'challenge': challenge, 'keyId': r['keyId'], 'object': r['object']};
      }
      if (Platform.isAndroid) {
        if (Env.playIntegrityProject.isEmpty) return null;
        final token = await _ch.invokeMethod<String>('integrity', {'challenge': challenge, 'project': int.tryParse(Env.playIntegrityProject)});
        return token == null ? null : {'challenge': challenge, 'token': token};
      }
    } on PlatformException {
      return null; // unsupported device: the server's mode (monitor/enforce) decides
    } on MissingPluginException {
      return null;
    }
    return null;
  }
}

/// No attestation (tests, mocks).
class NoAttestation implements AttestationProvider {
  @override
  Future<Map<String, dynamic>?> prove(String challenge) async => null;
}
