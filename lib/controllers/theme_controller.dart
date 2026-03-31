import 'package:flutter/material.dart';
import '../services/i_storage_service.dart';
import '../utils/constants.dart';

/// Persists and exposes the user's preferred [ThemeMode].
///
/// Calling [cycle] rotates through `system → light → dark → system`.
/// The choice is stored in the settings table and restored on next launch.
class ThemeController extends ChangeNotifier {
  final IStorageService _storage;

  ThemeMode _mode = ThemeMode.system;

  ThemeController(this._storage);

  /// The currently active theme mode.
  ThemeMode get mode => _mode;

  /// Icon to represent the current mode in the UI.
  IconData get icon => switch (_mode) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light  => Icons.light_mode_rounded,
    ThemeMode.dark   => Icons.dark_mode_rounded,
  };

  /// Tooltip text for the theme toggle button.
  String get tooltip => switch (_mode) {
    ThemeMode.system => 'Theme: System',
    ThemeMode.light  => 'Theme: Light',
    ThemeMode.dark   => 'Theme: Dark',
  };

  /// Loads the saved preference from storage. Call once from [initState].
  Future<void> init() async {
    final saved = await _storage.getSetting(StorageKeys.themeMode);
    final loaded = _fromString(saved);
    if (loaded != _mode) {
      _mode = loaded;
      notifyListeners();
    }
  }

  /// Cycles `system → light → dark → system` and persists the new choice.
  Future<void> cycle() async {
    _mode = switch (_mode) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light  => ThemeMode.dark,
      ThemeMode.dark   => ThemeMode.system,
    };
    notifyListeners();
    await _storage.setSetting(StorageKeys.themeMode, _mode.name);
  }

  static ThemeMode _fromString(String? value) => switch (value) {
    'light'  => ThemeMode.light,
    'dark'   => ThemeMode.dark,
    _        => ThemeMode.system,
  };
}
