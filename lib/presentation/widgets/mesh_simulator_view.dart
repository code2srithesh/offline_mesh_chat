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

class _MeshSimulatorViewState extends ConsumerState<MeshSimulatorView> {
  final TextEditingController _nodeNameController = TextEditingController();
  final ScrollController _logScrollController = ScrollController();

  @override
  void dispose() {
    _nodeNameController.dispose();
    _logScrollController.dispose();
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

    // Scroll to bottom when logs update
    _scrollToBottom();

    final size = MediaQuery.of(context).size;
    final double canvasHeight = size.height * 0.42;

    return Column(
      children: [
        // Mode Controls Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.surfaceColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Simulation Mode",
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColorPrimary),
              ),
              Switch(
                value: ref.watch(simulationModeProvider),
                activeColor: AppTheme.mintGreen,
                onChanged: (val) async {
                  if (val == false) {
                    // Switching to Native Mode
                    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Native Nearby Connections is only supported on Android. Please use the Virtual Mesh Simulator.",
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppTheme.crimsonRed,
                        ),
                      );
                      return;
                    }

                    final granted = await _requestNearbyPermissions();
                    if (!granted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Permissions are required to scan for real nearby devices.",
                            style: TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppTheme.crimsonRed,
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
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
                      
                      // Topology Links (Edges)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: TopologyPainter(
                            nodes: nodes,
                            hostX: simNotifier.hostX,
                            hostY: simNotifier.hostY,
                            hostOnline: simNotifier.hostOnline,
                          ),
                        ),
                      ),

                      // Host Device Node (My Device)
                      Positioned(
                        left: simNotifier.hostX - 25,
                        top: simNotifier.hostY - 25,
                        child: _buildDraggableNode(
                          id: 'host-device',
                          name: 'Host (Me)',
                          avatar: '📱',
                          isOnline: simNotifier.hostOnline,
                          onDrag: (dx, dy) {
                            simNotifier.moveHost(
                              (simNotifier.hostX + dx).clamp(25.0, constraints.maxWidth - 25.0),
                              (simNotifier.hostY + dy).clamp(25.0, constraints.maxHeight - 25.0),
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
                          left: node.x - 25,
                          top: node.y - 25,
                          child: _buildDraggableNode(
                            id: node.deviceId,
                            name: node.name,
                            avatar: node.deviceId == 'node-b' ? '👦' : node.deviceId == 'node-c' ? '👧' : '👩',
                            isOnline: node.isOnline,
                            onDrag: (dx, dy) {
                              simNotifier.moveNode(
                                node.deviceId,
                                (node.x + dx).clamp(25.0, constraints.maxWidth - 25.0),
                                (node.y + dy).clamp(25.0, constraints.maxHeight - 25.0),
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
                        child: FloatingActionButton.small(
                          backgroundColor: AppTheme.electricBlue,
                          foregroundColor: Colors.white,
                          child: const Icon(Icons.add_location_alt_rounded),
                          onPressed: () => _showAddNodeDialog(context, simNotifier, constraints),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF070A0F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SIMULATION NETWORK TRACE",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.electricBlueLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear_all_rounded, size: 16, color: AppTheme.textColorSecondary),
                      onPressed: () {
                        // Normally clear log buffer, but simulator prints it
                      },
                    )
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    controller: _logScrollController,
                    children: [
                      Text(
                        simLogs.isNotEmpty ? simLogs : "Waiting for simulator packets...",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Color(0xFF34D399),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        routingLogs.isNotEmpty ? routingLogs : "",
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
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
    return GestureDetector(
      onPanUpdate: (details) {
        onDrag(details.delta.dx, details.delta.dy);
      },
      child: Tooltip(
        message: "$name (${isOnline ? 'Online' : 'Offline'})",
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Signal radius (visual representation when dragging or selected)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline
                        ? (id == 'host-device' ? AppTheme.mintGreen : AppTheme.electricBlue).withOpacity(0.15)
                        : Colors.grey.withOpacity(0.1),
                    border: Border.all(
                      color: isOnline
                          ? (id == 'host-device' ? AppTheme.mintGreen : AppTheme.electricBlue)
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      avatar,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),

                // Offline crossed line or status dot
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOnline ? Colors.green : Colors.red,
                      border: Border.all(color: AppTheme.obsidianBackground, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                name.length > 10 ? "${name.substring(0, 8)}..." : name,
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    isOnline ? Icons.power_settings_new_rounded : Icons.power_rounded,
                    size: 14,
                    color: isOnline ? Colors.green : Colors.red,
                  ),
                  onPressed: onToggle,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                if (onMessage != null && isOnline) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: AppTheme.textColorSecondary),
                    onPressed: onMessage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showAddNodeDialog(BuildContext context, SimulationNodesNotifier notifier, BoxConstraints bounds) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text("Create Virtual Node", style: TextStyle(color: AppTheme.textColorPrimary)),
          content: TextField(
            controller: _nodeNameController,
            decoration: const InputDecoration(
              hintText: "Enter node name (e.g. David)",
              hintStyle: TextStyle(color: AppTheme.textColorSecondary),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(color: AppTheme.textColorSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = _nodeNameController.text.trim();
                if (name.isNotEmpty) {
                  // Spawn node in the middle of canvas with slight random offset
                  final offset = bounds.maxWidth / 2;
                  notifier.addNode(
                    name,
                    offset + (bounds.maxWidth / 4) * (2 * (0.5 - bounds.maxHeight)), // Random coords
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
    // Before messaging, we must register node in Storage user registry
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

    // Create Chat session
    await ref.read(chatsProvider.notifier).createChat(
      node.name,
      'individual',
      [profile!.userId, node.deviceId],
      customId: node.deviceId,
    );

    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailsScreen(chatId: node.deviceId, chatName: node.name),
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
      ..color = AppTheme.borderLight.withOpacity(0.3)
      ..strokeWidth = 1.0;

    const double step = 20.0;
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

// --- Topology Link Painter (Distance-based Edges) ---
class TopologyPainter extends CustomPainter {
  final List<SimulatedNode> nodes;
  final double hostX;
  final double hostY;
  final bool hostOnline;

  TopologyPainter({
    required this.nodes,
    required this.hostX,
    required this.hostY,
    required this.hostOnline,
  });

  double _distance(double x1, double y1, double x2, double y2) {
    return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = AppTheme.electricBlueLight.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final paintRange = Paint()
      ..color = AppTheme.electricBlueLight.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    const double rangeSquare = 180 * 180;

    // Draw range ring around Host
    if (hostOnline) {
      canvas.drawCircle(Offset(hostX, hostY), 180, paintRange);
    }

    // Draw lines between Host and other nodes
    if (hostOnline) {
      for (var node in nodes) {
        if (!node.isOnline) continue;
        if (_distance(hostX, hostY, node.x, node.y) <= rangeSquare) {
          canvas.drawLine(Offset(hostX, hostY), Offset(node.x, node.y), paintLine);
        }
      }
    }

    // Draw lines and rings between other nodes
    for (int i = 0; i < nodes.length; i++) {
      final n1 = nodes[i];
      if (!n1.isOnline) continue;
      
      // Draw range ring around virtual nodes
      canvas.drawCircle(Offset(n1.x, n1.y), 180, paintRange);

      for (int j = i + 1; j < nodes.length; j++) {
        final n2 = nodes[j];
        if (!n2.isOnline) continue;

        if (_distance(n1.x, n1.y, n2.x, n2.y) <= rangeSquare) {
          canvas.drawLine(Offset(n1.x, n1.y), Offset(n2.x, n2.y), paintLine);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) => true;
}
