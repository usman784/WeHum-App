import 'dart:io' show Platform;
import 'package:flutter/services.dart';

/// Android picture-in-picture for the video player (spec §12 #43). iOS has no PiP for this player.
abstract final class Pip {
  static const _ch = MethodChannel('app.wehum/pip');
  static bool get supported => Platform.isAndroid;

  static Future<bool> enter() async {
    if (!supported) return false;
    try {
      return await _ch.invokeMethod<bool>('enter') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
