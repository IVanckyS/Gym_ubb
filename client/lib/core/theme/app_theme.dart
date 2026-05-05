import 'package:flutter/material.dart';

// ── Paleta de colores ─────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Fondos modo oscuro
  static const Color bgPrimary    = Color(0xFF0A0A0F);
  static const Color bgSecondary  = Color(0xFF12121A);
  static const Color bgTertiary   = Color(0xFF1A1A24);

  // Fondos modo claro
  static const Color bgPrimaryLight   = Color(0xFFF4F4F8);
  static const Color bgSecondaryLight = Color(0xFFFFFFFF);
  static const Color bgTertiaryLight  = Color(0xFFEEEEF4);

  // Acento (igual en ambos modos)
  static const Color accentPrimary   = Color(0xFF5B4FE8);
  static const Color accentSecondary = Color(0xFFFF6B6B);
  static const Color accentGreen     = Color(0xFF00C9A7);

  // Colores institucionales y complementarios
  static const Color ubbBlue   = Color(0xFF014898);
  static const Color ubbYellow = Color(0xFFF9B214);
  static const Color ubbRed    = Color(0xFFE41B1A);
  static const Color orange    = Color(0xFFFF8C42);
  static const Color pink      = Color(0xFFFF6B9D);

  // Texto modo oscuro
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8B8B9E);
  static const Color textMuted     = Color(0xFF4A4A5E);

  // Texto modo claro
  static const Color textPrimaryLight   = Color(0xFF1A1A2E);
  static const Color textSecondaryLight = Color(0xFF555566);
  static const Color textMutedLight     = Color(0xFF9999AA);

  // Bordes
  static const Color border      = Color(0x14FFFFFF); // dark: rgba(255,255,255,0.08)
  static const Color borderLight = Color(0x1A000000); // light: rgba(0,0,0,0.10)
}

// ── Extensión de contexto: colores según el tema activo ──────────────────────
extension AppColorsX on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get colorBgPrimary =>
      isDarkMode ? AppColors.bgPrimary : AppColors.bgPrimaryLight;
  Color get colorBgSecondary =>
      isDarkMode ? AppColors.bgSecondary : AppColors.bgSecondaryLight;
  Color get colorBgTertiary =>
      isDarkMode ? AppColors.bgTertiary : AppColors.bgTertiaryLight;

  Color get colorTextPrimary =>
      isDarkMode ? AppColors.textPrimary : AppColors.textPrimaryLight;
  Color get colorTextSecondary =>
      isDarkMode ? AppColors.textSecondary : AppColors.textSecondaryLight;
  Color get colorTextMuted =>
      isDarkMode ? AppColors.textMuted : AppColors.textMutedLight;

  Color get colorBorder =>
      isDarkMode ? AppColors.border : AppColors.borderLight;
}

// ── Tema principal ────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF4F4F8),
        colorScheme: const ColorScheme.light(
          primary: AppColors.accentPrimary,
          secondary: AppColors.accentGreen,
          error: AppColors.accentSecondary,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Color(0xFF1A1A2E),
          onError: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0x1A000000)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEEEEF4),
          hintStyle: const TextStyle(color: Color(0xFF9999AA)),
          labelStyle: const TextStyle(color: Color(0xFF555566)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x1A000000)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0x1A000000)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentSecondary),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentSecondary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentPrimary,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 28, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: Color(0xFF1A1A2E), fontSize: 22, fontWeight: FontWeight.w700),
          titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E), fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFF555566), fontSize: 14),
          bodySmall: TextStyle(color: Color(0xFF9999AA), fontSize: 12),
        ),
        dividerTheme: const DividerThemeData(color: Color(0x1A000000), space: 1, thickness: 1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.15),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(color: AppColors.accentPrimary, fontSize: 11, fontWeight: FontWeight.w600);
            }
            return const TextStyle(color: Color(0xFF9999AA), fontSize: 11, fontWeight: FontWeight.w400);
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.accentPrimary, size: 22);
            }
            return const IconThemeData(color: Color(0xFF9999AA), size: 22);
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFEEEEF4),
          selectedColor: AppColors.accentPrimary.withValues(alpha: 0.15),
          labelStyle: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 12),
          secondaryLabelStyle: const TextStyle(color: AppColors.accentPrimary, fontSize: 12),
          side: const BorderSide(color: Color(0x1A000000)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w600),
          contentTextStyle: const TextStyle(color: Color(0xFF555566), fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFF1A1A2E),
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.accentPrimary,
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgPrimary,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentPrimary,
          secondary: AppColors.accentGreen,
          error: AppColors.accentSecondary,
          surface: AppColors.bgSecondary,
          onPrimary: AppColors.textPrimary,
          onSecondary: AppColors.textPrimary,
          onSurface: AppColors.textPrimary,
          onError: AppColors.textPrimary,
        ),
        cardTheme: CardThemeData(
          color: AppColors.bgSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.bgTertiary,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentPrimary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentSecondary),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentSecondary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentPrimary,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentPrimary,
            textStyle: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
          headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
          titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          bodySmall: TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          space: 1,
          thickness: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.bgSecondary,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: AppColors.textPrimary),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.bgSecondary,
          selectedItemColor: AppColors.accentPrimary,
          unselectedItemColor: AppColors.textMuted,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.bgSecondary,
          indicatorColor: AppColors.accentPrimary.withValues(alpha: 0.18),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: AppColors.accentPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.accentPrimary, size: 22);
            }
            return const IconThemeData(color: AppColors.textSecondary, size: 22);
          }),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.bgTertiary,
          selectedColor: AppColors.accentPrimary.withValues(alpha: 0.20),
          labelStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
          secondaryLabelStyle: const TextStyle(color: AppColors.accentPrimary, fontSize: 12),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.bgSecondary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
          contentTextStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.bgTertiary,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.bgSecondary,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.accentPrimary,
        ),
      );
}

