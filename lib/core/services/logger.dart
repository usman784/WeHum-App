import 'package:flutter/foundation.dart';
import '../utils/redact.dart';

/// Debug-only console logging with secrets removed.
void logd(String tag, String message) {
  if (kDebugMode) debugPrint('[$tag] ${redact(message)}');
}
