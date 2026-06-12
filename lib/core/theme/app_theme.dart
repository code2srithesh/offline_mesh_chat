import 'package:flutter/material.dart';

class AppTheme {
  // Deep Cyber Space Color Palette
  static const Color obsidianBackground = Color(0xFF06090E); // Slate-black backdrop
  static const Color surfaceColor = Color(0xFF0F172A);       // Slate-900 surface
  static const Color cardColor = Color(0xFF1E293B);          // Slate-800 card
  static const Color borderLight = Color(0x3364748B);        // Soft blue-gray border (20% Slate-500)

  // Neon Tech Accents
  static const Color mintGreen = Color(0xFF10B981);          // Neon Mint (Secure Encrypted)
  static const Color mintGreenLight = Color(0xFF34D399);
  
  static const Color electricBlue = Color(0xFF3B82F6);       // Cyber Blue (Radar & Discovery)
  static const Color electricBlueLight = Color(0xFF60A5FA);

  static const Color crimsonRed = Color(0xFFF43F5E);         // Cyber Crimson (SOS / Distress)
  static const Color crimsonRedLight = Color(0xFFFB7185);

  static const Color indigoTech = Color(0xFF6366F1);          // Indigo Accent (System & Routing)
  static const Color indigoTechLight = Color(0xFF818CF8);

  static const Color textColorPrimary = Color(0xFFF8FAFC);    // Slate-50 high contrast text
  static const Color textColorSecondary = Color(0xFF94A3B8);  // Slate-400 secondary text

  // Premium Glassmorphism Decoration
  static BoxDecoration glassCardDecoration({
    Color color = const Color(0x1F94A3B8), // Glassy white-gray translucency
    double borderRadius = 16,
    double borderWidth = 1.0,
    Color borderColor = borderLight,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor,
        width: borderWidth,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.25),
          blurRadius: 15,
          offset: const Offset(0, 6),
        )
      ],
    );
  }

  // Gradients
  static const LinearGradient premiumBlueGradient = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumGreenGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumRedGradient = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFF43F5E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumIndigoGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient premiumDarkGradient = LinearGradient(
    colors: [Color(0xFF030712), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // High-End Dark Theme configuration
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: mintGreen,
      scaffoldBackgroundColor: obsidianBackground,
      colorScheme: const ColorScheme.dark(
        primary: mintGreen,
        secondary: electricBlue,
        tertiary: indigoTech,
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
          fontWeight: FontWeight.w800, // Thicker font weight
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textColorPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(color: textColorPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        bodyLarge: TextStyle(color: textColorPrimary, fontSize: 16, height: 1.4, letterSpacing: 0.1),
        bodyMedium: TextStyle(color: textColorSecondary, fontSize: 14, height: 1.4),
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
      duration: const Duration(milliseconds: 80),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
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
