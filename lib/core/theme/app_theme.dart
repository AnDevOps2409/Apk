import 'package:flutter/material.dart';

/// Màu sắc chuẩn cho app chứng khoán (dark theme)
class AppColors {
  // Background
  static const background = Color(0xFF0D0F14);
  static const surface = Color(0xFF161B22);
  static const surfaceVariant = Color(0xFF1E2530);
  static const card = Color(0xFF1C2333);

  // Borders
  static const border = Color(0xFF30363D);

  // Stock Colors - chuẩn HOSE/HNX
  static const increase = Color(0xFF00C853);    // Xanh: tăng
  static const decrease = Color(0xFFFF3D3D);    // Đỏ: giảm
  static const reference = Color(0xFFFFD600);   // Vàng: tham chiếu
  static const ceiling = Color(0xFFAA00FF);     // Tím: trần
  static const floor = Color(0xFF00BCD4);       // Xanh dương: sàn

  // Text
  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFF8B949E);
  static const textDisabled = Color(0xFF484F58);

  // Accent
  static const accent = Color(0xFF58A6FF);
  static const accentGlow = Color(0x3358A6FF);

  // Market indices
  static const vnindex = Color(0xFF58A6FF);
  static const volume = Color(0xFF388BFD);
}

/// Màu text cho giá theo % thay đổi
Color priceColor(double change) {
  if (change > 0) return AppColors.increase;
  if (change < 0) return AppColors.decrease;
  return AppColors.reference;
}

class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.decrease,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
    ),
    dividerColor: AppColors.border,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      bodyMedium: TextStyle(color: AppColors.textPrimary, fontSize: 13),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 11),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
    ),
  );
}
