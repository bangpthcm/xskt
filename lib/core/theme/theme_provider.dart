// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;
  Color _accentColor = Colors.blue;
  
  static const String _themeModeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';

  ThemeMode get themeMode => _themeMode;
  Color get accentColor => _accentColor;

  ThemeProvider() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeStr = prefs.getString(_themeModeKey);
    if (themeModeStr != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == themeModeStr,
        orElse: () => ThemeMode.dark,
      );
    }
    
    final accentColorValue = prefs.getInt(_accentColorKey);
    if (accentColorValue != null) {
      _accentColor = Color(accentColorValue);
    }
    
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
  }

  Future<void> setAccentColor(Color color) async {
    _accentColor = color;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.value);
  }

  ThemeData getLightTheme() {
    // ✅ FIX: Tạo MaterialColor và dùng nó trong colorScheme
    final materialColor = _generateMaterialColor(_accentColor);
    
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: materialColor,
      primaryColor: _accentColor,  // ✅ THÊM: Set primary color trực tiếp
      scaffoldBackgroundColor: Colors.grey.shade50,
      cardColor: Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // ✅ FIX: Dùng colorScheme để đảm bảo màu được áp dụng đúng
      colorScheme: ColorScheme.light(
        primary: _accentColor,
        secondary: _accentColor,
        surface: Colors.white,
      ),
      // ✅ THÊM: Cấu hình màu cho các component cụ thể
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: _accentColor,
        indicatorColor: _accentColor,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return _accentColor.withOpacity(0.3);
              }
              return Colors.grey.shade200;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return _accentColor;
              }
              return Colors.grey.shade700;
            },
          ),
        ),
      ),
      useMaterial3: true,
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: _accentColor,
      scaffoldBackgroundColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1E1E1E),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.grey),
        bodyMedium: TextStyle(color: Colors.grey),
        bodySmall: TextStyle(color: Colors.grey),
        titleLarge: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
      ),
      colorScheme: ColorScheme.dark(
        primary: _accentColor,
        secondary: _accentColor,
        surface: const Color(0xFF1E1E1E),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: _accentColor,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _accentColor,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return _accentColor.withOpacity(0.3);
              }
              return const Color(0xFF2C2C2C);
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) {
              if (states.contains(WidgetState.selected)) {
                return _accentColor;
              }
              return Colors.grey.shade400;
            },
          ),
        ),
      ),
      useMaterial3: true,
    );
  }

  MaterialColor _generateMaterialColor(Color color) {
    return MaterialColor(
      color.value,
      <int, Color>{
        50: _tintColor(color, 0.9),
        100: _tintColor(color, 0.8),
        200: _tintColor(color, 0.6),
        300: _tintColor(color, 0.4),
        400: _tintColor(color, 0.2),
        500: color,
        600: _shadeColor(color, 0.1),
        700: _shadeColor(color, 0.2),
        800: _shadeColor(color, 0.3),
        900: _shadeColor(color, 0.4),
      },
    );
  }

  Color _tintColor(Color color, double factor) {
    return Color.fromRGBO(
      color.red + ((255 - color.red) * factor).round(),
      color.green + ((255 - color.green) * factor).round(),
      color.blue + ((255 - color.blue) * factor).round(),
      1,
    );
  }

  Color _shadeColor(Color color, double factor) {
    return Color.fromRGBO(
      (color.red * (1 - factor)).round(),
      (color.green * (1 - factor)).round(),
      (color.blue * (1 - factor)).round(),
      1,
    );
  }
}