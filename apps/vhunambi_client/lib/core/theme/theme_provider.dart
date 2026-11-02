import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../constants/app_constants.dart';
import 'app_colors.dart';

/// Preference representation for Vhunambi theme mode.
enum AppThemeModePreference {
  system,
  light,
  dark;

  ThemeMode toThemeMode() => switch (this) {
        AppThemeModePreference.system => ThemeMode.system,
        AppThemeModePreference.light => ThemeMode.light,
        AppThemeModePreference.dark => ThemeMode.dark,
      };

  static AppThemeModePreference fromString(String? value) => switch (value) {
        'light' => AppThemeModePreference.light,
        'dark' => AppThemeModePreference.dark,
        _ => AppThemeModePreference.system,
      };
}

/// State notifier managing the user's active theme mode preference.
///
/// Defaults to [ThemeMode.system] to follow Android and iOS device settings
/// automatically. Persists choices to Hive ([AppConstants.themePrefsBoxKey])
/// and gracefully handles headless test environments where Hive is uninitialized.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final Box? _prefsBox;

  ThemeModeNotifier([this._prefsBox]) : super(_initThemeMode(_prefsBox)) {
    _syncColors();
  }

  static ThemeMode _initThemeMode(Box? box) {
    if (box == null) return ThemeMode.system;
    try {
      final stored = box.get('selected_theme_mode') as String?;
      return AppThemeModePreference.fromString(stored).toThemeMode();
    } catch (_) {
      return ThemeMode.system;
    }
  }

  /// Sets the theme mode preference and syncs [AppColors] immediately.
  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    _syncColors();
    try {
      final prefName = switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
      await _prefsBox?.put('selected_theme_mode', prefName);
    } catch (_) {
      // In-memory fallback for test environments
    }
  }

  void _syncColors() {
    if (state == ThemeMode.light) {
      AppColors.syncWithBrightness(Brightness.light);
    } else if (state == ThemeMode.dark) {
      AppColors.syncWithBrightness(Brightness.dark);
    }
    // If system, AppColors is synchronized by the active WidgetsBinding / MediaQuery context.
  }
}

/// Provider for the active [ThemeMode].
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  Box? box;
  try {
    if (Hive.isBoxOpen(AppConstants.themePrefsBoxKey)) {
      box = Hive.box(AppConstants.themePrefsBoxKey);
    }
  } catch (_) {
    box = null;
  }
  return ThemeModeNotifier(box);
});

