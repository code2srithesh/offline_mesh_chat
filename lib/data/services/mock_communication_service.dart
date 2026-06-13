import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'communication_service.dart';

class SimulatedNode {
  final String deviceId;
  String name;
  String profilePicture;
  double x;
  double y;
  bool isOnline;
  
  // Local states inside virtual node for routing simulation
  Map<String, int> routingTable = {}; // destinationDeviceId -> cost
  Map<String, String> nextHops = {}; // destinationDeviceId -> nextHopId
  List<Map<String, dynamic>> storeAndForwardQueue = [];

  SimulatedNode({
    required this.deviceId,
    required this.name,
    required this.profilePicture,
    required this.x,
    required this.y,
    this.isOnline = true,
  });
}

class MockCommunicationService implements CommunicationService {
  static final MockCommunicationService _instance = MockCommunicationService._internal();
  factory MockCommunicationService() => _instance;

  final StreamController<List<DiscoveredPeer>> _discoveredPeersController =
      StreamController<List<DiscoveredPeer>>.broadcast();
  final StreamController<Map<String, PeerConnectionStatus>> _connectionStatusController =
      StreamController<Map<String, PeerConnectionStatus>>.broadcast();
  final StreamController<CommPayload> _incomingPayloadController =
      StreamController<CommPayload>.broadcast();

  @override
  Stream<List<DiscoveredPeer>> get discoveredPeersStream => _discoveredPeersController.stream;
  @override
  Stream<Map<String, PeerConnectionStatus>> get connectionStatusStream =>
      _connectionStatusController.stream;
  @override
  Stream<CommPayload> get incomingPayloadStream => _incomingPayloadController.stream;

  // Global simulation nodes (Host is always represented by the app user)
  final List<SimulatedNode> nodes = [];
  String _hostId = "host-device";
  String _hostName = "My Device";
  String _hostProfilePic = "";
  double hostX = 250;
  double hostY = 250;
  bool hostOnline = true;

  final Map<String, PeerConnectionStatus> _activeConnections = {};
  Timer? _simulationTimer;
  
  // Custom stream for UI to update simulation logs/topology
  final StreamController<String> _simLogController = StreamController<String>.broadcast();
  Stream<String> get simLogStream => _simLogController.stream;

  MockCommunicationService._internal() {
    // Add default mock nodes for campus scenario
    nodes.addAll([
      SimulatedNode(deviceId: 'node-b', name: 'Bob (Classroom A)', profilePicture: 'avatar_b', x: 250, y: 120),
      SimulatedNode(deviceId: 'node-c', name: 'Charlie (Library)', profilePicture: 'avatar_c', x: 380, y: 150),
      SimulatedNode(deviceId: 'node-d', name: 'Diana (Cafeteria)', profilePicture: 'avatar_d', x: 450, y: 300),
    ]);
  }

  void logSim(String message) {
    print("[SIMULATOR] $message");
    _simLogController.add("[${DateTime.now().toString().substring(11, 19)}] $message");
  }

  @override
  Future<void> init() async {
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _startSimulationLoop();
      updateSimulationState();
    }
    logSim("Simulation initialized.");
  }

  void setHostDetails(String id, String name, String profilePic) {
    _hostId = id;
    _hostName = name;
    _hostProfilePic = profilePic;
  }

  @override
  Map<String, PeerConnectionStatus> get activeConnections => _activeConnections;

  @override
  Future<void> startDiscovery() async {
    logSim("Discovery started.");
  }

  @override
  Future<void> stopDiscovery() async {
    logSim("Discovery stopped.");
  }

  @override
  Future<void> startAdvertising(String name, String profilePictureBase64) async {
    _hostName = name;
    _hostProfilePic = profilePictureBase64;
    logSim("Advertising started for $_hostName.");
  }

  @override
  Future<void> stopAdvertising() async {
    logSim("Advertising stopped.");
  }

  @override
  Future<void> connectToPeer(DiscoveredPeer peer) async {
    logSim("Connecting to peer ${peer.name}...");
    _activeConnections[peer.deviceId] = PeerConnectionStatus.connecting;
    _connectionStatusController.add(Map.from(_activeConnections));

    await Future.delayed(const Duration(milliseconds: 600));
    _activeConnections[peer.deviceId] = PeerConnectionStatus.connected;
    _connectionStatusController.add(Map.from(_activeConnections));
    logSim("Connected to ${peer.name}.");
  }

  @override
  Future<void> disconnectFromPeer(String deviceId) async {
    _activeConnections[deviceId] = PeerConnectionStatus.disconnected;
    _connectionStatusController.add(Map.from(_activeConnections));
    logSim("Disconnected from $deviceId.");
  }

  @override
  Future<bool> sendPayload(String targetDeviceId, String data) async {
    // Deliver payload to virtual node target
    if (!hostOnline) return false;
    
    // Check if direct link exists
    final targetNode = nodes.firstWhere((n) => n.deviceId == targetDeviceId, orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0));
    if (targetNode.deviceId.isEmpty || !targetNode.isOnline) return false;

    final dist = _calculateDistance(hostX, hostY, targetNode.x, targetNode.y);
    if (dist > 180) {
      logSim("Send failed: $targetDeviceId out of range.");
      return false;
    }

    logSim("Host -> Direct payload sent to ${targetNode.name}");
    _relayPayloadToNode(targetNode, _hostId, data);
    return true;
  }

  // --- Simulator Engine Internals ---

  double _calculateDistance(double x1, double y1, double x2, double y2) {
    return sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
  }

  void updateSimulationState() {
    if (!hostOnline) {
      final Map<String, PeerConnectionStatus> newStatuses = Map.from(_activeConnections);
      newStatuses.forEach((key, val) {
        if (val != PeerConnectionStatus.disconnected) {
          newStatuses[key] = PeerConnectionStatus.disconnected;
        }
      });
      _updateActiveConnections(newStatuses);
      return;
    }

    final List<DiscoveredPeer> discovered = [];
    final Map<String, PeerConnectionStatus> newStatuses = Map.from(_activeConnections);

    for (var node in nodes) {
      if (!node.isOnline) {
        if (_activeConnections[node.deviceId] != PeerConnectionStatus.disconnected) {
          newStatuses[node.deviceId] = PeerConnectionStatus.disconnected;
          logSim("Peer ${node.name} went offline.");
        }
        continue;
      }

      final dist = _calculateDistance(hostX, hostY, node.x, node.y);
      
      if (dist <= 180) {
        // In discovery range
        discovered.add(DiscoveredPeer(
          deviceId: node.deviceId,
          name: node.name,
          profilePicture: node.profilePicture,
          connectionEndpoint: "sim_${node.deviceId}",
        ));

        // Auto connect if not connected/connecting
        if (_activeConnections[node.deviceId] == null ||
            _activeConnections[node.deviceId] == PeerConnectionStatus.disconnected) {
          newStatuses[node.deviceId] = PeerConnectionStatus.connected;
          logSim("Discovered & Auto-connected to ${node.name}");
        }
      } else {
        // Out of range
        if (_activeConnections[node.deviceId] != PeerConnectionStatus.disconnected) {
          newStatuses[node.deviceId] = PeerConnectionStatus.disconnected;
          logSim("Lost connection to ${node.name} (Out of range).");
        }
      }
    }

    // Update controllers
    _discoveredPeersController.add(discovered);
    _updateActiveConnections(newStatuses);

    // Run virtual routing table exchange & updates among virtual nodes
    exchangeVirtualRoutingTables();
  }

  void _updateActiveConnections(Map<String, PeerConnectionStatus> newStatuses) {
    bool statusChanged = false;
    newStatuses.forEach((key, val) {
      if (_activeConnections[key] != val) {
        _activeConnections[key] = val;
        statusChanged = true;
      }
    });
    if (statusChanged) {
      _connectionStatusController.add(Map.from(_activeConnections));
    }
  }

  void _startSimulationLoop() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      updateSimulationState();
    });
  }

  /// Handles incoming payloads received by virtual nodes or the Host
  void _relayPayloadToNode(SimulatedNode targetNode, String senderId, String data) {
    // Simulating packet arrival delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!targetNode.isOnline) return;
      
      // Parse payload
      try {
        final packet = json.decode(data) as Map<String, dynamic>;
        final String type = packet['payloadType'] ?? 'mesh_message';
        final String msgId = packet['messageId'] ?? '';
        final String receiverId = packet['receiverId'] ?? '';
        
        logSim("Node ${targetNode.name} received packet of type '$type' from $senderId");

        if (type == 'routing_announcement') {
          // Routing announcements are direct 1-hop link local broadcasts. Ignore or log.
          return;
        }

        if (receiverId == targetNode.deviceId) {
          // Target node received the message!
          logSim("🎉 Node ${targetNode.name} received message destined for it: '${packet['content']}'!");
        } else if (receiverId.isEmpty && type == 'sos_broadcast') {
          // SOS Flooding
          logSim("🚨 Node ${targetNode.name} received SOS Alert!");
          _floodSOS(targetNode, packet, data);
        } else {
          // Forwarding logic inside virtual node
          _forwardPacketFromNode(targetNode, packet, data);
        }
      } catch (e) {
        logSim("Error processing packet at ${targetNode.name}: $e");
      }
    });
  }

  void _forwardPacketFromNode(SimulatedNode node, Map<String, dynamic> packet, String rawData) {
    final receiverId = packet['receiverId'] as String? ?? '';
    if (receiverId.isEmpty) return;
    
    final hops = List<String>.from(packet['hops'] ?? []);
    
    if (hops.contains(node.deviceId)) {
      logSim("Node ${node.name} dropping packet to avoid routing loops");
      return;
    }
    
    hops.add(node.deviceId);
    packet['hops'] = hops;
    final updatedRawData = json.encode(packet);

    // Look up next hop in virtual node's routing table
    final nextHop = node.nextHops[receiverId];
    if (nextHop != null && nextHop.isNotEmpty) {
      logSim("Node ${node.name} forwarding packet for $receiverId -> Next Hop: $nextHop");
      _sendPayloadBetweenNodes(node.deviceId, nextHop, updatedRawData);
    } else {
      // Store and forward!
      logSim("Node ${node.name} has no route to $receiverId. Queueing message for store-and-forward...");
      node.storeAndForwardQueue.add(packet);
    }
  }

  void _sendPayloadBetweenNodes(String sourceId, String destId, String rawData) {
    if (destId == _hostId) {
      // Send to Host
      if (hostOnline) {
        final sourceNode = nodes.firstWhere(
          (n) => n.deviceId == sourceId,
          orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0),
        );
        if (sourceNode.deviceId.isNotEmpty) {
          final dist = _calculateDistance(hostX, hostY, sourceNode.x, sourceNode.y);
          if (dist <= 180) {
            _incomingPayloadController.add(CommPayload(senderDeviceId: sourceId, data: rawData));
          }
        }
      }
      return;
    }

    final destNode = nodes.firstWhere((n) => n.deviceId == destId, orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0));
    if (destNode.deviceId.isEmpty || !destNode.isOnline) return;

    final sourceNode = nodes.firstWhere((n) => n.deviceId == sourceId, orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0));
    final sourceX = sourceId == _hostId ? hostX : sourceNode.x;
    final sourceY = sourceId == _hostId ? hostY : sourceNode.y;

    final dist = _calculateDistance(sourceX, sourceY, destNode.x, destNode.y);
    if (dist <= 180) {
      _relayPayloadToNode(destNode, sourceId, rawData);
    } else {
      logSim("Payload from $sourceId -> $destId failed: Out of physical range.");
    }
  }

  void _floodSOS(SimulatedNode originNode, Map<String, dynamic> packet, String rawData) {
    final hops = List<String>.from(packet['hops'] ?? []);
    if (hops.contains(originNode.deviceId)) return;
    
    hops.add(originNode.deviceId);
    packet['hops'] = hops;
    final updatedRawData = json.encode(packet);

    // Flood to all neighbors except those already in hops list
    for (var neighbor in nodes) {
      if (neighbor.deviceId == originNode.deviceId || !neighbor.isOnline) continue;
      
      final dist = _calculateDistance(originNode.x, originNode.y, neighbor.x, neighbor.y);
      if (dist <= 180 && !hops.contains(neighbor.deviceId)) {
        logSim("Node ${originNode.name} flooding SOS alert to ${neighbor.name}");
        _relayPayloadToNode(neighbor, originNode.deviceId, updatedRawData);
      }
    }

    // Also flood to Host if direct neighbor
    final distHost = _calculateDistance(originNode.x, originNode.y, hostX, hostY);
    if (distHost <= 180 && !hops.contains(_hostId) && hostOnline) {
      logSim("Node ${originNode.name} flooding SOS alert to Host");
      _incomingPayloadController.add(CommPayload(senderDeviceId: originNode.deviceId, data: updatedRawData));
    }
  }

  /// Simulates DSDV Routing table exchange between nodes
  void exchangeVirtualRoutingTables() {
    // 1. Reset routing tables of all virtual nodes to initial direct links
    for (var node in nodes) {
      node.routingTable.clear();
      node.nextHops.clear();
      
      // Every node knows about itself with cost 0
      node.routingTable[node.deviceId] = 0;
      node.nextHops[node.deviceId] = node.deviceId;
    }

    // Include Host
    final Map<String, int> hostRoutingTable = {_hostId: 0};
    
    // 2. Discover direct links based on distances
    final allNodes = [...nodes];
    
    for (int i = 0; i < allNodes.length; i++) {
      final n1 = allNodes[i];
      if (!n1.isOnline) continue;

      // Check distance to Host
      final distToHost = _calculateDistance(n1.x, n1.y, hostX, hostY);
      if (distToHost <= 180 && hostOnline) {
        n1.routingTable[_hostId] = 1;
        n1.nextHops[_hostId] = _hostId;
        hostRoutingTable[n1.deviceId] = 1;
      }

      for (int j = i + 1; j < allNodes.length; j++) {
        final n2 = allNodes[j];
        if (!n2.isOnline) continue;

        final dist = _calculateDistance(n1.x, n1.y, n2.x, n2.y);
        if (dist <= 180) {
          n1.routingTable[n2.deviceId] = 1;
          n1.nextHops[n2.deviceId] = n2.deviceId;

          n2.routingTable[n1.deviceId] = 1;
          n2.nextHops[n1.deviceId] = n1.deviceId;
        }
      }
    }

    // 3. Propagate routing tables (run Bellman-Ford algorithm multiple passes)
    bool tableChanged = true;
    int passes = 0;
    
    while (tableChanged && passes < nodes.length) {
      tableChanged = false;
      passes++;

      // Share routing updates between online neighbors
      for (var n1 in nodes) {
        if (!n1.isOnline) continue;

        for (var n2 in nodes) {
          if (n1.deviceId == n2.deviceId || !n2.isOnline) continue;

          final dist = _calculateDistance(n1.x, n1.y, n2.x, n2.y);
          if (dist <= 180) {
            // Direct neighbors - exchange tables
            n2.routingTable.forEach((dest, cost) {
              final currentKnownCost = n1.routingTable[dest] ?? 999;
              if (cost + 1 < currentKnownCost) {
                n1.routingTable[dest] = cost + 1;
                n1.nextHops[dest] = n2.deviceId;
                tableChanged = true;
              }
            });
          }
        }

        // Host link routing exchange
        final distToHost = _calculateDistance(n1.x, n1.y, hostX, hostY);
        if (distToHost <= 180 && hostOnline) {
          // Host sharing with neighbor
          hostRoutingTable.forEach((dest, cost) {
            final currentKnownCost = n1.routingTable[dest] ?? 999;
            if (cost + 1 < currentKnownCost) {
              n1.routingTable[dest] = cost + 1;
              n1.nextHops[dest] = _hostId;
              tableChanged = true;
            }
          });
        }
      }
    }

    // Send routing announcements to Host from all active direct neighbors
    if (hostOnline) {
      for (var node in nodes) {
        if (!node.isOnline) continue;
        final dist = _calculateDistance(node.x, node.y, hostX, hostY);
        if (dist <= 180) {
          final Map<String, Map<String, dynamic>> routesData = {};
          node.routingTable.forEach((dest, cost) {
            routesData[dest] = {
              'cost': cost,
            };
          });

          final announcement = {
            'payloadType': 'routing_announcement',
            'senderId': node.deviceId,
            'routingTable': routesData,
          };

          _incomingPayloadController.add(
            CommPayload(
              senderDeviceId: node.deviceId,
              data: json.encode(announcement),
            ),
          );
        }
      }
    }

    // 4. Try to flush store-and-forward queue for each virtual node if connection became available
    for (var node in nodes) {
      if (!node.isOnline) continue;
      final queue = List<Map<String, dynamic>>.from(node.storeAndForwardQueue);
      node.storeAndForwardQueue.clear();

      for (var packet in queue) {
        final dest = packet['receiverId'] as String? ?? '';
        if (dest.isEmpty) continue;
        final nextHop = node.nextHops[dest];
        if (nextHop != null && nextHop.isNotEmpty) {
          logSim("Node ${node.name} flushed store-and-forward message destined for $dest -> next hop $nextHop");
          _forwardPacketFromNode(node, packet, json.encode(packet));
        } else {
          // Keep in queue
          node.storeAndForwardQueue.add(packet);
        }
      }
    }
  }

  void addSimulatedNode(SimulatedNode node) {
    nodes.add(node);
    updateSimulationState();
    logSim("Created simulated node: ${node.name}");
  }

  void updateNodePosition(String id, double x, double y) {
    if (id == _hostId || id == 'host-device') {
      hostX = x;
      hostY = y;
    } else {
      final node = nodes.firstWhere((n) => n.deviceId == id, orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0));
      if (node.deviceId.isNotEmpty) {
        node.x = x;
        node.y = y;
      }
    }
    updateSimulationState();
    logSim("Updated position of $id to: ($x, $y)");
  }

  void toggleNodeStatus(String id, bool online) {
    if (id == _hostId || id == 'host-device') {
      hostOnline = online;
    } else {
      final node = nodes.firstWhere((n) => n.deviceId == id, orElse: () => SimulatedNode(deviceId: '', name: '', profilePicture: '', x: 0, y: 0));
      if (node.deviceId.isNotEmpty) {
        node.isOnline = online;
      }
    }
    updateSimulationState();
    logSim("Toggled status of $id to: ${online ? 'online' : 'offline'}");
  }

  void dispose() {
    _simulationTimer?.cancel();
    _discoveredPeersController.close();
    _connectionStatusController.close();
    _incomingPayloadController.close();
    _simLogController.close();
  }
}
