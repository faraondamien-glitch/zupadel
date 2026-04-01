import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ZuTheme {
  // ─── Couleurs ───────────────────────────────────────────────
  static const Color bgPrimary   = Color(0xFF0D0F14);
  static const Color bgSurface   = Color(0xFF161920);
  static const Color bgCard      = Color(0xFF1E2230);
  static const Color borderColor = Color(0x1FFFFFFF); // 12% → 12.5% (0x1F) plus visible

  static const Color accent      = Color(0xFFC8F04A);
  static const Color accent2     = Color(0xFF4AF0C8);
  static const Color accentRed   = Color(0xFFFF4D6A);
  static const Color accentGold  = Color(0xFFF5C842);

  static const Color textPrimary   = Color(0xFFF0F2F5);
  static const Color textSecondary = Color(0xFF7A8090);
  static const Color textMuted     = Color(0xFF4A4F60);

  // ─── Spacing system ─────────────────────────────────────────
  static const double sp2  = 2;
  static const double sp4  = 4;
  static const double sp8  = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp40 = 40;
  static const double sp48 = 48;

  // ─── Gradients centralisés ───────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2A18), Color(0xFF0D0F14)],
  );
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2510), Color(0xFF0F1A1A)],
  );
  static const LinearGradient avatarGradient = LinearGradient(
    colors: [accent, accent2],
  );

  // ─── Couleurs avatars joueurs ────────────────────────────────
  static const List<Color> playerColors = [
    Color(0xFF2A4A35),
    Color(0xFF2A354A),
    Color(0xFF3A2A4A),
    Color(0xFF4A3A2A),
  ];

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
      displayLarge:  GoogleFonts.syne(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2),
      displayMedium: GoogleFonts.syne(fontSize: 24, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2),
      displaySmall:  GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary, height: 1.25),
      headlineLarge: GoogleFonts.syne(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3),
      headlineMedium:GoogleFonts.syne(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3),
      headlineSmall: GoogleFonts.syne(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, height: 1.35),
      bodyLarge:  GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary,   height: 1.5),
      bodyMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w400, color: textPrimary,   height: 1.45),
      bodySmall:  GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w400, color: textSecondary, height: 1.4),
      labelLarge: GoogleFonts.syne(fontSize: 13, fontWeight: FontWeight.w700, color: bgPrimary, height: 1.2),
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
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      labelStyle: GoogleFonts.dmSans(color: textSecondary, fontSize: 13),
      hintStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: sp16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: bgPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: sp16),
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

