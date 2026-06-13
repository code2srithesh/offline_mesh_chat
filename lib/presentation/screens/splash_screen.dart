import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'onboarding_screen.dart';
import 'home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _rotationController;
  late AnimationController _ambientController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _loaderFade;

  // Mock floating background particles
  final List<_SplashParticle> _particles = List.generate(
    25,
    (index) => _SplashParticle(
      x: Random().nextDouble(),
      y: Random().nextDouble(),
      speed: 0.02 + Random().nextDouble() * 0.04,
      radius: 1.5 + Random().nextDouble() * 2.5,
      opacity: 0.15 + Random().nextDouble() * 0.45,
    ),
  );

  @override
  void initState() {
    super.initState();

    // Entrance Animations (1.8s duration)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.7, curve: Curves.elasticOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Continuous Logo Orbits Rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );
    
    // Ambient Movement / Shifting Gradients
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      // Avoid infinite loops and navigation timers in widget test environment
    } else {
      _rotationController.repeat();
      _ambientController.repeat(reverse: true);
      _navigateToNext();
    }

    _entranceController.forward();
  }

  Future<void> _navigateToNext() async {
    // Wait for the cinematic duration (2.2s)
    await Future.delayed(const Duration(milliseconds: 2200));

    // Warm-up database & routing
    final storage = ref.read(storageServiceProvider);
    await storage.init();
    ref.read(routingServiceProvider); // Initialize RoutingService triggers

    final profile = await storage.getMyProfile();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => profile != null ? const HomeScreen() : const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _rotationController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: palette.background,
      body: AnimatedBuilder(
        animation: _ambientController,
        builder: (context, child) {
          // Shifting gradient color coordinates
          final gradientOffset = _ambientController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.background,
                  Color.lerp(palette.background, palette.secondary, 0.4)!,
                  Color.lerp(palette.background, palette.card, 0.7)!,
                ],
                begin: Alignment(-1.0 + gradientOffset * 0.5, -1.0 + gradientOffset),
                end: Alignment(1.0 - gradientOffset * 0.5, 1.0 - gradientOffset),
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Background Particle Painter
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambientController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SplashParticlesPainter(
                      particles: _particles,
                      progress: _ambientController.value,
                      accentColor: palette.accent.withOpacity(0.35),
                    ),
                  );
                },
              ),
            ),

            // Central Branding Element
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // orbital logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer concentric orbit (Clockwise)
                            RotationTransition(
                              turns: _rotationController,
                              child: Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.accent.withOpacity(0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.accent,
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Inner concentric orbit (Counter-Clockwise)
                            RotationTransition(
                              turns: ReverseAnimation(_rotationController),
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.accentLight.withOpacity(0.1),
                                    width: 1.2,
                                  ),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: palette.accentLight,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: palette.accentLight,
                                          blurRadius: 8,
                                          spreadRadius: 1.5,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Core Hub Logo with Blur/Shadow
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.card.withOpacity(0.85),
                                border: Border.all(
                                  color: palette.accent.withOpacity(0.35),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withOpacity(0.25),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.hub_rounded,
                                size: 40,
                                color: palette.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Brand Texts
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            'OfflineMesh',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'DECENTRALIZED • SECURE • AD-HOC',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: palette.textSecondary.withOpacity(0.7),
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Premium Smooth Loader
                  FadeTransition(
                    opacity: _loaderFade,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashParticle {
  double x;
  double y;
  final double speed;
  final double radius;
  final double opacity;

  _SplashParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
  });
}

class _SplashParticlesPainter extends CustomPainter {
  final List<_SplashParticle> particles;
  final double progress;
  final Color accentColor;

  _SplashParticlesPainter({
    required this.particles,
    required this.progress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final particle in particles) {
      // Drift upwards
      double drawY = (particle.y - progress * particle.speed) % 1.0;
      double drawX = particle.x;

      final position = Offset(drawX * size.width, drawY * size.height);
      paint.color = accentColor.withOpacity(particle.opacity);
      canvas.drawCircle(position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
