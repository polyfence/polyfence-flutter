import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF5B6FEE);
  static const Color primaryForeground = Color(0xFFFFFFFF);

  // Lavender (Status Card)
  static const Color lavenderBackground = Color(0xFFF5F5FF);
  static const Color lavenderBorder = Color(0xFFE5E5FF);

  // Light Theme Colors
  static const Color background = Color(0xFFF9FAFB); // bg-gray-50 - subtle gray for card contrast
  static const Color foreground = Color(0xFF252525);
  static const Color card = Color(0xFFFFFFFF); // white cards float on gray background
  static const Color cardForeground = Color(0xFF252525);

  static const Color secondary = Color(0xFFF0F0F3);
  static const Color secondaryForeground = Color(0xFF030213);

  static const Color muted = Color(0xFFECECF0);
  static const Color mutedForeground = Color(0xFF717182);

  static const Color accent = Color(0xFFE9EBEF);
  static const Color accentForeground = Color(0xFF030213);

  static const Color destructive = Color(0xFFEF4444);
  static const Color destructiveForeground = Color(0xFFFFFFFF);

  static const Color border = Color(0x1A000000); // rgba(0, 0, 0, 0.1)
  static const Color inputBackground = Color(0xFFF3F3F5);

  // Status Colors
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFEAB308);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Zone Type Colors
  static const Color circleZoneBg = Color(0xFFDBEAFE);
  static const Color circleZoneIcon = Color(0xFF2563EB);
  static const Color polygonZoneBg = Color(0xFFF3E8FF);
  static const Color polygonZoneIcon = Color(0xFF9333EA);

  // Border Radius
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;  // rounded-lg (0.5rem = 8px) per spec
  static const double radiusLg = 8.0;  // rounded-lg (0.5rem = 8px) per spec - cards use this
  static const double radiusXl = 14.0;

  // Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 20.0;
  static const double spacingXl2 = 24.0;
  static const double spacingXl3 = 32.0;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
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
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
      textTheme: const TextTheme(
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
      ),
    );
  }

  static ThemeData get darkTheme {
    // Similar structure for dark theme
    return lightTheme.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF252525),
    );
  }
}
