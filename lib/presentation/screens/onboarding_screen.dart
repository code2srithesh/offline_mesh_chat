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

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;
  String _selectedAvatar = "🚀";

  final List<String> _avatars = ["🚀", "👾", "🤖", "🦊", "🐼", "🦁", "🦖", "🦄", "⚽️", "🎨", "🎸", "💻"];

  Future<void> _handleGetStarted() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your display name.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Generate keys & create profile (simulated delay for key generation visual feedback)
    await Future.delayed(const Duration(milliseconds: 800));
    await ref.read(profileProvider.notifier).createUserProfile(name, _selectedAvatar);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(
                  Icons.security_rounded,
                  size: 60,
                  color: AppTheme.mintGreen,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Onboarding',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your offline profile. Your private keys will be generated and stored securely only on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textColorSecondary,
                  ),
                ),
                const SizedBox(height: 40),

                // Avatar Picker
                Text(
                  'Choose Profile Avatar',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textColorSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.cardColor,
                      border: Border.all(color: AppTheme.borderLight, width: 2),
                    ),
                    child: Text(
                      _selectedAvatar,
                      style: const TextStyle(fontSize: 60),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _avatars.length,
                    itemBuilder: (context, index) {
                      final avatar = _avatars[index];
                      final isSelected = avatar == _selectedAvatar;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedAvatar = avatar;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppTheme.mintGreen.withOpacity(0.2) : AppTheme.cardColor,
                            border: Border.all(
                              color: isSelected ? AppTheme.mintGreen : AppTheme.borderLight,
                              width: 2,
                            ),
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

                const SizedBox(height: 32),

                // Name input
                Container(
                  decoration: AppTheme.glassCardDecoration(
                    color: AppTheme.cardColor.withOpacity(0.5),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: AppTheme.textColorPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      labelStyle: TextStyle(color: AppTheme.textColorSecondary),
                      prefixIcon: Icon(Icons.person, color: AppTheme.textColorSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleGetStarted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mintGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Generating Secure Keys...',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              )
                            ],
                          )
                        : const Text(
                            'Generate Profile & Pair',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
