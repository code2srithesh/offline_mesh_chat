import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../core/theme/app_theme.dart';
import 'chat_details_screen.dart';
import '../widgets/mesh_simulator_view.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    "OfflineMesh Chat",
    "Mesh Radar & Simulator",
    "Emergency SOS",
    "Settings"
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);

    if (profile == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> tabs = [
      const _ChatsTab(),
      const MeshSimulatorView(),
      const _SOSTab(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: AppTheme.textColorPrimary),
              onPressed: () => _showPairingQR(context, profile),
              tooltip: "Show Pairing QR",
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: tabs,
              ),
            ),
            _buildBottomNavBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 64,
      decoration: AppTheme.glassCardDecoration(
        color: AppTheme.surfaceColor.withOpacity(0.85),
        borderRadius: 32,
        borderWidth: 1.5,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
          _buildNavItem(1, Icons.radar_outlined, Icons.radar_rounded, 'Radar'),
          _buildNavItem(2, Icons.warning_amber_rounded, Icons.warning_rounded, 'SOS'),
          _buildNavItem(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return AnimatedPress(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isSelected ? AppTheme.mintGreen.withOpacity(0.12) : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.mintGreen : AppTheme.textColorSecondary,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.mintGreen,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  void _showPairingQR(BuildContext context, profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Scan to Pair", style: TextStyle(color: AppTheme.textColorPrimary, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Let nearby devices scan this QR code to import your profile details and exchange security keys.",
                style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(
                    child: Icon(Icons.qr_code_2_rounded, size: 160, color: AppTheme.obsidianBackground),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ID: ${profile.userId.substring(0, 12)}...",
                  style: const TextStyle(color: AppTheme.textColorSecondary, fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Done", style: TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold)),
            )
          ],
        );
      },
    );
  }
}

// --- Chats Tab Layout ---
class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatsProvider);
    final verifiedUsers = ref.watch(verifiedUsersProvider);

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surfaceColor,
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 48, color: AppTheme.textColorSecondary.withOpacity(0.5)),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No Active Chats",
                    style: TextStyle(color: AppTheme.textColorPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "Navigate to the Radar tab to discover and connect with nearby devices to begin messaging.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13, height: 1.45),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                final isGroup = chat.type == 'group';
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  color: AppTheme.surfaceColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppTheme.borderLight, width: 1.0),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (isGroup ? AppTheme.indigoTech : AppTheme.mintGreen).withOpacity(0.1),
                        border: Border.all(
                          color: (isGroup ? AppTheme.indigoTech : AppTheme.mintGreen).withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isGroup ? "👥" : "💬",
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          chat.name,
                          style: const TextStyle(
                            color: AppTheme.textColorPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        if (!isGroup && verifiedUsers.contains(chat.chatId)) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified, color: AppTheme.mintGreen, size: 16),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        isGroup ? 'Group Relay Channel' : 'Secure Direct Connection',
                        style: const TextStyle(color: AppTheme.textColorSecondary, fontSize: 12),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textColorSecondary),
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (_, __, ___) => ChatDetailsScreen(chatId: chat.chatId, chatName: chat.name),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
                                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                              ),
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 300),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

// --- Emergency SOS Tab Layout ---
class _SOSTab extends ConsumerStatefulWidget {
  const _SOSTab();

  @override
  ConsumerState<_SOSTab> createState() => _SOSTabState();
}

class _SOSTabState extends ConsumerState<_SOSTab> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _sosController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sosController.dispose();
    super.dispose();
  }

  void _triggerSOS() {
    final text = _sosController.text.trim();
    final sosText = text.isNotEmpty ? text : "HELP! Emergency Distress broadcast from device.";
    
    // Simulate latitude/longitude
    const lat = 12.9716;
    const lon = 77.5946;

    ref.read(sosProvider.notifier).sendSOS(sosText, lat, lon);
    _sosController.clear();
    FocusScope.of(context).unfocus();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🚨 Emergency SOS alert broadcasted to all nearby devices!', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.crimsonRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sosHistory = ref.watch(sosProvider);

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Distress Button with Multi-layered Glowing Radar Rings
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outermost wave
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.7, end: 1.45).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
                      ),
                      child: Container(
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.crimsonRed.withOpacity(0.04),
                          border: Border.all(color: AppTheme.crimsonRed.withOpacity(0.08), width: 1.5),
                        ),
                      ),
                    ),
                    // Inner wave
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1.25).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
                      ),
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.crimsonRed.withOpacity(0.08),
                          border: Border.all(color: AppTheme.crimsonRed.withOpacity(0.18), width: 2),
                        ),
                      ),
                    ),
                    // Center button
                    AnimatedPress(
                      onTap: _triggerSOS,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.premiumRedGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.crimsonRed.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.wifi_tethering_rounded, size: 36, color: Colors.white),
                            SizedBox(height: 6),
                            Text(
                              'SEND SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tap distress button to broadcast immediate location and emergency text to all devices within transmission range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            // Custom Input Box for Distress Alert
            Container(
              decoration: AppTheme.glassCardDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: 12,
                borderWidth: 1.0,
              ),
              child: TextField(
                controller: _sosController,
                style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                decoration: const InputDecoration(
                  hintText: "Enter custom distress message...",
                  hintStyle: TextStyle(color: AppTheme.textColorSecondary),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.edit_note_rounded, color: AppTheme.textColorSecondary),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.borderLight),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent SOS Alerts History',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.textColorPrimary, letterSpacing: -0.5),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: sosHistory.isEmpty
                  ? Center(
                      child: Text(
                        "No distress alerts registered nearby.",
                        style: TextStyle(color: AppTheme.textColorSecondary.withOpacity(0.7)),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: sosHistory.length,
                      itemBuilder: (context, index) {
                        final sos = sosHistory[index];
                        return Card(
                          color: AppTheme.crimsonRed.withOpacity(0.07),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppTheme.crimsonRed, width: 1.0),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.crimsonRed.withOpacity(0.15),
                              ),
                              child: const Icon(Icons.warning_amber_rounded, color: AppTheme.crimsonRed, size: 24),
                            ),
                            title: Text(
                              sos.content,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textColorPrimary),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "From: Peer ${sos.senderId.substring(0, 6)} • ${sos.timestamp.toLocal().toString().substring(11, 16)}",
                                style: const TextStyle(color: AppTheme.textColorSecondary, fontSize: 11),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
