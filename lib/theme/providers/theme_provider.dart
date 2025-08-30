import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/services/app_service.dart';
import '../themes/app_themes.dart';
import '../themes/theme_data.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'selected_theme';
  static const String _themeModeKey = 'theme_mode';
  
  AppThemeData _selectedTheme = AppThemes.defaultTheme;
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeProvider();

  Future<void> initialize() async {
    await _loadThemeFromPrefs();
  }
  
  // Getters
  AppThemeData get selectedTheme => _selectedTheme;
  ThemeMode get themeMode => _themeMode;
  
  ThemeData get lightTheme => _selectedTheme.lightTheme;
  ThemeData get darkTheme {
    // If the selected theme is the default, use Midnight Black as the dark theme.
    if (_selectedTheme.name == 'default') {
      return AppThemes.midnightTheme.darkTheme;
    }
    return _selectedTheme.darkTheme;
  }
  
  bool get isSystemDark {
    return SchedulerBinding.instance.platformDispatcher.platformBrightness == 
           Brightness.dark;
  }
  
  bool get isDarkMode {
    switch (_themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return isSystemDark;
    }
  }
  
  // Theme selection
  void selectTheme(AppThemeData theme) {
    if (_selectedTheme != theme) {
      _selectedTheme = theme;
      _saveThemeToPrefs();
      notifyListeners();
    }
  }
  
  // Theme mode selection
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeModeToPrefs();
      notifyListeners();
    }
  }
  
  // Persistence
  Future<void> _loadThemeFromPrefs() async {
    // Wait for prefs to be initialized
    while (AppService.prefs == null) {
      await Future.delayed(const Duration(milliseconds: 10));
    }

    final themeName = AppService.prefs.getString(_themeKey);
    if (themeName != null) {
      final theme = AppThemes.allThemes.firstWhere(
        (t) => t.name == themeName,
        orElse: () => AppThemes.defaultTheme,
      );
      _selectedTheme = theme;
    }
    
    final themeModeIndex = AppService.prefs.getInt(_themeModeKey);
    if (themeModeIndex != null) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }
  }
  
  void _saveThemeToPrefs() {
    AppService.prefs.setString(_themeKey, _selectedTheme.name);
  }
  
  void _saveThemeModeToPrefs() {
    AppService.prefs.setInt(_themeModeKey, _themeMode.index);
  }
}