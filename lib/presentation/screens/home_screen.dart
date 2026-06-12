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

    // If profile has not loaded yet
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
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.surfaceColor,
        selectedItemColor: AppTheme.mintGreen,
        unselectedItemColor: AppTheme.textColorSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            activeIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar_outlined),
            activeIcon: Icon(Icons.radar_rounded),
            label: 'Radar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            activeIcon: Icon(Icons.warning_rounded),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showPairingQR(BuildContext context, profile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text("Scan to Pair", style: TextStyle(color: AppTheme.textColorPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Let nearby devices scan this QR code to import your profile details and exchange security keys.",
                style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Center(
                    child: Icon(Icons.qr_code_2, size: 180, color: Colors.black),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "ID: ${profile.userId.substring(0, 8)}...",
                style: const TextStyle(color: AppTheme.textColorSecondary, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Done", style: TextStyle(color: AppTheme.mintGreen)),
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

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: chats.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 60, color: AppTheme.textColorSecondary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text(
                    "No Active Chats",
                    style: TextStyle(color: AppTheme.textColorPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40.0),
                    child: Text(
                      "Navigate to the Radar tab to discover and connect with nearby devices to begin messaging.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: chats.length,
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.cardColor,
                    child: const Text("💬", style: TextStyle(fontSize: 20)),
                  ),
                  title: Text(chat.name, style: const TextStyle(color: AppTheme.textColorPrimary, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    chat.type == 'group' ? 'Group Chat' : 'Direct Message',
                    style: const TextStyle(color: AppTheme.textColorSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppTheme.textColorSecondary),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatDetailsScreen(chatId: chat.chatId, chatName: chat.name),
                      ),
                    );
                  },
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
      duration: const Duration(seconds: 2),
      lowerBound: 0.8,
      upperBound: 1.2,
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
      const SnackBar(
        content: Text('🚨 Emergency SOS alert broadcasted to all nearby devices!'),
        backgroundColor: AppTheme.crimsonRed,
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
            const SizedBox(height: 20),
            // Distress Button
            Center(
              child: ScaleTransition(
                scale: _pulseController,
                child: GestureDetector(
                  onTap: _triggerSOS,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.crimsonRed.withOpacity(0.15),
                      border: Border.all(color: AppTheme.crimsonRed, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.crimsonRed.withOpacity(0.4),
                          blurRadius: 30,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_tethering, size: 50, color: AppTheme.crimsonRed),
                        SizedBox(height: 8),
                        Text(
                          'SEND SOS',
                          style: TextStyle(
                            color: AppTheme.textColorPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Tap distress button to broadcast immediate location and emergency text to all devices within transmission range.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _sosController,
              decoration: InputDecoration(
                hintText: "Enter custom distress message...",
                hintStyle: const TextStyle(color: AppTheme.textColorSecondary),
                fillColor: AppTheme.cardColor,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.borderLight),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: AppTheme.borderLight),
            const SizedBox(height: 10),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent SOS Alerts History',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textColorPrimary),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: sosHistory.isEmpty
                  ? Center(
                      child: Text(
                        "No distress alerts registered nearby.",
                        style: TextStyle(color: AppTheme.textColorSecondary.withOpacity(0.7)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: sosHistory.length,
                      itemBuilder: (context, index) {
                        final sos = sosHistory[index];
                        return Card(
                          color: AppTheme.crimsonRed.withOpacity(0.1),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: const BorderSide(color: AppTheme.crimsonRed, width: 1),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: AppTheme.crimsonRed, size: 30),
                            title: Text(
                              sos.content,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColorPrimary),
                            ),
                            subtitle: Text(
                              "From: Peer ${sos.senderId.substring(0, 6)} • ${sos.timestamp.toLocal().toString().substring(11, 16)}",
                              style: const TextStyle(color: AppTheme.textColorSecondary, fontSize: 12),
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
