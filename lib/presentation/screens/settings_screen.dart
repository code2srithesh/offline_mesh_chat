import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _nameEditController = TextEditingController();
  bool _isEditingName = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _nameEditController.text = profile.name;
    }
  }

  @override
  void dispose() {
    _nameEditController.dispose();
    super.dispose();
  }

  void _updateProfileName() {
    final name = _nameEditController.text.trim();
    if (name.isEmpty) return;

    final profile = ref.read(profileProvider);
    if (profile != null) {
      ref.read(profileProvider.notifier).updateProfile(name, profile.profilePicture);
      setState(() {
        _isEditingName = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile name updated successfully!')),
      );
    }
  }

  void _clearDatabase() async {
    final storage = ref.read(storageServiceProvider);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text("Clear Database", style: TextStyle(color: AppTheme.textColorPrimary)),
          content: const Text(
            "Are you sure you want to permanently erase all chat logs, user profiles, routing tables, and security keys? This cannot be undone.",
            style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(color: AppTheme.textColorSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimsonRed),
              onPressed: () async {
                await storage.clearAllData();
                Navigator.of(context).pop();
                
                // Restart app by pushing onboarding or restarting state
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Database erased. Please restart the application.')),
                );
              },
              child: const Text("Erase Data", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final isSimMode = ref.watch(simulationModeProvider);
    final storage = ref.watch(storageServiceProvider);

    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Card
            Card(
              color: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppTheme.cardColor,
                      child: Text(profile.profilePicture, style: const TextStyle(fontSize: 36)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isEditingName)
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _nameEditController,
                                    style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 16),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: UnderlineInputBorder(),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check, color: AppTheme.mintGreen),
                                  onPressed: _updateProfileName,
                                )
                              ],
                            )
                          else
                            Row(
                              children: [
                                Text(
                                  profile.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColorPrimary,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 16, color: AppTheme.textColorSecondary),
                                  onPressed: () {
                                    setState(() {
                                      _isEditingName = true;
                                    });
                                  },
                                )
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text(
                            "Device ID: ${profile.userId.substring(0, 12)}...",
                            style: const TextStyle(color: AppTheme.textColorSecondary, fontSize: 11),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Status: OfflineMesh Connected",
                            style: TextStyle(color: AppTheme.mintGreenLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            const Text(
              "APP PREFERENCES",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textColorSecondary, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            // Simulation mode toggle
            ListTile(
              leading: const Icon(Icons.radar_rounded, color: AppTheme.electricBlueLight),
              title: const Text("Simulation Mode Overlay", style: TextStyle(color: AppTheme.textColorPrimary)),
              subtitle: const Text("Runs a virtual 2D topology network in-memory to test multi-hops.", style: TextStyle(fontSize: 11)),
              trailing: Switch(
                value: isSimMode,
                activeColor: AppTheme.mintGreen,
                onChanged: (val) {
                  ref.read(simulationModeProvider.notifier).state = val;
                },
              ),
            ),

            const Divider(color: AppTheme.borderLight),

            const SizedBox(height: 16),
            const Text(
              "SECURITY KEYS INFO",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textColorSecondary, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.vpn_key_rounded, color: AppTheme.textColorSecondary),
              title: const Text("Public Key Fingerprint", style: TextStyle(color: AppTheme.textColorPrimary)),
              subtitle: Text(
                profile.publicKey.substring(0, 40) + "...",
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
              onTap: () => _showPublicKeyDialog(context, profile.publicKey),
            ),

            const Divider(color: AppTheme.borderLight),

            const SizedBox(height: 16),
            const Text(
              "STORAGE MANAGEMENT",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textColorSecondary, letterSpacing: 1.0),
            ),
            const SizedBox(height: 8),

            ListTile(
              leading: const Icon(Icons.storage_rounded, color: AppTheme.textColorSecondary),
              title: const Text("Database Storage Size", style: TextStyle(color: AppTheme.textColorPrimary)),
              subtitle: const Text("Total: ~240 KB (Hive storage tables)", style: TextStyle(fontSize: 12)),
            ),

            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: AppTheme.crimsonRedLight),
              title: const Text("Erase All Database Tables", style: TextStyle(color: AppTheme.crimsonRedLight)),
              onTap: _clearDatabase,
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "OfflineMesh Chat v1.0.0 (Local Build)",
                style: TextStyle(color: AppTheme.textColorSecondary.withOpacity(0.5), fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPublicKeyDialog(BuildContext context, String pubKey) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text("Asymmetric Public Key", style: TextStyle(color: AppTheme.textColorPrimary)),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                pubKey,
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: AppTheme.textColorSecondary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Dismiss", style: TextStyle(color: AppTheme.mintGreen)),
            )
          ],
        );
      },
    );
  }
}
