import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../../app/app_controller.dart';

/// Debug builds only: lets a developer drive the running app from the host to look at every screen on a device.
/// Write a command into `<Documents>/debug_cmd.txt` (on the simulator: `xcrun simctl get_app_container … data`):
///   `/library`                 → Get.toNamed('/library')
///   `/session/abc id=abc`      → Get.toNamed('/session/abc', arguments: {'id': 'abc'})
///   `off /today`               → Get.offAllNamed('/today')
///   `link wehum://group n1`    → the push-tap router (link, optional notification id)
///   `tap Build_it`             → presses the Text that reads "Build it"
///   `back`                     → Get.back()
/// Never started in profile/release builds.
String file2text(String s) => s.replaceAll('_', ' ');

abstract final class DebugRemote {
  /// `type Sunday_morning` → fills the first text field on screen.
  static void _type(String text) {
    var done = false;
    void visit(Element e) {
      if (done) return;
      final w = e.widget;
      if (w is EditableText) {
        w.controller.text = text;
        w.onChanged?.call(text); // as if typed
        done = true;
        return;
      }
      e.visitChildren(visit);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visit);
  }

  /// `tap Build it` → presses the last (topmost: sheets come after pages) visible Text/RichText that reads exactly that (underscores stand for spaces).
  static void _tap(String label) {
    Offset? at;
    void visit(Element e) {
      final w = e.widget;
      final txt = w is Text ? (w.data ?? w.textSpan?.toPlainText()) : null;
      final k = w.key;
      final byKey = label.startsWith('#') && k is ValueKey<String> && k.value == label.substring(1);
      if (txt == label || byKey) {
        final box = e.renderObject;
        if (box is RenderBox && box.attached && box.hasSize) at = box.localToGlobal(box.size.center(Offset.zero));
        return;
      }
      e.visitChildren(visit);
    }
    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    if (at == null) return debugPrint('[debug] tap: "$label" not on screen');
    final b = GestureBinding.instance;
    const id = 77;
    b.handlePointerEvent(PointerAddedEvent(position: at!, pointer: id));
    b.handlePointerEvent(PointerDownEvent(position: at!, pointer: id));
    Future.delayed(const Duration(milliseconds: 80), () => b.handlePointerEvent(PointerUpEvent(position: at!, pointer: id)));
  }

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
      if (parts.first == 'type') return _type(file2text(parts.skip(1).join(' ')));
      if (parts.first == 'tap') return _tap(file2text(parts.skip(1).join(' ')));
      if (parts.first == 'link' && parts.length > 1) return Get.find<AppController>().openLink(parts[1], notificationId: parts.length > 2 ? parts[2] : null); // same path as a tapped push
      final off = parts.first == 'off';
      final rest = off ? parts.sublist(1) : parts;
      if (rest.isEmpty) return;
      final args = {for (final p in rest.skip(1)) if (p.contains('=')) p.substring(0, p.indexOf('=')): p.substring(p.indexOf('=') + 1)};
      off ? Get.offAllNamed<void>(rest.first, arguments: args) : Get.toNamed<void>(rest.first, arguments: args);
    });
  }
}
