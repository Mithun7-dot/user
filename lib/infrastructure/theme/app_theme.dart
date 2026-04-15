import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// OBSIDIAN GALLERY — Color System (from Stitch DESIGN.md)
// ============================================================
class AppColors {
  AppColors._();

  // Surface Hierarchy (Level 0 → 5)
  static const Color bg0 = Color(0xFF0E0E0E); // Deepest void
  static const Color bg1 = Color(0xFF131313); // Main canvas / Background
  static const Color bg2 = Color(0xFF1C1B1B); // Container Low
  static const Color bg3 = Color(0xFF201F1F); // Container
  static const Color bg4 = Color(0xFF2A2A2A); // Container High / Nav
  static const Color bg5 = Color(0xFF353534); // Container Highest / Cards

  // Semantic aliases
  static const Color background = bg1;
  static const Color surface = bg1;
  static const Color surfaceContainerLow = bg2;
  static const Color surfaceContainer = bg3;
  static const Color surfaceContainerHigh = bg4;
  static const Color surfaceContainerHighest = bg5;

  // Text
  static const Color onSurface = Color(0xFFE5E2E1); // Primary text
  static const Color onSurfaceVariant = Color(0xFFC6C6C6); // Secondary text
  static const Color secondary = Color(0xFFC7C6C6);
  static const Color outline = Color(0xFF919191);
  static const Color outlineVariant = Color(0xFF474747);

  // Primary = White (sharp, stark)
  static const Color primary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFD4D4D4);
  static const Color onPrimary = Color(0xFF1A1C1C);

  // Error
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);

  // No accent color — monochromatic system
}

// ============================================================
// OBSIDIAN GALLERY — Theme
// ============================================================
class AppTheme {
  AppTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: Colors.black,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onPrimary,
        secondaryContainer: Color(0xFF464747),
        onSecondaryContainer: Color(0xFFE3E2E2),
        tertiary: Color(0xFFE4E2E2),
        onTertiary: AppColors.onPrimary,
        tertiaryContainer: Color(0xFF919090),
        onTertiaryContainer: Colors.black,
        error: AppColors.error,
        onError: Color(0xFF690005),
        errorContainer: AppColors.errorContainer,
        onErrorContainer: Color(0xFFFFDAD6),
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerLowest: AppColors.bg0,
        surfaceContainerLow: AppColors.bg2,
        surfaceContainer: AppColors.bg3,
        surfaceContainerHigh: AppColors.bg4,
        surfaceContainerHighest: AppColors.bg5,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: Color(0xFFE5E2E1),
        onInverseSurface: Color(0xFF313030),
        inversePrimary: Color(0xFF5D5F5F),
        surfaceTint: AppColors.onSurfaceVariant,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _textTheme(),
      appBarTheme: _appBarTheme(),
      elevatedButtonTheme: _elevatedButtonTheme(),
      outlinedButtonTheme: _outlinedButtonTheme(),
      textButtonTheme: _textButtonTheme(),
      inputDecorationTheme: _inputTheme(),
      bottomNavigationBarTheme: _bottomNavTheme(),
      cardTheme: _cardTheme(),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.bg4,
        contentTextStyle: GoogleFonts.manrope(
          color: AppColors.onSurface,
          fontSize: 13,
        ).copyWith(fontFamilyFallback: ['sans-serif']),
        behavior: SnackBarBehavior.floating,
        shape: const BeveledRectangleBorder(), // Sharp edges
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.bg2,
        modalBackgroundColor: AppColors.bg2,
        shape: BeveledRectangleBorder(), // 0px radius
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.bg2,
        shape: const BeveledRectangleBorder(),
        titleTextStyle: GoogleFonts.epilogue(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ).copyWith(fontFamilyFallback: ['sans-serif']),
      ),
    );
  }

  static TextTheme _textTheme() {
    return TextTheme(
      // Display — Epilogue, hero titles
      displayLarge: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 56,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        height: 1.0,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      displayMedium: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 44,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        height: 1.0,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      displaySmall: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ).copyWith(fontFamilyFallback: ['sans-serif']),

      // Headlines — Epilogue, section titles
      headlineLarge: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      headlineMedium: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      headlineSmall: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ).copyWith(fontFamilyFallback: ['sans-serif']),

      // Title — Epilogue, product names
      titleLarge: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      titleMedium: GoogleFonts.manrope(
        color: AppColors.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      titleSmall: GoogleFonts.manrope(
        color: AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: ['sans-serif']),

      // Body — Manrope
      bodyLarge: GoogleFonts.manrope(
        color: AppColors.onSurface,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      bodyMedium: GoogleFonts.manrope(
        color: AppColors.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      bodySmall: GoogleFonts.manrope(
        color: AppColors.outline,
        fontSize: 11,
        height: 1.4,
      ).copyWith(fontFamilyFallback: ['sans-serif']),

      // Label — Manrope uppercase tracking
      labelLarge: GoogleFonts.manrope(
        color: AppColors.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      labelMedium: GoogleFonts.manrope(
        color: AppColors.onSurfaceVariant,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      labelSmall: GoogleFonts.manrope(
        color: AppColors.outline,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
    );
  }

  static AppBarTheme _appBarTheme() {
    return AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.epilogue(
        color: AppColors.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      iconTheme: const IconThemeData(color: AppColors.onSurface, size: 24),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: const BeveledRectangleBorder(), // 0px radius
        textStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
        ).copyWith(fontFamilyFallback: ['sans-serif']),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      ),
    );
  }

  static OutlinedButtonThemeData _outlinedButtonTheme() {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        minimumSize: const Size(double.infinity, 56),
        side: const BorderSide(color: AppColors.outlineVariant),
        shape: const BeveledRectangleBorder(),
        textStyle: GoogleFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ).copyWith(fontFamilyFallback: ['sans-serif']),
      ),
    );
  }

  static TextButtonThemeData _textButtonTheme() {
    return TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onSurface,
        textStyle: GoogleFonts.manrope(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          decoration: TextDecoration.underline,
        ).copyWith(fontFamilyFallback: ['sans-serif']),
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  static InputDecorationTheme _inputTheme() {
    // Minimalist underline inputs (from Stitch design spec)
    return InputDecorationTheme(
      filled: false,
      border: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.outlineVariant),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      hintStyle: GoogleFonts.manrope(
        color: AppColors.outlineVariant,
        fontSize: 14,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      labelStyle: GoogleFonts.manrope(
        color: AppColors.outline,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      floatingLabelStyle: GoogleFonts.manrope(
        color: AppColors.primary,
        fontSize: 10,
        letterSpacing: 2,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
    );
  }

  static BottomNavigationBarThemeData _bottomNavTheme() {
    return BottomNavigationBarThemeData(
      backgroundColor: Colors.transparent,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: const Color(0xFF888888),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.manrope(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
      ).copyWith(fontFamilyFallback: ['sans-serif']),
      unselectedLabelStyle: GoogleFonts.manrope(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }

  static CardThemeData _cardTheme() {
    return const CardThemeData(
      color: AppColors.bg5,
      elevation: 0,
      shape: BeveledRectangleBorder(), // Sharp 0px
      margin: EdgeInsets.zero,
    );
  }
}
