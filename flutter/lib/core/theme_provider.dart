import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'platform/app_data_dir.dart';

// Persisted theme mode preference
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final file = AppDataDir.file('theme_mode');
      if (await file.exists()) {
        final val = await file.readAsString();
        state = ThemeMode.values.firstWhere(
          (m) => m.name == val.trim(),
          orElse: () => ThemeMode.system,
        );
      }
    } catch (_) {}
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final file = AppDataDir.file('theme_mode');
      await file.writeAsString(mode.name);
    } catch (_) {}
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
