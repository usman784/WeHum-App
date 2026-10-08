import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/app_controller.dart';

/// Debug builds only: lets a developer drive the running app from the host to look at every screen on a device.
/// Write a command into `<Documents>/debug_cmd.txt` (on the simulator: `xcrun simctl get_app_container … data`):
///   `/library`                 → Get.toNamed('/library')
///   `/session/abc id=abc`      → Get.toNamed('/session/abc', arguments: {'id': 'abc'})
///   `off /today`               → Get.offAllNamed('/today')
///   `link wehum://group n1`    → the push-tap router (link, optional notification id)
///   `back`                     → Get.back()
/// Never started in profile/release builds.
abstract final class DebugRemote {
  static Timer? _timer;

  static Future<void> start() async {
    if (!kDebugMode || _timer != null) return;
    final file = File('${(await getApplicationDocumentsDirectory()).path}/debug_cmd.txt');
    _timer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (!file.existsSync()) return;
      final parts = file.readAsStringSync().trim().split(RegExp(r'\s+'));
      file.deleteSync();
      if (parts.isEmpty || parts.first.isEmpty) return;
      if (parts.first == 'back') return Get.back<void>();
      if (parts.first == 'link' && parts.length > 1) return Get.find<AppController>().openLink(parts[1], notificationId: parts.length > 2 ? parts[2] : null); // same path as a tapped push
      final off = parts.first == 'off';
      final rest = off ? parts.sublist(1) : parts;
      if (rest.isEmpty) return;
      final args = {for (final p in rest.skip(1)) if (p.contains('=')) p.substring(0, p.indexOf('=')): p.substring(p.indexOf('=') + 1)};
      off ? Get.offAllNamed<void>(rest.first, arguments: args) : Get.toNamed<void>(rest.first, arguments: args);
    });
  }
}
