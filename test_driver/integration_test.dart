import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final out = Platform.environment['SHOTS_DIR'] ?? '/tmp/wehum_shots';
  await Directory(out).create(recursive: true);
  await integrationDriver(onScreenshot: (name, bytes, [args]) async {
    await File('$out/$name.png').writeAsBytes(bytes);
    return true;
  });
}
