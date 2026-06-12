import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color obsidianBackground = Color(0xFF0D1117);
  static const Color surfaceColor = Color(0xFF161B22);
  static const Color cardColor = Color(0xFF21262D);
  static const Color borderLight = Color(0xFF30363D);

  // Accents
  static const Color mintGreen = Color(0xFF10B981);
  static const Color mintGreenLight = Color(0xFF34D399);
  
  static const Color electricBlue = Color(0xFF2563EB);
  static const Color electricBlueLight = Color(0xFF60A5FA);

  static const Color crimsonRed = Color(0xFFEF4444);
  static const Color crimsonRedLight = Color(0xFFF87171);

  static const Color textColorPrimary = Color(0xFFF0F6FC);
  static const Color textColorSecondary = Color(0xFF8B949E);

  // Custom Glassmorphism Box Decoration
  static BoxDecoration glassCardDecoration({
    Color color = const Color(0x1F8B949E),
    double borderRadius = 16,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderLight.withOpacity(0.5),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  // Gradients
  static const LinearGradient premiumBlueGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGreenGradient = LinearGradient(
    colors: [Color(0xFF064E3B), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumDarkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Theme config
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: mintGreen,
      scaffoldBackgroundColor: obsidianBackground,
      colorScheme: const ColorScheme.dark(
        primary: mintGreen,
        secondary: electricBlue,
        surface: surfaceColor,
        background: obsidianBackground,
        error: crimsonRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textColorPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: textColorPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textColorPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textColorPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textColorSecondary, fontSize: 14),
      ),
    );
  }
}
