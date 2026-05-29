import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand typography — Space Grotesk. For monospace-like contexts (coords,
  // IDs, timestamps), pass `fontFeatures: [FontFeature.tabularFigures()]`
  // to brandTextStyle — Space Grotesk ships an OpenType `tnum` feature
  // that locks digit widths without switching fonts.
  static TextStyle brandTextStyle({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    FontStyle? fontStyle,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.spaceGrotesk(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      fontFeatures: fontFeatures,
    );
  }

  // Brand Colors — Polyfence
  static const Color primary = Color(0xFF00C2FF); // CYAN
  static const Color primaryForeground = Color(0xFF0A0E1A); // DARK_ON_CYAN

  // Light Theme Colors
  static const Color background = Color(0xFFFAFBFC); // SURFACE
  static const Color foreground = Color(0xFF111111); // INK
  static const Color card = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFFF3F4F6); // gray-100
  static const Color secondaryForeground = Color(0xFF111111);

  static const Color mutedForeground = Color(0xFF6B7280); // TEXT_SECONDARY
  static const Color textTertiary = Color(0xFF9CA3AF); // TEXT_TERTIARY

  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFFFFFF);
  static const Color destructiveHover = Color(0xFFDC2626);

  static const Color border = Color(0xFFE5E7EB); // BORDER (solid light gray)
  // Lighter divider used between rows INSIDE list cards.
  static const Color borderMuted = Color(0xFFF3F4F6);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Zone Type Colors — pastel fill (-100) + darker icon (-600).
  static const Color circleZoneBg = Color(0xFFDBEAFE); // blue-100
  static const Color circleZoneIcon = Color(0xFF2563EB); // blue-600
  static const Color polygonZoneBg = Color(0xFFF3E8FF); // purple-100
  static const Color polygonZoneIcon = Color(0xFF9333EA); // purple-600

  // Border Radius
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusLg = 8.0; // cards
  static const double radiusXl = 14.0;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXl2 = 24.0;
  static const double spacingXl3 = 32.0;

  // Drop-shadow tokens. Use getter form because BoxShadow.color uses
  // `withValues(alpha:)` which isn't const-constructable.
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 6,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get overlayShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get fabShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.1),
          blurRadius: 15,
          spreadRadius: -3,
          offset: const Offset(0, 10),
        ),
      ];

  static ThemeData get lightTheme {
    final brandTextTheme = GoogleFonts.spaceGroteskTextTheme(_baseTextTheme);
    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      brightness: Brightness.light,
      textTheme: brandTextTheme,
      primaryTextTheme: brandTextTheme,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: primaryForeground,
        secondary: secondary,
        onSecondary: secondaryForeground,
        error: destructive,
        onError: destructiveForeground,
        surface: background,
        onSurface: foreground,
      ),
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: primaryForeground,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusLg),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: mutedForeground,
        ),
      ),
    );
  }

  static const TextTheme _baseTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
    displayMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
    displaySmall: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: foreground,
    ),
    bodyMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: foreground,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: foreground,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: foreground,
    ),
  );
}
