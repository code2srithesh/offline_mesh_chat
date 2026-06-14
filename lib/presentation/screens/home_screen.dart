import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../data/models/storage_models.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/avatar_view.dart';
import 'chat_details_screen.dart';
import 'settings_screen.dart';
import '../widgets/mesh_simulator_view.dart';
import '../widgets/ambient_background.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<String> _titles = [
    "Secure Chats",
    "Mesh Channels",
    "Discover Beacons",
    "Terminal Settings"
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final palette = ThemeManager.currentTheme;

    if (profile == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<Widget> tabs = [
      const _ChatsTab(),
      const _CommunitiesTab(),
      const _DiscoverTab(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: palette.background,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          _titles[_currentIndex],
          style: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.w800,
            fontSize: 24,
            color: palette.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [
          SizedBox(width: 8),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _currentIndex,
            children: tabs,
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(palette),
    );
  }

  Widget _buildBottomNavBar(ThemePalette palette) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        height: 68,
        decoration: AppTheme.glassCardDecoration(
          color: palette.secondary.withOpacity(0.85),
          borderRadius: 34,
          borderWidth: 1.5,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double itemWidth = constraints.maxWidth / 4;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.fastOutSlowIn,
                  left: _currentIndex * itemWidth + 8,
                  width: itemWidth - 16,
                  top: 8,
                  bottom: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(
                        colors: [
                          palette.accent.withOpacity(0.16),
                          palette.accent.withOpacity(0.04),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: palette.accent.withOpacity(0.35),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.accent.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: _buildNavItem(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats', palette)),
                    Expanded(child: _buildNavItem(1, Icons.group_outlined, Icons.group_rounded, 'Channels', palette)),
                    Expanded(child: _buildNavItem(2, Icons.radar_outlined, Icons.radar_rounded, 'Discover', palette)),
                    Expanded(child: _buildNavItem(3, Icons.terminal_outlined, Icons.terminal_rounded, 'Settings', palette)),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label, ThemePalette palette) {
    final isSelected = _currentIndex == index;
    return AnimatedPress(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? palette.accent : palette.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? palette.accent : palette.textSecondary,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- COMMUNITIES/CHANNELS TAB ---
class _CommunitiesTab extends ConsumerStatefulWidget {
  const _CommunitiesTab();

  @override
  ConsumerState<_CommunitiesTab> createState() => _CommunitiesTabState();
}

class _CommunitiesTabState extends ConsumerState<_CommunitiesTab> {
  final List<Map<String, dynamic>> _predefinedCommunities = [
    {
      'id': 'emergency_sos',
      'name': '🚨 EMERGENCY SOS BROADCAST',
      'desc': 'Floods localized emergency coordinates to all devices. Keep channels open.',
      'tag': '#emergency',
      'icon': '🚨',
      'category': 'BROADCAST',
      'online': 14,
      'members': 412,
      'avatars': ['🦁', '🦖', '🐼', '🤖'],
    },
    {
      'id': 'community_lounge',
      'name': '💬 LOCAL LOUNGE',
      'desc': 'Casual public frequency for nearby users. Drop a hi to discover who is around.',
      'tag': '#general',
      'icon': '💬',
      'category': 'PUBLIC DISCUSSION',
      'online': 28,
      'members': 621,
      'avatars': ['🚀', '🦊', '👾', '🐼'],
    },
    {
      'id': 'community_tech',
      'name': '🛠️ TECH & SIGNAL DIAGNOSTICS',
      'desc': 'Frequencies for debugging routes, discussing hardware setups, and network traces.',
      'tag': '#dev',
      'icon': '🛠️',
      'category': 'MESH DEV',
      'online': 9,
      'members': 148,
      'avatars': ['🤖', '🛰️', '🛸', '⚡'],
    },
    {
      'id': 'community_marketplace',
      'name': '🛒 OFFLINE CLASSIFIEDS',
      'desc': 'Decentralized neighborhood directory to post trades, items, or services offline.',
      'tag': '#market',
      'icon': '🛒',
      'category': 'TRADE',
      'online': 5,
      'members': 97,
      'avatars': ['🦊', '🔮', '🦄', '🦁'],
    },
  ];

  void _openCommunityChat(String chatId, String chatName) async {
    final storage = ref.read(storageServiceProvider);
    final myProfile = ref.read(profileProvider);
    if (storage.getChat(chatId) == null) {
      final chat = ChatModel(
        chatId: chatId,
        name: chatName,
        type: 'group',
        members: [myProfile?.userId ?? 'host-device'],
        createdAt: DateTime.now(),
      );
      await storage.saveChat(chat);
    }

    if (mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ChatDetailsScreen(chatId: chatId, chatName: chatName),
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
    }
  }

  Widget _buildAvatarPile(List<String> avatars, ThemePalette palette) {
    return SizedBox(
      width: 76,
      height: 24,
      child: Stack(
        children: List.generate(avatars.length, (index) {
          return Positioned(
            left: index * 16.0,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: palette.secondary,
                border: Border.all(color: palette.background, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  )
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                avatars[index],
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(
            'DECENTRALIZED FREQUENCIES',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: palette.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: _predefinedCommunities.length,
              itemBuilder: (context, index) {
                final com = _predefinedCommunities[index];
                final isSos = com['id'] == 'emergency_sos';

                return AnimatedPress(
                  onTap: () => _openCommunityChat(com['id']!, com['name']!),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: AppTheme.glassCardDecoration(
                      color: isSos 
                          ? palette.error.withOpacity(0.06) 
                          : palette.secondary.withOpacity(0.65),
                      borderRadius: 20,
                      borderColor: isSos 
                          ? palette.error.withOpacity(0.35) 
                          : palette.border.withOpacity(0.15),
                      borderWidth: isSos ? 1.5 : 1.0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          if (isSos)
                            Positioned(
                              top: -20,
                              right: -20,
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 100,
                                color: palette.error.withOpacity(0.04),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: (isSos ? palette.error : palette.accent).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        com['category']!,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isSos ? palette.error : palette.accent,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      com['tag']!,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: palette.textSecondary.withOpacity(0.6),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Text(
                                      com['icon']!,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        com['name']!,
                                        style: GoogleFonts.spaceGrotesk(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: isSos ? palette.error : palette.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  com['desc']!,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: palette.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    _buildAvatarPile(List<String>.from(com['avatars']), palette),
                                    const SizedBox(width: 8),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSos ? palette.error : palette.success,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${com['online']} ONLINE  /  ${com['members']} PEERS",
                                      style: GoogleFonts.spaceGrotesk(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isSos ? palette.error : palette.success,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 12,
                                      color: palette.textSecondary.withOpacity(0.8),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- CHATS TAB ---
class _ChatsTab extends ConsumerStatefulWidget {
  const _ChatsTab();

  @override
  ConsumerState<_ChatsTab> createState() => _ChatsTabState();
}

class _ChatsTabState extends ConsumerState<_ChatsTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatsProvider);
    final verifiedUsers = ref.watch(verifiedUsersProvider);
    final palette = ThemeManager.currentTheme;

    // Filtered chats list
    final query = _searchController.text.trim().toLowerCase();
    var filteredList = chats.where((chat) {
      return chat.name.toLowerCase().contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildSearchBar(palette),
          const SizedBox(height: 12),

          // Chats list
          Expanded(
            child: filteredList.isEmpty
                ? _buildEmptyState(palette)
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final chat = filteredList[index];
                      final isGroup = chat.type == 'group';
                      final isVerified = verifiedUsers.contains(chat.chatId);
                      final peerUser = isGroup ? null : ref.watch(storageServiceProvider).getUser(chat.chatId);
                      final avatarString = isGroup ? "👥" : (peerUser?.profilePicture ?? "🦊");
                      
                      return Dismissible(
                        key: Key(chat.chatId),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: palette.error.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.archive_outlined, color: palette.error),
                        ),
                        onDismissed: (_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Chat archived: ${chat.name}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          color: palette.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: palette.border.withOpacity(0.15)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Stack(
                              children: [
                                AvatarView(
                                  avatar: avatarString,
                                  size: 48,
                                  fontSize: 22,
                                  borderColor: (isGroup ? palette.accent : palette.success).withOpacity(0.3),
                                  backgroundColor: palette.secondary,
                                ),
                                if (!isGroup)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: palette.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: palette.card, width: 2.0),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                            title: Row(
                              children: [
                                Text(
                                  chat.name,
                                  style: GoogleFonts.poppins(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                if (!isGroup && isVerified) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.verified_rounded, color: palette.success, size: 16),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                isGroup ? 'Active Relay Channel' : 'Secure Point-to-Point Node',
                                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '20:41',
                                  style: GoogleFonts.inter(color: palette.textSecondary.withOpacity(0.7), fontSize: 10),
                                ),
                                const SizedBox(height: 6),
                                if (index == 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: palette.accent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      '2',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                              ],
                            ),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemePalette palette) {
    return Container(
      decoration: AppTheme.glassCardDecoration(
        color: palette.secondary.withOpacity(0.6),
        borderRadius: 12,
        borderColor: palette.border.withOpacity(0.15),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {});
        },
        style: TextStyle(color: palette.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: "Search terminals...",
          hintStyle: TextStyle(color: palette.textSecondary.withOpacity(0.6)),
          prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemePalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.secondary,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 44, color: palette.textSecondary.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text(
            "No Terminal Links Found",
            style: GoogleFonts.spaceGrotesk(color: palette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            "Go to the Discover tab to connect to nearby nodes.",
            style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --- DISCOVER TAB ---
class _DiscoverTab extends ConsumerWidget {
  const _DiscoverTab();

  void _connectAndOpenChat(BuildContext context, WidgetRef ref, DiscoveredPeer peer) async {
    final commService = ref.read(communicationServiceProvider);
    final storage = ref.read(storageServiceProvider);
    final profile = ref.read(profileProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Establishing secure handshake with ${peer.name}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // 1. Initiate connection
    await commService.connectToPeer(peer);

    // 2. Save peer user details to storage
    if (storage.getUser(peer.deviceId) == null) {
      final mockUser = UserModel(
        userId: peer.deviceId,
        name: peer.name,
        profilePicture: peer.profilePicture,
        deviceId: peer.deviceId,
        publicKey: "mock_public_key_for_${peer.deviceId}",
        createdAt: DateTime.now(),
      );
      await storage.saveUser(mockUser);
    }

    // 3. Create chat session
    await ref.read(chatsProvider.notifier).createChat(
      peer.name,
      'individual',
      [profile!.userId, peer.deviceId],
      customId: peer.deviceId,
    );

    // 4. Open chat screen
    if (context.mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ChatDetailsScreen(chatId: peer.deviceId, chatName: peer.name),
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
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discoveredPeers = ref.watch(discoveredPeersProvider);
    final palette = ThemeManager.currentTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Interactive Launch Simulation Card
          Card(
            color: palette.accent.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: palette.accent.withOpacity(0.35), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.hub_rounded, color: palette.accent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'Virtual Mesh Simulator',
                        style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: palette.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Test packet traces, node relocations, and routing hop algorithms on a virtual 2D terminal grid map.',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  AnimatedPress(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const Scaffold(
                          body: MeshSimulatorView(),
                        )),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumBlueGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'LAUNCH SIMULATION BOARD',
                        style: GoogleFonts.spaceGrotesk(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Discover peer list title
          Text(
            'NEARBY ACTIVE BEACONS',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 10),

          // Real-time discovered list
          Expanded(
            child: discoveredPeers.when(
              data: (peers) {
                if (peers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Listening for BLE beacons...',
                          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 90),
                  itemCount: peers.length,
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    return Card(
                      color: palette.card,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: palette.border.withOpacity(0.15)),
                      ),
                      child: ListTile(
                        leading: AvatarView(
                          avatar: peer.profilePicture,
                          size: 40,
                          fontSize: 18,
                          borderColor: palette.accent.withOpacity(0.3),
                          backgroundColor: palette.secondary,
                        ),
                        title: Text(
                          peer.name,
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          'RSSI: -${60 + (peer.deviceId.hashCode % 20)} dBm • Secure Handshake Ready',
                          style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                        ),
                        trailing: Icon(Icons.link_rounded, color: palette.accent),
                        onTap: () => _connectAndOpenChat(context, ref, peer),
                      ),
                    );
                  },
                );
              },
              error: (e, s) => Center(child: Text('Error: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

// --- PROFILE & SETTINGS TAB ---
class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final palette = ThemeManager.currentTheme;

    if (profile == null) return const SizedBox();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Banner Card
          Card(
            color: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: palette.border.withOpacity(0.15)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  AvatarView(
                    avatar: profile.profilePicture,
                    size: 72,
                    fontSize: 36,
                    borderColor: palette.accent,
                    backgroundColor: palette.secondary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name,
                          style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: palette.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "ID: ${profile.userId.substring(0, 16)}...",
                          style: TextStyle(fontFamily: 'monospace', color: palette.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "STATUS: Listening...",
                            style: GoogleFonts.spaceGrotesk(color: palette.success, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: palette.accent),
                    onPressed: () => _showEditProfileSheet(context, ref, profile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Visual Theme Switcher swatches
          Text(
            'VISUAL INTERFACE THEME',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 70,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: ThemeManager.themes.values.map((theme) {
                final isSelected = theme.id == palette.id;
                return AnimatedPress(
                  onTap: () {
                    ref.read(themePaletteProvider.notifier).changeTheme(theme.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: theme.background,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.accent : theme.border.withOpacity(0.2),
                        width: isSelected ? 3.0 : 1.5,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(color: theme.accent.withOpacity(0.4), blurRadius: 10)
                      ] : [],
                    ),
                    child: Center(
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.accent,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Settings Categories
          Text(
            'UTILITIES & MAINTENANCE',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w800, color: palette.textSecondary, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          const SettingsScreen(),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, UserModel profile) {
    final palette = ThemeManager.currentTheme;
    final nameController = TextEditingController(text: profile.name);
    String currentAvatar = profile.profilePicture;
    final List<String> avatarEmojis = ["🚀", "🦊", "👾", "🤖", "🐼", "🦁", "🦖", "🦄", "🛰️", "🛸", "⚡", "🔮"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setInnerState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              decoration: BoxDecoration(
                color: palette.secondary.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: palette.border.withOpacity(0.2), width: 1.5),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Edit Profile settings",
                          style: GoogleFonts.spaceGrotesk(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: palette.textSecondary),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        children: [
                          AvatarView(
                            avatar: currentAvatar,
                            size: 84,
                            fontSize: 44,
                            borderColor: palette.accent,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final picked = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 300,
                                  maxHeight: 300,
                                  imageQuality: 80,
                                );
                                if (picked != null) {
                                  final bytes = await picked.readAsBytes();
                                  final base64String = base64Encode(bytes);
                                  setInnerState(() {
                                    currentAvatar = base64String;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: palette.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: palette.secondary, width: 2),
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "CHOOSE AN EMOJI AVATAR",
                      style: GoogleFonts.spaceGrotesk(
                        color: palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 52,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: avatarEmojis.length,
                        itemBuilder: (context, index) {
                          final emoji = avatarEmojis[index];
                          final isSelected = currentAvatar == emoji;
                          return GestureDetector(
                            onTap: () {
                              setInnerState(() {
                                currentAvatar = emoji;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected ? palette.accent.withOpacity(0.2) : Colors.transparent,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? palette.accent : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "DISPLAY NAME",
                      style: GoogleFonts.spaceGrotesk(
                        color: palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: AppTheme.glassCardDecoration(
                        color: palette.background.withOpacity(0.5),
                        borderRadius: 12,
                      ),
                      child: TextField(
                        controller: nameController,
                        style: TextStyle(color: palette.textPrimary),
                        decoration: InputDecoration(
                          hintText: "Enter name...",
                          hintStyle: TextStyle(color: palette.textSecondary.withOpacity(0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "SECURITY KEYPAIR",
                      style: GoogleFonts.spaceGrotesk(
                        color: palette.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Rotate Encryption Keys",
                        style: GoogleFonts.poppins(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        "Generate new RSA pair. Invalidates older chat logs.",
                        style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.error.withOpacity(0.2),
                          side: BorderSide(color: palette.error.withOpacity(0.5)),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _confirmRotateKeys(context, ref),
                        child: Text("ROTATE", style: TextStyle(color: palette.error, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isNotEmpty) {
                            await ref.read(profileProvider.notifier).updateProfile(name, currentAvatar);
                            if (context.mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Profile updated successfully!"),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          "SAVE CHANGES",
                          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmRotateKeys(BuildContext context, WidgetRef ref) {
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
            "Rotate Keys?",
            style: GoogleFonts.spaceGrotesk(color: palette.error, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "WARNING: Generating a new cryptographic keypair will render all previous E2E encrypted messages in your chats unreadable. Peers will need to fetch your new public key to message you safely.\n\nDo you wish to proceed?",
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
                await ref.read(profileProvider.notifier).resetKeys();
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Close sheet
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text("RSA security keys rotated successfully!"),
                      backgroundColor: palette.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text("ROTATE KEYS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}
