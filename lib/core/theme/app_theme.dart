import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemePalette {
  final String id;
  final String name;
  final Color background;
  final Color secondary;
  final Color card;
  final Color accent;
  final Color accentLight;
  final Color success;
  final Color warning;
  final Color error;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;

  const ThemePalette({
    required this.id,
    required this.name,
    required this.background,
    required this.secondary,
    required this.card,
    required this.accent,
    required this.accentLight,
    required this.success,
    required this.warning,
    required this.error,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
  });
}

class ThemeManager {
  static const ThemePalette luxuryObsidian = ThemePalette(
    id: 'default',
    name: 'Obsidian Black',
    background: Color(0xFF050505),
    secondary: Color(0xFF0B0B0B),
    card: Color(0xFF121212),
    accent: Color(0xFFFFFFFF),
    accentLight: Color(0xFFD0D0D0),
    success: Color(0xFFE5E5E5),
    warning: Color(0xFF9A9A9A),
    error: Color(0xFF666666),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD0D0D0),
    border: Color(0x14FFFFFF), // rgba(255,255,255,0.08)
  );

  static const ThemePalette alabasterLight = ThemePalette(
    id: 'light',
    name: 'Alabaster Light',
    background: Color(0xFFFAFAFA),
    secondary: Color(0xFFF2F2F2),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFF000000),
    accentLight: Color(0xFF404040),
    success: Color(0xFF202020),
    warning: Color(0xFF606060),
    error: Color(0xFF808080),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF555555),
    border: Color(0x1F000000), // rgba(0,0,0,0.12)
  );

  static const Map<String, ThemePalette> themes = {
    'default': luxuryObsidian,
    'light': alabasterLight,
  };

  static ThemePalette currentTheme = luxuryObsidian;
}

class AppTheme {
  // Static getters routing to active ThemePalette configurations
  static Color get obsidianBackground => ThemeManager.currentTheme.background;
  static Color get surfaceColor => ThemeManager.currentTheme.secondary;
  static Color get cardColor => ThemeManager.currentTheme.card;
  static Color get borderLight => ThemeManager.currentTheme.border;

  // Accents mapped directly to monochrome palette states
  static Color get mintGreen => ThemeManager.currentTheme.accent;
  static Color get mintGreenLight => ThemeManager.currentTheme.accentLight.withOpacity(0.8);
  static Color get electricBlue => ThemeManager.currentTheme.accent;
  static Color get electricBlueLight => ThemeManager.currentTheme.accentLight;
  static Color get crimsonRed => ThemeManager.currentTheme.error;
  static Color get crimsonRedLight => ThemeManager.currentTheme.error.withOpacity(0.8);
  static Color get indigoTech => ThemeManager.currentTheme.accent;
  static Color get indigoTechLight => ThemeManager.currentTheme.accentLight;

  static Color get textColorPrimary => ThemeManager.currentTheme.textPrimary;
  static Color get textColorSecondary => ThemeManager.currentTheme.textSecondary;

  // Pure glassmorphic styling (frosted glass layers, subtle borders, shadows replaced by glow)
  static BoxDecoration glassCardDecoration({
    Color? color,
    double borderRadius = 16,
    double borderWidth = 1.0,
    Color? borderColor,
  }) {
    final palette = ThemeManager.currentTheme;
    return BoxDecoration(
      color: color ?? Colors.white.withOpacity(0.04), // rgba(255,255,255,0.04)
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? Colors.white.withOpacity(0.08), // rgba(255,255,255,0.08)
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2), // Soft ambient depth glow
          blurRadius: 30,
          offset: const Offset(0, 10),
        )
      ],
    );
  }

  // Grayscale Gradients
  static LinearGradient get premiumBlueGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.accent, palette.accentLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient get premiumGreenGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.accent, palette.accentLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient get premiumRedGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.accentLight, palette.error],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient get premiumIndigoGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.accent, palette.accentLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient get premiumDarkGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.background, palette.secondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Dynamic Theme Builder using luxurious typography styles (supports light/dark brightness contrast)
  static ThemeData get darkTheme {
    final palette = ThemeManager.currentTheme;
    final isLight = palette.id == 'light';
    return ThemeData(
      useMaterial3: true,
      brightness: isLight ? Brightness.light : Brightness.dark,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.background,
      colorScheme: isLight
          ? ColorScheme.light(
              primary: palette.accent,
              secondary: palette.accentLight,
              surface: palette.secondary,
              error: palette.error,
            )
          : ColorScheme.dark(
              primary: palette.accent,
              secondary: palette.accentLight,
              surface: palette.secondary,
              error: palette.error,
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w500, // Elegant lighter weights
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border, width: 1),
        ),
      ),
      textTheme: TextTheme(
        // Large Display / Neue Montreal
        displayLarge: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 48,
          fontWeight: FontWeight.w300, // Luxurious thin look
          letterSpacing: -1.5,
        ),
        // Hero title
        displayMedium: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 40,
          fontWeight: FontWeight.w400,
          letterSpacing: -1.0,
        ),
        // Title (28px)
        titleLarge: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
        ),
        // Section (22px)
        titleMedium: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w500,
        ),
        // Subtitle (18px)
        titleSmall: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        // Body (15-16px)
        bodyLarge: GoogleFonts.inter(
          color: palette.textPrimary,
          fontSize: 16,
          height: 1.45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.1,
        ),
        bodyMedium: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        // Caption (12-13px)
        labelLarge: GoogleFonts.inter(
          color: palette.textSecondary.withOpacity(0.8),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// Micro-interactions class for luxury haptics / spring scale compression
class AnimatedPress extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const AnimatedPress({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<AnimatedPress> createState() => _AnimatedPressState();
}

class _AnimatedPressState extends State<AnimatedPress> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150), // responsive spring speed
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
