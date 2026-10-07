import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Theme choice (system / dark / light), kept in local prefs.
class ThemeController extends GetxController {
  ThemeController({String? Function()? load, void Function(String)? save})
      : _load = load ?? (() => GetStorage().read<String>(_key)),
        _save = save ?? ((v) => GetStorage().write(_key, v));
  final String? Function() _load;
  final void Function(String) _save;
  static const _key = 'theme_mode';

  final mode = ThemeMode.system.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _load();
    mode.value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
  }

  void set(ThemeMode m) {
    mode.value = m;
    Get.changeThemeMode(m);
    _save(m.name);
  }
}
