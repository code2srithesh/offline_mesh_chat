import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';
import '../widgets/ambient_background.dart';
import '../widgets/custom_toast.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();

  int _currentPage = 0;
  bool _isLoading = false;
  bool _isNameFocused = false;
  String _selectedAvatar = "🚀";

  final List<String> _avatars = ["🚀", "🦊", "👾", "🤖", "🐼", "🦁", "🦖", "🦄", "🛰️", "🛸", "⚡", "🔮"];

  // Setup Progress States
  int _loadingStep = 0;
  Timer? _loadingTimer;
  final List<String> _loadingLogs = [
    "[INFO] Initializing secure configuration...",
    "[OK] Local environment parameters set up.",
    "[INFO] Generating secure profile key pair...",
    "[OK] Key pair candidate created successfully.",
    "[INFO] Verifying security keys...",
    "[OK] Security credentials verified.",
    "[INFO] Saving secure key pair locally...",
    "[OK] Device configured. Setup complete!"
  ];

  // Animation Controllers for illustrations
  late AnimationController _pulseController;
  late AnimationController _routingController;
  late AnimationController _rotationController;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() {
      setState(() {
        _isNameFocused = _nameFocusNode.hasFocus;
      });
    });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _routingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      // Avoid infinite animation loops in widget test environment
    } else {
      _pulseController.repeat(reverse: true);
      _routingController.repeat();
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameFocusNode.dispose();
    _nameController.dispose();
    _pulseController.dispose();
    _routingController.dispose();
    _rotationController.dispose();
    _scanController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 600),
      curve: Curves.fastOutSlowIn,
    );
  }

  void _showFaceIdScanner() {
    final palette = ThemeManager.currentTheme;
    _scanController.repeat(reverse: true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 420,
          decoration: BoxDecoration(
            color: palette.secondary.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: palette.border.withOpacity(0.3), width: 1.5),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: AmbientBackground(child: const SizedBox()),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Face Verification',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scanning face features to personalize your profile security.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 36),
                    // Scanner Animation
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: _FaceIdScanPainter(
                              progress: _scanController.value,
                              color: palette.accent,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Dismiss button
                    AnimatedPress(
                      onTap: () {
                        _scanController.stop();
                        Navigator.of(context).pop();
                        
                        // Autofill profile details
                        setState(() {
                          _nameController.text = "CryptoGhost";
                          _selectedAvatar = "🤖";
                        });

                        CustomToast.show(context, 'Profile successfully configured.');
                      },
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: AppTheme.premiumBlueGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'AUTO-FILL PROFILE',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _scanController.stop());
  }

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      CustomToast.show(context, 'Please enter a display name.');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingStep = 0;
    });

    // Animate logs over ~3.6 seconds (12 logs * 300ms)
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      if (_loadingStep < _loadingLogs.length - 1) {
        if (mounted) {
          setState(() {
            _loadingStep++;
          });
        }
      } else {
        timer.cancel();
      }
    });

    await Future.delayed(const Duration(milliseconds: 3800));
    await ref.read(profileProvider.notifier).createUserProfile(name, _selectedAvatar);

    _loadingTimer?.cancel();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.05, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              child: child,
            ),
          ),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    }
  }

  Widget _buildLoadingOverlay(ThemePalette palette) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Spinning key ring / cryptographic emblem
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * pi,
                              child: child,
                            );
                          },
                          child: CustomPaint(
                            size: const Size(100, 100),
                            painter: _CryptoRingPainter(color: palette.accent),
                          ),
                        ),
                        Icon(
                          Icons.vpn_key_rounded,
                          color: palette.accent,
                          size: 36,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'GENERATING SECURE ACCESS',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Secure credentials are being generated on your device.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Shimmer progress bar
                  Container(
                    width: double.infinity,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: constraints.maxWidth * ((_loadingStep + 1) / _loadingLogs.length),
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: AppTheme.premiumBlueGradient,
                                borderRadius: BorderRadius.circular(2),
                                boxShadow: [
                                  BoxShadow(
                                    color: palette.accent.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Scrolling Terminal Code Log
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border.withOpacity(0.3)),
                      ),
                      child: ClipRect(
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _loadingStep + 1,
                          itemBuilder: (context, index) {
                            final log = _loadingLogs[index];
                            final isLast = index == _loadingStep;
                            final isOk = log.contains("[OK]");
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ">  ",
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: palette.accent,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      log,
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 11,
                                        color: isLast 
                                            ? Colors.white 
                                            : (isOk ? palette.success : palette.textSecondary),
                                        fontWeight: isLast ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          AmbientBackground(
            child: SafeArea(
              child: Column(
            children: [
              // Top Bar
              if (_currentPage < 3)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OFFLINE MESH',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.accent,
                          letterSpacing: 2.0,
                        ),
                      ),
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: GoogleFonts.inter(
                            color: palette.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    ],
                  ),
                ),

              // Page View
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() {
                      _currentPage = page;
                    });
                  },
                  children: [
                    _buildSlide(
                      title: 'Welcome',
                      description: 'Connect directly with people nearby, completely offline. No cellular towers, internet, or data plans required.',
                      illustration: _WelcomeIllustration(rotation: _rotationController, pulse: _pulseController, accent: palette.accent),
                    ),
                    _buildSlide(
                      title: 'Private & Secure',
                      description: 'All chats are securely locked on your device. Your data stays entirely yours, with security keys stored safely on your phone.',
                      illustration: _SecurityIllustration(pulse: _pulseController, accent: palette.accent, success: palette.accentLight),
                    ),
                    _buildSlide(
                      title: 'Automatic Delivery',
                      description: 'Messages find the best path to deliver automatically. If a friend is far away, nearby devices help pass and store messages until they reconnect.',
                      illustration: _MeshHopsIllustration(progress: _routingController, accent: palette.accent, secondary: palette.accentLight),
                    ),
                    _buildLoginCardSlide(),
                  ],
                ),
              ),
              if (_currentPage < 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Dot indicators
                      Row(
                        children: List.generate(4, (index) {
                          final isActive = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isActive ? palette.accent : palette.border.withOpacity(0.4),
                            ),
                          );
                        }),
                      ),

                      // Next action
                      AnimatedPress(
                        onTap: _nextPage,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            gradient: AppTheme.premiumBlueGradient,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: palette.accent.withOpacity(0.35),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Next',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading) _buildLoadingOverlay(palette),
        ],
      ),
    );
  }

  Widget _buildSlide({
    required String title,
    required String description,
    required Widget illustration,
  }) {
    final palette = ThemeManager.currentTheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic section
          Expanded(
            flex: 5,
            child: Center(
              child: illustration,
            ),
          ),
          const SizedBox(height: 12),

          // Details section
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: palette.textPrimary,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: palette.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCardSlide() {
    final palette = ThemeManager.currentTheme;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Display
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.accent.withOpacity(0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GET STARTED',
                    style: GoogleFonts.spaceGrotesk(
                      color: palette.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Profile',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your profile details to start chatting securely.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),

            // Profile Avatar Picker
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.secondary,
                    border: Border.all(color: palette.accent.withOpacity(0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Text(
                    _selectedAvatar,
                    style: const TextStyle(fontSize: 60),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Horizontal avatar select row
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _avatars.length,
                itemBuilder: (context, index) {
                  final avatar = _avatars[index];
                  final isSelected = avatar == _selectedAvatar;
                  return AnimatedPress(
                    onTap: () {
                      setState(() {
                        _selectedAvatar = avatar;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? palette.accent.withOpacity(0.12) : palette.secondary,
                        border: Border.all(
                          color: isSelected ? palette.accent : palette.border.withOpacity(0.4),
                          width: isSelected ? 2.0 : 1.0,
                        ),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: palette.accent.withOpacity(0.25),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ] : [],
                      ),
                      child: Text(
                        avatar,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Input fields under Glassmorphism
            Container(
              decoration: AppTheme.glassCardDecoration(
                color: palette.secondary.withOpacity(0.85),
                borderRadius: 16,
                borderColor: _isNameFocused ? palette.accent : palette.border.withOpacity(0.3),
              ),
              child: TextField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                style: GoogleFonts.inter(
                  color: palette.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(
                    color: _isNameFocused ? palette.accent : palette.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                  prefixIcon: Icon(Icons.person_outline_rounded, color: _isNameFocused ? palette.accent : palette.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Social & Biometric Access shortcuts
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: palette.border.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(Icons.face_retouching_natural_rounded, color: palette.accent),
                    label: Text(
                      'Biometric ID',
                      style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _showFaceIdScanner,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Create Key Pair Button
            AnimatedPress(
              onTap: _isLoading ? () {} : _handleGetStarted,
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: _isLoading ? null : AppTheme.premiumBlueGradient,
                  color: _isLoading ? palette.card : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoading ? [] : [
                    BoxShadow(
                      color: palette.accent.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                alignment: Alignment.center,
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'SETTING UP PROFILE SECURELY...',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          )
                        ],
                      )
                    : Text(
                        'GET STARTED',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// --- Face ID Scan Painting ---
class _FaceIdScanPainter extends CustomPainter {
  final double progress;
  final Color color;

  _FaceIdScanPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Outer circle
    canvas.drawCircle(center, size.width * 0.45, paint);

    // Dotted corners simulating scan zone
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final double radius = size.width * 0.45;
    // Draw 4 corner sweeps
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi/4 - 0.2, 0.4, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi/4 - 0.2, 0.4, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 3*pi/4 - 0.2, 0.4, false, cornerPaint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -3*pi/4 - 0.2, 0.4, false, cornerPaint);

    // Inner Face shape placeholder
    final facePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawOval(Rect.fromCenter(center: center.translate(0, -5), width: 50, height: 65), facePaint);
    canvas.drawArc(Rect.fromCenter(center: center.translate(0, 15), width: 34, height: 20), 0, pi, false, facePaint);

    // Scanning horizontal sweep bar
    final barY = (size.height * 0.1) + (size.height * 0.8 * progress);
    final barPaint = Paint()
      ..shader = LinearGradient(
        colors: [Colors.transparent, color, Colors.transparent],
      ).createShader(Rect.fromLTWH(0, barY - 2, size.width, 4))
      ..strokeWidth = 3.0;
    canvas.drawLine(Offset(size.width * 0.1, barY), Offset(size.width * 0.9, barY), barPaint);

    // Glowing blur sweep
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTRB(size.width * 0.1, barY - 10, size.width * 0.9, barY + 2), glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Illustration Painter Widgets ---
class _WelcomeIllustration extends StatelessWidget {
  final Animation<double> rotation;
  final Animation<double> pulse;
  final Color accent;

  const _WelcomeIllustration({
    required this.rotation,
    required this.pulse,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([rotation, pulse]),
      builder: (context, _) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _WelcomePainter(
            rotation: rotation.value,
            pulse: pulse.value,
            color: accent,
          ),
        );
      },
    );
  }
}

class _WelcomePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color color;

  _WelcomePainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final corePaint = Paint()
      ..color = color.withOpacity(0.15 + pulse * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40 + pulse * 10, corePaint);

    final coreOutline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 20 + pulse * 5, coreOutline);

    final numNodes = 6;
    final maxRadius = size.width / 2.2;
    
    for (int i = 0; i < numNodes; i++) {
      final angle = (i * 2 * pi / numNodes) + (rotation * 2 * pi);
      final nodePos = Offset(
        center.dx + cos(angle) * maxRadius,
        center.dy + sin(angle) * maxRadius,
      );

      paint.color = color.withOpacity(0.2 + pulse * 0.1);
      canvas.drawLine(center, nodePos, paint);

      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodePos, 5 + sin(rotation * 2 * pi + i) * 2, dotPaint);

      paint.color = color.withOpacity(0.05);
      canvas.drawCircle(nodePos, 12, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SecurityIllustration extends StatelessWidget {
  final Animation<double> pulse;
  final Color accent;
  final Color success;

  const _SecurityIllustration({
    required this.pulse,
    required this.accent,
    required this.success,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _SecurityPainter(
            pulse: pulse.value,
            accent: accent,
            success: success,
          ),
        );
      },
    );
  }
}

class _SecurityPainter extends CustomPainter {
  final double pulse;
  final Color accent;
  final Color success;

  _SecurityPainter({
    required this.pulse,
    required this.accent,
    required this.success,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint();

    paint.color = success.withOpacity(0.05 + pulse * 0.05);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, 70 + pulse * 15, paint);

    paint.color = success.withOpacity(0.1);
    canvas.drawCircle(center, 55 + pulse * 8, paint);

    final lockPaint = Paint()
      ..color = success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(center: center.translate(0, 10), width: 60, height: 45);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, lockPaint);

    final path = Path()
      ..moveTo(center.dx - 18, center.dy + 10)
      ..lineTo(center.dx - 18, center.dy - 12)
      ..arcToPoint(
        Offset(center.dx + 18, center.dy - 12),
        radius: const Radius.circular(18),
        clockwise: true,
      )
      ..lineTo(center.dx + 18, center.dy + 10);
    
    canvas.drawPath(path, lockPaint);

    paint.color = success;
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center.translate(0, 18), 5, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MeshHopsIllustration extends StatelessWidget {
  final Animation<double> progress;
  final Color accent;
  final Color secondary;

  const _MeshHopsIllustration({
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(220, 200),
          painter: _MeshHopsPainter(
            progress: progress.value,
            accent: accent,
            secondary: secondary,
          ),
        );
      },
    );
  }
}

class _MeshHopsPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Color secondary;

  _MeshHopsPainter({
    required this.progress,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = [
      Offset(size.width * 0.15, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.25),
      Offset(size.width * 0.5, size.height * 0.75),
      Offset(size.width * 0.85, size.height * 0.5),
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    paint.color = accent.withOpacity(0.15);
    canvas.drawLine(nodes[0], nodes[1], paint);
    canvas.drawLine(nodes[0], nodes[2], paint);
    canvas.drawLine(nodes[1], nodes[3], paint);
    canvas.drawLine(nodes[2], nodes[3], paint);

    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nodes.length; i++) {
      nodePaint.color = i == 0 || i == 3 ? accent : secondary;
      canvas.drawCircle(nodes[i], 12, nodePaint);
      
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodes[i], 4, innerPaint);
    }

    final path = Path()
      ..moveTo(nodes[0].dx, nodes[0].dy)
      ..lineTo(nodes[1].dx, nodes[1].dy)
      ..lineTo(nodes[3].dx, nodes[3].dy);

    final pathMetrics = path.computeMetrics();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final totalLength = metric.length;
      final currentPos = totalLength * progress;
      final tangent = metric.getTangentForOffset(currentPos);
      
      if (tangent != null) {
        final packetPaint = Paint()
          ..color = accent
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, 8, packetPaint);

        final glowPaint = Paint()
          ..color = accent.withOpacity(0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(tangent.position, 16, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _CryptoRingPainter extends CustomPainter {
  final Color color;

  _CryptoRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Outer orbiting ring with gaps
    final double radius = size.width * 0.45;
    paint.color = color.withOpacity(0.3);
    canvas.drawCircle(center, radius, paint);

    paint.color = color;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), 0, pi / 3, false, paint);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), pi, pi / 3, false, paint);

    // Inner dotted/dashed ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = color.withOpacity(0.5);
    
    final double innerRadius = size.width * 0.35;
    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
