import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../providers/simulation_provider.dart';
import '../../data/models/storage_models.dart';
import '../../data/services/mock_communication_service.dart';
import '../../core/theme/app_theme.dart';
import '../screens/chat_details_screen.dart';

class MeshSimulatorView extends ConsumerStatefulWidget {
  const MeshSimulatorView({super.key});

  @override
  ConsumerState<MeshSimulatorView> createState() => _MeshSimulatorViewState();
}

class _MeshSimulatorViewState extends ConsumerState<MeshSimulatorView> with TickerProviderStateMixin {
  final TextEditingController _nodeNameController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _nodeNameController.dispose();
    _logScrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<bool> _requestNearbyPermissions() async {
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
    ].request();

    final locationGranted = statuses[Permission.location]?.isGranted ?? false;
    final scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? true;
    final connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? true;
    final advertiseGranted = statuses[Permission.bluetoothAdvertise]?.isGranted ?? true;

    return locationGranted && scanGranted && connectGranted && advertiseGranted;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logScrollController.hasClients) {
        _logScrollController.animateTo(
          _logScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(simulationNodesProvider);
    final simNotifier = ref.read(simulationNodesProvider.notifier);
    
    final simLogs = ref.watch(simLogsProvider).value ?? '';
    final routingLogs = ref.watch(routingLogsProvider).value ?? '';

    _scrollToBottom();

    return Column(
      children: [
        // Mode Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.radar_rounded, color: AppTheme.mintGreen, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Virtual Mesh Mode",
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.textColorPrimary),
                  ),
                ],
              ),
              Switch(
                value: ref.watch(simulationModeProvider),
                activeColor: AppTheme.mintGreen,
                onChanged: (val) async {
                  if (val == false) {
                    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            "Native Nearby Connections is only supported on Android. Please use the Virtual Mesh Simulator.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppTheme.crimsonRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      return;
                    }

                    final granted = await _requestNearbyPermissions();
                    if (!granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            "Permissions are required to scan for real nearby devices.",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: AppTheme.crimsonRed,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                      return;
                    }
                  }
                  ref.read(simulationModeProvider.notifier).state = val;
                },
              ),
            ],
          ),
        ),

        // Simulator Interactive Grid Canvas
        Expanded(
          flex: 5,
          child: Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.obsidianBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.borderLight, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Grid background pattern
                      Positioned.fill(
                        child: CustomPaint(
                          painter: GridPainter(),
                        ),
                      ),
                      
                      // Topology Links (Edges) and expanding pulse waves
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: TopologyPainter(
                                nodes: nodes,
                                hostX: simNotifier.hostX,
                                hostY: simNotifier.hostY,
                                hostOnline: simNotifier.hostOnline,
                                progress: _pulseController.value,
                              ),
                            );
                          },
                        ),
                      ),

                      // Host Device Node (My Device)
                      Positioned(
                        left: simNotifier.hostX - 31,
                        top: simNotifier.hostY - 35,
                        child: _buildDraggableNode(
                          id: 'host-device',
                          name: 'Host (Me)',
                          avatar: '📱',
                          isOnline: simNotifier.hostOnline,
                          onDrag: (dx, dy) {
                            simNotifier.moveHost(
                              (simNotifier.hostX + dx).clamp(31.0, constraints.maxWidth - 31.0),
                              (simNotifier.hostY + dy).clamp(35.0, constraints.maxHeight - 45.0),
                            );
                          },
                          onToggle: () {
                            simNotifier.toggleHost(!simNotifier.hostOnline);
                          },
                        ),
                      ),

                      // Discovered Peer Nodes
                      ...nodes.map((node) {
                        return Positioned(
                          left: node.x - 31,
                          top: node.y - 35,
                          child: _buildDraggableNode(
                            id: node.deviceId,
                            name: node.name,
                            avatar: node.deviceId == 'node-b' ? '👦' : node.deviceId == 'node-c' ? '👧' : '👩',
                            isOnline: node.isOnline,
                            onDrag: (dx, dy) {
                              simNotifier.moveNode(
                                node.deviceId,
                                (node.x + dx).clamp(31.0, constraints.maxWidth - 31.0),
                                (node.y + dy).clamp(35.0, constraints.maxHeight - 45.0),
                              );
                            },
                            onToggle: () {
                              simNotifier.toggleNode(node.deviceId, !node.isOnline);
                            },
                            onMessage: () => _openMockDirectChat(context, node),
                          ),
                        );
                      }).toList(),

                      // Floating Button to Add Node
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: AnimatedPress(
                          onTap: () => _showAddNodeDialog(context, simNotifier, constraints),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.premiumBlueGradient,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.electricBlue.withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),

        // Simulation Hops Trace Log Console
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF04060A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.terminal_rounded, size: 16, color: AppTheme.electricBlueLight),
                        SizedBox(width: 8),
                        Text(
                          "SIMULATION NETWORK TRACE",
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppTheme.electricBlueLight,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    controller: _logScrollController,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      Text(
                        simLogs.isNotEmpty ? simLogs : "Waiting for simulator packets...",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        routingLogs.isNotEmpty ? routingLogs : "",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.4,
                          color: Color(0xFF60A5FA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDraggableNode({
    required String id,
    required String name,
    required String avatar,
    required bool isOnline,
    required Function(double, double) onDrag,
    required VoidCallback onToggle,
    VoidCallback? onMessage,
  }) {
    final themeColor = id == 'host-device' ? AppTheme.mintGreen : AppTheme.electricBlue;
    return GestureDetector(
      onPanUpdate: (details) {
        onDrag(details.delta.dx, details.delta.dy);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Ambient Aura Glow
              if (isOnline)
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: themeColor.withOpacity(0.05),
                    boxShadow: [
                      BoxShadow(
                        color: themeColor.withOpacity(0.12),
                        blurRadius: 12,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              // Main Avatar Node Wrapper
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceColor,
                  border: Border.all(
                    color: isOnline ? themeColor : AppTheme.textColorSecondary.withOpacity(0.4),
                    width: 2.0,
                  ),
                ),
                child: Center(
                  child: Text(
                    avatar,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              // Status Indicator Badge
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? AppTheme.mintGreen : AppTheme.crimsonRed,
                    border: Border.all(color: AppTheme.obsidianBackground, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Tooltip name label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: themeColor.withOpacity(0.25), width: 0.5),
            ),
            child: Text(
              name.length > 10 ? "${name.substring(0, 8)}..." : name,
              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          // Control Actions Row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isOnline ? AppTheme.crimsonRed : AppTheme.mintGreen).withOpacity(0.15),
                  ),
                  child: Icon(
                    isOnline ? Icons.power_settings_new_rounded : Icons.power_rounded,
                    size: 12,
                    color: isOnline ? AppTheme.crimsonRed : AppTheme.mintGreen,
                  ),
                ),
              ),
              if (onMessage != null && isOnline) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onMessage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.mintGreen.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 12,
                      color: AppTheme.mintGreen,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context, SimulationNodesNotifier notifier, BoxConstraints bounds) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Create Virtual Node", style: TextStyle(color: AppTheme.textColorPrimary, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _nodeNameController,
            style: const TextStyle(color: AppTheme.textColorPrimary, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: "Enter node name (e.g. David)",
              hintStyle: TextStyle(color: AppTheme.textColorSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(color: AppTheme.textColorSecondary, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nodeNameController.text.trim();
                if (name.isNotEmpty) {
                  notifier.addNode(
                    name,
                    bounds.maxWidth / 2,
                    bounds.maxHeight / 2,
                  );
                  _nodeNameController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: const Text("Spawn Node"),
            )
          ],
        );
      },
    );
  }

  void _openMockDirectChat(BuildContext context, SimulatedNode node) async {
    final storage = ref.read(storageServiceProvider);
    final profile = ref.read(profileProvider);

    final mockUser = UserModel(
      userId: node.deviceId,
      name: node.name,
      profilePicture: node.profilePicture,
      deviceId: node.deviceId,
      publicKey: "mock_public_key_for_${node.deviceId}",
      createdAt: DateTime.now(),
    );

    await storage.saveUser(mockUser);

    await ref.read(chatsProvider.notifier).createChat(
      node.name,
      'individual',
      [profile!.userId, node.deviceId],
      customId: node.deviceId,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ChatDetailsScreen(chatId: node.deviceId, chatName: node.name),
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
}

// --- Background Grid Lines Painter ---
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.borderLight.withOpacity(0.12)
      ..strokeWidth = 1.0;

    const double step = 25.0;
    for (double i = 0; i < size.width; i += step) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += step) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- Topology Link Painter (Marching Dots Animation) ---
class TopologyPainter extends CustomPainter {
  final List<SimulatedNode> nodes;
  final double hostX;
  final double hostY;
  final bool hostOnline;
  final double progress; // 0.0 to 1.0 driving packet/ripple movement

  TopologyPainter({
    required this.nodes,
    required this.hostX,
    required this.hostY,
    required this.hostOnline,
    required this.progress,
  });

  double _distance(double x1, double y1, double x2, double y2) {
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.electricBlue.withOpacity(0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = AppTheme.electricBlueLight
      ..style = PaintingStyle.fill;

    const double range = 180.0;
    const double rangeSquare = range * range;

    // 1. Draw periodic expanding beacon ripple waves around active nodes
    if (hostOnline) {
      final double rippleRadius = (progress * range);
      final paintRipple = Paint()
        ..color = AppTheme.mintGreen.withOpacity((1.0 - progress).clamp(0.0, 1.0) * 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(hostX, hostY), rippleRadius, paintRipple);
    }

    for (var node in nodes) {
      if (!node.isOnline) continue;
      final double rippleRadius = (progress * range);
      final paintRipple = Paint()
        ..color = AppTheme.electricBlue.withOpacity((1.0 - progress).clamp(0.0, 1.0) * 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(node.x, node.y), rippleRadius, paintRipple);
    }

    // 2. Draw marching ant dot routes between host and neighbors
    if (hostOnline) {
      for (var node in nodes) {
        if (!node.isOnline) continue;
        final distSq = _distance(hostX, hostY, node.x, node.y);
        if (distSq <= rangeSquare) {
          canvas.drawLine(Offset(hostX, hostY), Offset(node.x, node.y), paintLine);
          
          // Marching packet dots along paths
          final double length = double.parse(distSq.toString());
          final double actualDist = double.parse(length.toString()); 
          // Re-calculate math vector
          final double dx = node.x - hostX;
          final double dy = node.y - hostY;
          final int dotCount = 4;
          for (int k = 0; k < dotCount; k++) {
            final double fraction = ((k / dotCount) + progress) % 1.0;
            canvas.drawCircle(Offset(hostX + dx * fraction, hostY + dy * fraction), 3.0, paintDot);
          }
        }
      }
    }

    // 3. Draw marching ant dot routes between peer nodes
    for (int i = 0; i < nodes.length; i++) {
      final n1 = nodes[i];
      if (!n1.isOnline) continue;

      for (int j = i + 1; j < nodes.length; j++) {
        final n2 = nodes[j];
        if (!n2.isOnline) continue;

        final distSq = _distance(n1.x, n1.y, n2.x, n2.y);
        if (distSq <= rangeSquare) {
          canvas.drawLine(Offset(n1.x, n1.y), Offset(n2.x, n2.y), paintLine);

          // Marching packets
          final double dx = n2.x - n1.x;
          final double dy = n2.y - n1.y;
          final int dotCount = 4;
          for (int k = 0; k < dotCount; k++) {
            final double fraction = ((k / dotCount) + progress) % 1.0;
            canvas.drawCircle(Offset(n1.x + dx * fraction, n1.y + dy * fraction), 3.0, paintDot);
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) => true;
}
