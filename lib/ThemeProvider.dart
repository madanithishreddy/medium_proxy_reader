// ignore_for_file: file_names

import 'package:flutter/material.dart';

enum AppThemeMode { light, dark, original }

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.original;

  AppThemeMode get themeMode => _themeMode;

  void setThemeMode(AppThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  ThemeMode get materialThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.original:
        return ThemeMode.system;
    }
  }

  Color? get webViewBackgroundOverride {
    switch (_themeMode) {
      case AppThemeMode.light:
        return Colors.white;
      case AppThemeMode.dark:
        return Colors.black;
      case AppThemeMode.original:
        return null;
    }
  }
}
