import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';

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

  final List<String> _avatars = ["🚀", "👾", "🤖", "🦊", "🐼", "🦁", "🦖", "🦄", "💻", "🛰️", "⚡", "🛸"];

  // Controllers for illustrations
  late AnimationController _pulseController;
  late AnimationController _routingController;
  late AnimationController _rotationController;

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
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _skipOnboarding() {
    _pageController.animateToPage(
      4,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _simulateBiometric() async {
    setState(() {
      _isLoading = true;
    });
    // Simulate biometric scan delay
    await Future.delayed(const Duration(milliseconds: 1000));
    _nameController.text = "CryptoGhost";
    _selectedAvatar = "🤖";
    setState(() {
      _isLoading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🧬 Biometric scan successful! Profile autofilled.'),
          backgroundColor: ThemeManager.currentTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _simulateSocialLogin(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Simulating authentication via $provider... secure token retrieved!'),
        backgroundColor: ThemeManager.currentTheme.accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    setState(() {
      _nameController.text = "${provider}Peer";
      _selectedAvatar = provider == 'Discord' ? '👾' : '🛰️';
    });
  }

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a display name to register your node.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: ThemeManager.currentTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Keys generation feedback
    await Future.delayed(const Duration(milliseconds: 1400));
    await ref.read(profileProvider.notifier).createUserProfile(name, _selectedAvatar);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'MESH PROTOCOL',
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
                    title: 'Welcome to Mesh',
                    description: 'Enter a decentralized world of point-to-point communication. Connect directly to peers nearby without towers or data cables.',
                    illustration: _WelcomeIllustration(rotation: _rotationController, pulse: _pulseController, accent: palette.accent),
                  ),
                  _buildSlide(
                    title: 'E2E Encryption',
                    description: 'All conversations are secured with localized asymmetric RSA keys. Your private keys never leave your terminal.',
                    illustration: _SecurityIllustration(pulse: _pulseController, accent: palette.accent, success: palette.success),
                  ),
                  _buildSlide(
                    title: 'Offline Hops',
                    description: 'Alice to Diana, routed via Bob automatically. Messages store in neighbor database nodes until targets reconnect.',
                    illustration: _MeshHopsIllustration(progress: _routingController, accent: palette.accent, secondary: palette.accentLight),
                  ),
                  _buildSlide(
                    title: 'AI Native Assist',
                    description: 'Local on-device smart answers, mesh mapping utilities, and packet trace decoders working offline.',
                    illustration: _AiIllustration(rotation: _rotationController, pulse: _pulseController, accent: palette.accent),
                  ),
                  _buildLoginCardSlide(),
                ],
              ),
            ),

            // Page Indicators and Action buttons (Only for slides 0-3)
            if (_currentPage < 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Dot indicators
                    Row(
                      children: List.generate(5, (index) {
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

                    // Next floating action
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
                    fontSize: 32,
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
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
                    'SECURITY INITIALIZATION',
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
              'Terminal Setup',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Name your local node and pick a call sign avatar to initialize RSA pair parameters.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: palette.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 36),

            // Profile Avatar Picker
            Center(
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.05).animate(
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
            const SizedBox(height: 36),

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
                  prefixIcon: Icon(Icons.terminal_rounded, color: _isNameFocused ? palette.accent : palette.textSecondary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),

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
                    icon: Icon(Icons.fingerprint_rounded, color: palette.accent),
                    label: Text(
                      'Biometric ID',
                      style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _simulateBiometric,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: Divider(color: palette.border.withOpacity(0.3))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR CONNECT SECURELY', style: GoogleFonts.spaceGrotesk(fontSize: 10, color: palette.textSecondary, letterSpacing: 1.0, fontWeight: FontWeight.w700)),
                ),
                Expanded(child: Divider(color: palette.border.withOpacity(0.3))),
              ],
            ),
            const SizedBox(height: 20),

            // Row of custom mock socials
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialIcon('Google', Icons.g_mobiledata_rounded, Colors.redAccent),
                _buildSocialIcon('Apple', Icons.apple, Colors.white),
                _buildSocialIcon('Discord', Icons.discord, const Color(0xFF5865F2)),
              ],
            ),
            const SizedBox(height: 40),

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
                            'GENERATING RSA SECURITY KEYS...',
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
                        'INITIALIZE PROTOCOL TERMINAL',
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

  Widget _buildSocialIcon(String provider, IconData icon, Color color) {
    final palette = ThemeManager.currentTheme;
    return AnimatedPress(
      onTap: () => _simulateSocialLogin(provider),
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: palette.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: palette.border.withOpacity(0.4)),
        ),
        child: Icon(icon, size: 28, color: color),
      ),
    );
  }
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

    // Glowing core
    final corePaint = Paint()
      ..color = color.withOpacity(0.15 + pulse * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40 + pulse * 10, corePaint);

    final coreOutline = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 20 + pulse * 5, coreOutline);

    // Dynamic orbital connections
    final numNodes = 6;
    final maxRadius = size.width / 2.2;
    
    for (int i = 0; i < numNodes; i++) {
      final angle = (i * 2 * pi / numNodes) + (rotation * 2 * pi);
      final nodePos = Offset(
        center.dx + cos(angle) * maxRadius,
        center.dy + sin(angle) * maxRadius,
      );

      // Draw line from center to node
      paint.color = color.withOpacity(0.2 + pulse * 0.1);
      canvas.drawLine(center, nodePos, paint);

      // Draw node dots
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodePos, 5 + sin(rotation * 2 * pi + i) * 2, dotPaint);

      // Outer ripple
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

    // Background shield wave glow
    paint.color = success.withOpacity(0.05 + pulse * 0.05);
    paint.style = PaintingStyle.fill;
    canvas.drawCircle(center, 70 + pulse * 15, paint);

    paint.color = success.withOpacity(0.1);
    canvas.drawCircle(center, 55 + pulse * 8, paint);

    // Draw Lock Icon Outline
    final lockPaint = Paint()
      ..color = success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(center: center.translate(0, 10), width: 60, height: 45);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, lockPaint);

    // Lock shackle path
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

    // Lock keyhole dot
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
      Offset(size.width * 0.15, size.height * 0.5), // Node Alice
      Offset(size.width * 0.5, size.height * 0.25), // Node Bob
      Offset(size.width * 0.5, size.height * 0.75), // Node Charlie (alternate hop)
      Offset(size.width * 0.85, size.height * 0.5), // Node Diana
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw static connection links
    paint.color = accent.withOpacity(0.15);
    canvas.drawLine(nodes[0], nodes[1], paint);
    canvas.drawLine(nodes[0], nodes[2], paint);
    canvas.drawLine(nodes[1], nodes[3], paint);
    canvas.drawLine(nodes[2], nodes[3], paint);

    // Draw node circles
    final nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nodes.length; i++) {
      nodePaint.color = i == 0 || i == 3 ? accent : secondary;
      canvas.drawCircle(nodes[i], 12, nodePaint);
      
      // Node center dots
      final innerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(nodes[i], 4, innerPaint);
    }

    // Moving packet trace path (Alice -> Bob -> Diana)
    final path = Path()
      ..moveTo(nodes[0].dx, nodes[0].dy)
      ..lineTo(nodes[1].dx, nodes[1].dy)
      ..lineTo(nodes[3].dx, nodes[3].dy);

    // Extract path metrics to locate the packet
    final pathMetrics = path.computeMetrics();
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      final totalLength = metric.length;
      final currentPos = totalLength * progress;
      final tangent = metric.getTangentForOffset(currentPos);
      
      if (tangent != null) {
        // Draw the glowing packet
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

class _AiIllustration extends StatelessWidget {
  final Animation<double> rotation;
  final Animation<double> pulse;
  final Color accent;

  const _AiIllustration({
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
          painter: _AiPainter(
            rotation: rotation.value,
            pulse: pulse.value,
            color: accent,
          ),
        );
      },
    );
  }
}

class _AiPainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final Color color;

  _AiPainter({
    required this.rotation,
    required this.pulse,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Glowing core orbits for AI brain
    final auraPaint = Paint()
      ..color = color.withOpacity(0.06 + pulse * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 50 + pulse * 12, auraPaint);

    // Rotating orbital lines (Double axis)
    paint.color = color.withOpacity(0.3);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 120, height: 40 + pulse * 10),
      paint,
    );

    // Save canvas, rotate, and draw another orbit
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(pi / 3 + rotation * pi);
    paint.color = color.withOpacity(0.2);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 100, height: 35),
      paint,
    );
    canvas.restore();

    // Central graphic
    final corePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 12, corePaint);

    final outerRingPaint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 25 + pulse * 4, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
