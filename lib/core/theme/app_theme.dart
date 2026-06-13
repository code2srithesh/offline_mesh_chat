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
  static const ThemePalette defaultCyber = ThemePalette(
    id: 'default',
    name: 'Aurora Night',
    background: Color(0xFF050816),
    secondary: Color(0xFF0D1326),
    card: Color(0xFF131C33),
    accent: Color(0xFF6D5DFC),
    accentLight: Color(0xFF00D9FF),
    success: Color(0xFF8A7FFF),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA8B0C5),
    border: Color(0x336D5DFC),
  );

  static const ThemePalette midnightPurple = ThemePalette(
    id: 'purple',
    name: 'Cyber Neon',
    background: Color(0xFF00020A),
    secondary: Color(0xFF050B1B),
    card: Color(0xFF09122C),
    accent: Color(0xFF00F0FF),
    accentLight: Color(0xFFBD00FF),
    success: Color(0xFF00FF87),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF8E9BB0),
    border: Color(0x3300F0FF),
  );

  static const ThemePalette emeraldGreen = ThemePalette(
    id: 'green',
    name: 'Midnight Emerald',
    background: Color(0xFF020B0B),
    secondary: Color(0xFF061514),
    card: Color(0xFF0B211E),
    accent: Color(0xFF00FF87),
    accentLight: Color(0xFF60EFFF),
    success: Color(0xFF00FF87),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF7FA69E),
    border: Color(0x3300FF87),
  );

  static const ThemePalette roseGold = ThemePalette(
    id: 'rose',
    name: 'Rose Gold Premium',
    background: Color(0xFF1B1414),
    secondary: Color(0xFF291E1E),
    card: Color(0xFF3D2E2E),
    accent: Color(0xFFE29578),
    accentLight: Color(0xFFFFDDD2),
    success: Color(0xFF00D68F),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCDB3BA),
    border: Color(0x33E29578),
  );

  static const ThemePalette amoledBlack = ThemePalette(
    id: 'black',
    name: 'AMOLED Pure Black',
    background: Color(0xFF000000),
    secondary: Color(0xFF080808),
    card: Color(0xFF121212),
    accent: Color(0xFFFFFFFF),
    accentLight: Color(0xFFB0B0B0),
    success: Color(0xFF00D68F),
    warning: Color(0xFFFFB020),
    error: Color(0xFFFF5C5C),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF969696),
    border: Color(0x33FFFFFF),
  );

  static const Map<String, ThemePalette> themes = {
    'default': defaultCyber,
    'purple': midnightPurple,
    'green': emeraldGreen,
    'rose': roseGold,
    'black': amoledBlack,
  };

  static ThemePalette currentTheme = defaultCyber;
}

class AppTheme {
  // Static getters routing to active ThemeManager config for absolute backwards compatibility
  static Color get obsidianBackground => ThemeManager.currentTheme.background;
  static Color get surfaceColor => ThemeManager.currentTheme.secondary;
  static Color get cardColor => ThemeManager.currentTheme.card;
  static Color get borderLight => ThemeManager.currentTheme.border;

  // Accents matching the design system
  static Color get mintGreen => ThemeManager.currentTheme.success;
  static Color get mintGreenLight => ThemeManager.currentTheme.success.withOpacity(0.8);
  static Color get electricBlue => ThemeManager.currentTheme.accent;
  static Color get electricBlueLight => ThemeManager.currentTheme.accentLight;
  static Color get crimsonRed => ThemeManager.currentTheme.error;
  static Color get crimsonRedLight => ThemeManager.currentTheme.error.withOpacity(0.8);
  static Color get indigoTech => ThemeManager.currentTheme.accent;
  static Color get indigoTechLight => ThemeManager.currentTheme.accentLight;

  static Color get textColorPrimary => ThemeManager.currentTheme.textPrimary;
  static Color get textColorSecondary => ThemeManager.currentTheme.textSecondary;

  // Adaptable glassmorphism styles
  static BoxDecoration glassCardDecoration({
    Color? color,
    double borderRadius = 16,
    double borderWidth = 1.0,
    Color? borderColor,
  }) {
    final palette = ThemeManager.currentTheme;
    return BoxDecoration(
      color: color ?? palette.card.withOpacity(0.65),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? palette.border.withOpacity(0.2),
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        )
      ],
    );
  }

  // Adaptive Gradients
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
      colors: [palette.success, palette.accent],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  static LinearGradient get premiumRedGradient {
    final palette = ThemeManager.currentTheme;
    return LinearGradient(
      colors: [palette.error, palette.error.withOpacity(0.7)],
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

  // Dynamic Theme Builder
  static ThemeData get darkTheme {
    final palette = ThemeManager.currentTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: palette.accent,
      scaffoldBackgroundColor: palette.background,
      colorScheme: ColorScheme.dark(
        primary: palette.accent,
        secondary: palette.accentLight,
        surface: palette.secondary,
        background: palette.background,
        error: palette.error,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.border.withOpacity(0.25), width: 1),
        ),
      ),
      textTheme: TextTheme(
        // Display (48px)
        displayLarge: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 48,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        // Hero (40px)
        displayMedium: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 40,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.8,
        ),
        // Title (28px)
        titleLarge: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        // Section (22px)
        titleMedium: GoogleFonts.spaceGrotesk(
          color: palette.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        // Subtitle (18px)
        titleSmall: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        // Body (15-16px)
        bodyLarge: GoogleFonts.inter(
          color: palette.textPrimary,
          fontSize: 16,
          height: 1.45,
          letterSpacing: 0.1,
        ),
        bodyMedium: GoogleFonts.inter(
          color: palette.textSecondary,
          fontSize: 14,
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

// Tactical animated press feedback for high fidelity micro-interactions
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
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94).animate(
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
