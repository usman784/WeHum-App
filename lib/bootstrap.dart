import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'app/app.dart';
import 'core/services/debug_remote.dart';
import 'core/audio/media_session.dart';
import 'core/config/env.dart';
import 'core/data/local/app_database.dart';
import 'core/services/perf_service.dart';
import 'core/services/crash_service.dart';

/// Single entry for every flavor (spec §6): Sentry → zones → storage → Firebase → runApp.
/// Flavor values come from `--dart-define-from-file=env/{flavor}.json`.
Future<void> bootstrap() async {
  appStartWatch.start();
  Future<void> run() async {
    WidgetsFlutterBinding.ensureInitialized();
    await GetStorage.init();
    // the local database and the downloads folder are needed by services created in InitialBinding
    Get.put<AppDatabase>(await AppDatabase.open(), permanent: true);
    try {
      Get.put<MediaSessionPort>(await AudioServiceMediaSession.init(), permanent: true); // lock screen / notification controls
    } catch (e) {
      debugPrint('audio_service init failed: $e');
      Get.put<MediaSessionPort>(const NoMediaSession(), permanent: true);
    }
    final support = await getApplicationSupportDirectory();
    Get.put<Directory>(Directory(p.join(support.path, 'downloads')), tag: 'downloads', permanent: true);
    try {
      await Firebase.initializeApp(); // native config per flavor (google-services.json / GoogleService-Info.plist)
    } catch (e) {
      debugPrint('Firebase init failed: $e'); // login and push degrade; the app still opens
    }
    unawaited(DebugRemote.start()); // debug builds only
    runApp(const WeHumApp());
  }

  if (Env.sentryDsn.isEmpty) {
    FlutterError.onError = (d) => FlutterError.presentError(d);
    await runZonedGuarded(run, (e, st) => debugPrint('Uncaught: $e\n$st'));
    return;
  }
  await SentryFlutter.init(CrashService.configure, appRunner: run);
}
