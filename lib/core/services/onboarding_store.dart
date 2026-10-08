import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Minimal key/value port (get_storage in the app, a map in tests).
abstract class PrefsBox {
  T? read<T>(String key);
  void write(String key, Object? value);
  Future<void> erase();
}

class GetStorageBox implements PrefsBox {
  GetStorageBox([GetStorage? box]) : _box = box ?? GetStorage();
  final GetStorage _box;
  @override
  T? read<T>(String key) => _box.read<T>(key);
  @override
  void write(String key, Object? value) => _box.write(key, value);
  @override
  Future<void> erase() => _box.erase();
}

class MemoryBox implements PrefsBox {
  final map = <String, Object?>{};
  @override
  T? read<T>(String key) => map[key] as T?;
  @override
  void write(String key, Object? value) => map[key] = value;
  @override
  Future<void> erase() async => map.clear();
}

/// Local choices made during setup (name, reminder time, whether onboarding is finished). Small prefs → get_storage.
class OnboardingStore extends GetxService {
  OnboardingStore([PrefsBox? box]) : _box = box ?? GetStorageBox();
  final PrefsBox _box;

  bool get done => _box.read<bool>('onboarding_done') ?? false;
  set done(bool v) => _box.write('onboarding_done', v);

  String get name => _box.read<String>('first_name') ?? '';
  set name(String v) => _box.write('first_name', v);

  /// Whose name that is. The first name on this phone must follow the signed-in person (login, sign-out, merge).
  String get nameOwner => _box.read<String>('first_name_owner') ?? '';
  set nameOwner(String v) => _box.write('first_name_owner', v);

  /// Called whenever the session's person is known. Same person: the server's name wins when it has one.
  /// A different person (logged in as someone else, or signed out to a new guest): never keep the old name.
  void adoptName({required String userId, String? serverName}) {
    if (userId.isEmpty) return;
    final server = (serverName ?? '').trim();
    if (nameOwner.isEmpty || nameOwner == userId) {
      if (server.isNotEmpty) name = server;
    } else {
      name = server;
    }
    nameOwner = userId;
  }

  /// 24-hour `HH:mm`, local time.
  String get reminderTime => _box.read<String>('reminder_time') ?? '07:00';
  set reminderTime(String v) => _box.write('reminder_time', v);

  /// `granted | denied | skipped | unknown`
  String get notificationChoice => _box.read<String>('notification_choice') ?? 'unknown';
  set notificationChoice(String v) => _box.write('notification_choice', v);

  /// What brought the person here (setup step 74, behind `features.intent`): stress | focus | sleep | deep.
  String? get intent => _box.read<String>('intent');
  set intent(String? v) => _box.write('intent', v);

  /// Downloads only on Wi-Fi (Reminders & sounds).
  bool get wifiOnlyDownloads => _box.read<bool>('wifi_only') ?? true;
  set wifiOnlyDownloads(bool v) => _box.write('wifi_only', v);

  Future<void> reset() => _box.erase();
}
