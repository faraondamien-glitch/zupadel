import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZuTheme {
  // ─── Couleurs ───────────────────────────────────────────────
  static const Color bgPrimary   = Color(0xFF0D0F14);
  static const Color bgSurface   = Color(0xFF161920);
  static const Color bgCard      = Color(0xFF1E2230);
  static const Color borderColor = Color(0x12FFFFFF);

  static const Color accent      = Color(0xFFC8F04A); // vert citron
  static const Color accent2     = Color(0xFF4AF0C8); // turquoise
  static const Color accentRed   = Color(0xFFFF4D6A);
  static const Color accentGold  = Color(0xFFF5C842);

  static const Color textPrimary   = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF7A8090);
  static const Color textMuted     = Color(0xFF4A4F60);

  // ─── Thème principal ────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary:   accent,
      secondary: accent2,
      surface:   bgSurface,
      error:     accentRed,
      onPrimary: bgPrimary,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge:  GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary),
      displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary),
      displaySmall:  GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
      headlineLarge: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      headlineMedium:GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
      headlineSmall: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge:  GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
      bodyMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary),
      bodySmall:  GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, color: textSecondary),
      labelLarge: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: bgPrimary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bgPrimary,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w800, color: textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: bgSurface,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: bgCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: GoogleFonts.dmSans(color: textSecondary, fontSize: 13),
      hintStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bgPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: accent,
        side: const BorderSide(color: accent),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bgCard,
      selectedColor: accent.withOpacity(0.15),
      labelStyle: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
      side: const BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: const DividerThemeData(color: borderColor, thickness: 1, space: 0),
  );
}

// ─── Extension helpers ──────────────────────────────────────────
extension ZuColors on BuildContext {
  Color get accent      => ZuTheme.accent;
  Color get accent2     => ZuTheme.accent2;
  Color get bgCard      => ZuTheme.bgCard;
  Color get bgSurface   => ZuTheme.bgSurface;
  Color get textMuted   => ZuTheme.textSecondary;
}
