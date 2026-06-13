import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  void _clearDatabase() async {
    final storage = ref.read(storageServiceProvider);
    final palette = ThemeManager.currentTheme;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: palette.border.withOpacity(0.3)),
          ),
          title: Text(
            "Clear Database",
            style: GoogleFonts.spaceGrotesk(color: palette.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Are you sure you want to permanently erase all chat logs, user profiles, routing tables, and security keys? This cannot be undone.",
            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("CANCEL", style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: palette.error),
              onPressed: () async {
                await storage.clearAllData();
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Database erased. Please restart the terminal app.'),
                    backgroundColor: palette.error,
                  ),
                );
              },
              child: const Text("ERASE DATA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    final palette = ThemeManager.currentTheme;

    if (profile == null) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preferences Category
        Card(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.radar_rounded, color: palette.accent),
                title: Text(
                  "Simulation Mode Overlay",
                  style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Run a virtual 2D topology network in-memory to simulate multi-hop routing paths.",
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
                trailing: Switch(
                  value: isSimMode,
                  activeColor: palette.accent,
                  onChanged: (val) {
                    ref.read(simulationModeProvider.notifier).state = val;
                  },
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.vpn_key_rounded, color: palette.textSecondary),
                title: Text(
                  "Public Key Fingerprint",
                  style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  profile.publicKey.substring(0, 36) + "...",
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: palette.textSecondary),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                onTap: () => _showPublicKeyDialog(context, profile.publicKey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Storage & Cache
        Card(
          color: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: palette.border.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.storage_rounded, color: palette.textSecondary),
                title: Text(
                  "Database Storage Size",
                  style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Total: ~280 KB (Hive local storage tables)",
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: palette.error),
                title: Text(
                  "Erase All Database Tables",
                  style: GoogleFonts.poppins(color: palette.error, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Resets security credentials, clears mesh caches, and logs.",
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
                onTap: _clearDatabase,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Footer Build
        Center(
          child: Column(
            children: [
              Text(
                "OfflineMesh Protocol v1.2.0-Alpha",
                style: GoogleFonts.spaceGrotesk(
                  color: palette.textSecondary.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "E2E LINK SECURITY HANDSHAKE ACTIVE",
                style: GoogleFonts.spaceGrotesk(
                  color: palette.success.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _showPublicKeyDialog(BuildContext context, String pubKey) {
    final palette = ThemeManager.currentTheme;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: palette.secondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: palette.border.withOpacity(0.3)),
          ),
          title: Text(
            "Terminal Public Key",
            style: GoogleFonts.spaceGrotesk(color: palette.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border.withOpacity(0.25)),
              ),
              child: Text(
                pubKey,
                style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.white70),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("DISMISS", style: GoogleFonts.spaceGrotesk(color: palette.accent, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}
