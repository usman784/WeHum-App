import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../config/env.dart';

/// Instagram "Share to Stories": hands a PNG to the Instagram app on the phone (no Instagram login, no API).
/// - With our Meta App ID (`source_application`): straight into the story composer (iOS pasteboard +
///   `instagram-stories://share`; Android `com.instagram.share.ADD_TO_STORY`).
/// - Without it, on Android: a plain share intent sent to Instagram, which asks Feed / Story / Message.
/// - Without it, on iOS: not possible directly; the caller uses the share sheet (Instagram → Story).
/// See AppDelegate / MainActivity for the platform side.
class InstagramShare {
  InstagramShare({MethodChannel? channel, String? appId}) : _ch = channel ?? const MethodChannel('app.wehum/share'), _appId = appId ?? Env.metaAppId;
  final MethodChannel _ch;
  final String _appId;

  bool get _direct => _appId.isNotEmpty;
  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  /// True when Instagram can be opened from the button: Instagram is installed and either the app id is configured or
  /// this is Android (share intent).
  Future<bool> available() async {
    if (!_direct && !_android) return false;
    try {
      return await _ch.invokeMethod<bool>('instagramAvailable') ?? false;
    } catch (_) {
      return false; // no handler (tests, desktop) or the check failed: the caller falls back to the share sheet
    }
  }

  /// Opens Instagram with [pngPath]. False when Instagram could not be opened (the caller then uses the share sheet).
  Future<bool> shareStory(String pngPath) async {
    if (!_direct && !_android) return false;
    try {
      return await (_direct
              ? _ch.invokeMethod<bool>('instagramStory', {'path': pngPath, 'appId': _appId})
              : _ch.invokeMethod<bool>('instagramSend', {'path': pngPath})) ??
          false;
    } on PlatformException {
      return false;
    }
  }
}
