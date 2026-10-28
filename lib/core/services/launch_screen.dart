import 'dart:async';
import 'package:flutter/widgets.dart';

/// Keeps the native launch screen up until the splash has its logo ready, so the hand-over shows no empty frame.
abstract final class LaunchScreen {
  static bool _held = false;

  /// Called once in bootstrap. A fallback releases it after [timeout] in case the splash never does.
  static void hold({Duration timeout = const Duration(seconds: 4)}) {
    if (_held) return;
    _held = true;
    WidgetsBinding.instance.deferFirstFrame();
    Timer(timeout, release);
  }

  /// Shows the first Flutter frame; safe to call more than once and when [hold] was never called (tests).
  static void release() {
    if (!_held) return;
    _held = false;
    WidgetsBinding.instance.allowFirstFrame();
  }
}
