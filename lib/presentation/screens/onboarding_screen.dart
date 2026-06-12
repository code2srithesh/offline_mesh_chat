import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _nameFocusNode = FocusNode();
  bool _isLoading = false;
  bool _isNameFocused = false;
  String _selectedAvatar = "🚀";

  final List<String> _avatars = ["🚀", "👾", "🤖", "🦊", "🐼", "🦁", "🦖", "🦄", "⚽️", "🎨", "🎸", "💻"];
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() {
      setState(() {
        _isNameFocused = _nameFocusNode.hasFocus;
      });
    });

    // Pulse animation for selected avatar aura
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter your display name.', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.crimsonRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Secure key pair generation simulated feedback
    await Future.delayed(const Duration(milliseconds: 1200));
    await ref.read(profileProvider.notifier).createUserProfile(name, _selectedAvatar);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                
                // Security Icon with Soft Pulsing Aura
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.mintGreen.withOpacity(0.08),
                    border: Border.all(
                      color: AppTheme.mintGreen.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    size: 54,
                    color: AppTheme.mintGreen,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  'Onboarding',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppTheme.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Create your offline profile. Your unique private keys will be generated and stored securely on this device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textColorSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // Selected Avatar Bio-Scanner Style Preview
                const Text(
                  'CHOOSE PROFILE AVATAR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textColorSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                
                Center(
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surfaceColor,
                        border: Border.all(color: AppTheme.mintGreen.withOpacity(0.5), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.mintGreen.withOpacity(0.15),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        _selectedAvatar,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Horizontal Avatar Selection Row
                SizedBox(
                  height: 64,
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
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppTheme.mintGreen.withOpacity(0.12) : AppTheme.surfaceColor,
                            border: Border.all(
                              color: isSelected ? AppTheme.mintGreen : AppTheme.borderLight,
                              width: isSelected ? 2.5 : 1.5,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppTheme.mintGreen.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              )
                            ] : [],
                          ),
                          child: Text(
                            avatar,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 40),

                // Name input with Dynamic Glow Focused Border
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: AppTheme.glassCardDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: 16,
                    borderWidth: 1.5,
                    borderColor: _isNameFocused ? AppTheme.mintGreen : AppTheme.borderLight,
                  ),
                  child: TextField(
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    style: const TextStyle(
                      color: AppTheme.textColorPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(color: AppTheme.textColorSecondary, fontWeight: FontWeight.bold),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: AppTheme.textColorSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 44),

                // Generate Profile Secure Action Button
                AnimatedPress(
                  onTap: _isLoading ? () {} : _handleGetStarted,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: _isLoading ? null : AppTheme.premiumGreenGradient,
                      color: _isLoading ? AppTheme.cardColor : null,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _isLoading ? [] : [
                        BoxShadow(
                          color: AppTheme.mintGreen.withOpacity(0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'GENERATING SECURE KEYS...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                  color: Colors.white,
                                ),
                              )
                            ],
                          )
                        : const Text(
                            'GENERATE PROFILE & JOIN MESH',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
