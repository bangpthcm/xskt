// lib/core/theme/theme_provider.dart
import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // 1. Định nghĩa hệ thống màu chuẩn (Hardcoded)
  static const Color background = Color(0xFF121212); // Nền chính
  static const Color surface = Color(0xFF1E1E1E);    // Khối/Card
  static const Color accent = Color(0xFFFFD700);     // Màu nhấn (Vàng)
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFFA0A0A0);
  
  static const Color profit = Color(0xFF00897B); // Tăng trưởng (Xanh)
  static const Color loss = Color(0xFFD32F2F);   // Chi phí (Đỏ)

  // 2. Trả về Theme duy nhất
  ThemeData getTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: accent,
      canvasColor: surface,
      cardColor: surface,
      
      // Cấu hình ColorScheme
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        surfaceContainer: surface,
        onSurface: textPrimary,
        error: loss,
      ),

      // Cấu hình Text mặc định
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textSecondary),
      ),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: accent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: accent,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: accent),
      ),

      // ✅ FIX: Dùng CardThemeData thay vì CardTheme
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none, // Đảm bảo không có border
        ),
      ),
      
      // Button: CÓ border màu Accent, nền trong suốt hoặc Surface
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: accent,  // Màu chữ/icon
          shadowColor: Colors.transparent,
          // ✅ BẮT BUỘC: Border cho nút
          side: const BorderSide(color: accent, width: 1.0), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // Input (TextField)
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        // Border mặc định (khi chưa focus)
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textSecondary.withOpacity(0.3)),
        ),
        // Border khi focus (màu Accent)
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      
      dividerTheme: DividerThemeData(
        color: textSecondary.withOpacity(0.2),
        thickness: 1,
      ),

      iconTheme: const IconThemeData(color: textSecondary),
    );
  }
}