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
import '../widgets/ambient_background.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _streakController;
  late AnimationController _rotationController;
  late AnimationController _glowController;

  late Animation<double> _logoScale;
  late Animation<double> _logoGlow;
  late Animation<double> _logoFade;
  
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  
  late Animation<double> _taglineFade;
  late Animation<double> _streakPosition;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animations sequence (Total 2.0s duration)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.65, curve: Curves.elasticOut),
      ),
    );

    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.75, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
      ),
    );

    // 2. Light streak sweep across the brand name (0.9s duration starting mid-way)
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _streakPosition = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(parent: _streakController, curve: Curves.easeInOutSine),
    );

    // 3. Orbits slow rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // 4. Logo ambient glow pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _logoGlow = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      // Avoid infinite animations and navigation delays in widget testing environment
    } else {
      _rotationController.repeat();
      _glowController.repeat(reverse: true);
      _entranceController.forward().then((_) {
        _streakController.forward();
      });
      _navigateToNext();
    }

    _entranceController.forward();
  }

  Future<void> _navigateToNext() async {
    // Cinematic delay
    await Future.delayed(const Duration(milliseconds: 2800));

    final storage = ref.read(storageServiceProvider);
    await storage.init();
    ref.read(routingServiceProvider); // triggers routing init

    final profile = await storage.getMyProfile();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => profile != null ? const HomeScreen() : const OnboardingScreen(),
          transitionsBuilder: (_, animation, __, child) {
            // High fidelity startup zoom + fade transition
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 1.08, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.fastOutSlowIn),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _streakController.dispose();
    _rotationController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: palette.background,
      body: AmbientBackground(
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Cinematic Glowing Hub Logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: SizedBox(
                        width: 210,
                        height: 210,
                        child: AnimatedBuilder(
                          animation: Listenable.merge([_rotationController, _logoGlow]),
                          builder: (context, _) {
                            final glowVal = _logoGlow.value;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                // Outer Concentric Orbit (Clockwise)
                                RotationTransition(
                                  turns: _rotationController,
                                  child: Container(
                                    width: 180,
                                    height: 180,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: palette.accent.withOpacity(0.06 * glowVal),
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
                                              blurRadius: 8 + 6 * glowVal,
                                              spreadRadius: 2 * glowVal,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Inner Concentric Orbit (Counter-Clockwise)
                                RotationTransition(
                                  turns: ReverseAnimation(_rotationController),
                                  child: Container(
                                    width: 130,
                                    height: 130,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: palette.accentLight.withOpacity(0.08 * glowVal),
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
                                              blurRadius: 6 + 4 * glowVal,
                                              spreadRadius: 1.5 * glowVal,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Core glowing glass logo
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: palette.card.withOpacity(0.85),
                                    border: Border.all(
                                      color: palette.accent.withOpacity(0.35 + 0.15 * glowVal),
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: palette.accent.withOpacity(0.2 + 0.15 * glowVal),
                                        blurRadius: 20 + 10 * glowVal,
                                        spreadRadius: 1 + 2 * glowVal,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.hub_rounded,
                                    size: 44,
                                    color: palette.accent,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Brand Header with Light Streak Sweep
                  SlideTransition(
                    position: _textSlide,
                    child: FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          AnimatedBuilder(
                            animation: _streakController,
                            builder: (context, child) {
                              return ShaderMask(
                                shaderCallback: (rect) {
                                  return LinearGradient(
                                    colors: [
                                      palette.textPrimary,
                                      palette.accentLight,
                                      palette.textPrimary,
                                    ],
                                    stops: [
                                      0.0,
                                      (_streakPosition.value + 1.2) / 2.4,
                                      1.0,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ).createShader(rect);
                                },
                                child: Text(
                                  'OfflineMesh',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1.0,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          // Cinematic Tagline fade
                          FadeTransition(
                            opacity: _taglineFade,
                            child: Text(
                              'DECENTRALIZED • SECURE • AD-HOC',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: palette.textSecondary.withOpacity(0.7),
                                letterSpacing: 3.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
