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

  /// 24-hour `HH:mm`, local time.
  String get reminderTime => _box.read<String>('reminder_time') ?? '07:00';
  set reminderTime(String v) => _box.write('reminder_time', v);

  /// `granted | denied | skipped | unknown`
  String get notificationChoice => _box.read<String>('notification_choice') ?? 'unknown';
  set notificationChoice(String v) => _box.write('notification_choice', v);

  Future<void> reset() => _box.erase();
}
