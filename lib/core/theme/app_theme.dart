import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Màu sắc chuẩn cho app chứng khoán — Dark + Purple Theme 💜
class AppColors {
  // ── Backgrounds ────────────────────────────────────────────────────────────
  static const background     = Color(0xFF0B0D12); // tối sâu hơn
  static const surface        = Color(0xFF13161F); // surface nhẹ
  static const surfaceVariant = Color(0xFF1A1D28); // card phụ
  static const card           = Color(0xFF181C27); // card chính — hơi tím

  // ── Borders ────────────────────────────────────────────────────────────────
  static const border         = Color(0xFF2A2D3E); // border tím nhạt

  // ── Stock Colors — chuẩn HOSE/HNX ─────────────────────────────────────────
  static const increase  = Color(0xFF00C853); // Xanh: tăng
  static const decrease  = Color(0xFFFF3D3D); // Đỏ: giảm
  static const reference = Color(0xFFFFD600); // Vàng: tham chiếu
  static const ceiling   = Color(0xFFE040FB); // Tím nhạt: trần
  static const floor     = Color(0xFF00BCD4); // Cyan: sàn

  // ── Text ───────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFEAE6FF); // trắng tím nhẹ
  static const textSecondary = Color(0xFF8B8FA8); // xám tím
  static const textDisabled  = Color(0xFF484F66); // dim

  // ── Accent — Tím may mắn 💜 ───────────────────────────────────────────────
  static const accent      = Color(0xFF9B5FFC); // tím rực chính
  static const accentLight = Color(0xFFB47EFF); // tím sáng (hover/label)
  static const accentGlow  = Color(0x339B5FFC); // tím 20% opacity (pill bg)
  static const accentDeep  = Color(0xFF7C3AED); // tím đậm (gradient end)

  // ── Market indices ─────────────────────────────────────────────────────────
  static const vnindex = Color(0xFF9B5FFC);
  static const volume  = Color(0xFF7C3AED);
}

/// Màu text cho giá theo % thay đổi
Color priceColor(double change) {
  if (change > 0) return AppColors.increase;
  if (change < 0) return AppColors.decrease;
  return AppColors.reference;
}

class AppTheme {
  static ThemeData get dark {
    // Ghi đè system navigation bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF13161F),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.dark(
        primary:          AppColors.accent,
        primaryContainer: AppColors.accentDeep,
        secondary:        AppColors.accentLight,
        surface:          AppColors.surface,
        onSurface:        AppColors.textPrimary,
        onPrimary:        Colors.white,
        error:            AppColors.decrease,
      ),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actionsIconTheme: IconThemeData(color: AppColors.textPrimary),
      ),

      // ── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),

      // ── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          side: const BorderSide(color: AppColors.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),

      // ── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: AppColors.accentGlow,
        ),
      ),

      // ── TextField ───────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        hintStyle: const TextStyle(color: AppColors.textDisabled, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),

      // ── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),

      // ── BottomNavigationBar (fallback) ──────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ── Switch / Checkbox / Radio ────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : AppColors.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accentGlow : AppColors.surfaceVariant),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppColors.accent : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.textSecondary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),

      // ── Misc ─────────────────────────────────────────────────────────────
      dividerColor: AppColors.border,
      splashFactory: NoSplash.splashFactory,   // xoá toàn bộ ripple mặc định
      highlightColor: Colors.transparent,

      textTheme: const TextTheme(
        bodyLarge:   TextStyle(color: AppColors.textPrimary,   fontSize: 14),
        bodyMedium:  TextStyle(color: AppColors.textPrimary,   fontSize: 13),
        bodySmall:   TextStyle(color: AppColors.textSecondary, fontSize: 11),
        labelLarge:  TextStyle(color: AppColors.textPrimary,   fontSize: 13, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: AppColors.textPrimary,   fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall:  TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
    );
  }
}
