import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_providers.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/custom_toast.dart';
import '../widgets/mesh_simulator_view.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {

  void _clearDatabase() async {
    final storage = ref.read(storageServiceProvider);
    CustomToast.showDialogBox(
      context: context,
      title: "Erase App Data",
      content: "Are you sure you want to permanently delete all chats and reset your profile? This action cannot be undone.",
      confirmText: "Erase All",
      cancelText: "Cancel",
      onConfirm: () async {
        await storage.clearAllData();
        if (mounted) {
          CustomToast.show(context, "App data erased. Please restart the app.");
        }
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
                  "Simulator Mode",
                  style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Run a simulated map to test messaging when devices are far apart.",
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
              if (isSimMode) ...[
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: Icon(Icons.hub_rounded, color: palette.accent),
                  title: Text(
                    "Launch Simulation Map",
                    style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    "Open the interactive 2D node map simulator.",
                    style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const Scaffold(
                        body: MeshSimulatorView(),
                      )),
                    );
                  },
                ),
              ],
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.vpn_key_rounded, color: palette.textSecondary),
                title: Text(
                  "Device Security Key",
                  style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
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
                  "App Storage",
                  style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Total: ~280 KB used locally",
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: palette.error),
                title: Text(
                  "Delete All App Data",
                  style: GoogleFonts.inter(color: palette.error, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Resets profile, security keys, and clears all chats.",
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
                "Offline Connection Service v1.2.0",
                style: GoogleFonts.spaceGrotesk(
                  color: palette.textSecondary.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "SECURE CONNECTION SHIELD ACTIVE",
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
    CustomToast.showDialogBox(
      context: context,
      title: "Device Security Key",
      content: "This unique key secures all your offline chats:\n\n$pubKey",
      confirmText: "Dismiss",
      cancelText: "",
      onConfirm: () {},
    );
  }
}
