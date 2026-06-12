import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_chat/data/models/storage_models.dart';
import 'package:offline_mesh_chat/data/services/mock_communication_service.dart';
import 'package:offline_mesh_chat/data/services/routing_service.dart';
import 'package:offline_mesh_chat/data/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mesh Routing & Store-and-Forward Tests', () {
    late MockCommunicationService mockComm;
    late StorageService storage;
    late RoutingService routing;

    setUp(() async {
      mockComm = MockCommunicationService();
      storage = StorageService();
      routing = RoutingService();

      // Initialize storage and clear previous boxes
      await storage.init();
      await storage.clearAllData();

      // Mock user profiles
      await storage.saveMyProfile(UserModel(
        userId: 'host-device',
        name: 'My Device',
        profilePicture: '',
        deviceId: 'host-device',
        publicKey: '',
        createdAt: DateTime.now(),
      ));

      mockComm.setHostDetails('host-device', 'My Device', '');
      
      // Initialize routing service with the mock communication service
      await routing.init(mockComm);
    });

    test('DSDV Route Calculation (Multi-Hop Line)', () async {
      // Setup chain: Host (250, 250) <-> Node B (250, 350) <-> Node C (250, 450) <-> Node D (250, 550)
      // Ranges: 180 pixels.
      // Distances:
      // Host - B: 100 px (Within range)
      // B - C: 100 px (Within range)
      // C - D: 100 px (Within range)
      // Host - C: 200 px (Out of range, multi-hop via B)
      // Host - D: 300 px (Out of range, multi-hop via B)

      mockComm.nodes.clear();
      mockComm.nodes.addAll([
        SimulatedNode(deviceId: 'node-b', name: 'Bob', profilePicture: '', x: 250, y: 350),
        SimulatedNode(deviceId: 'node-c', name: 'Charlie', profilePicture: '', x: 250, y: 450),
        SimulatedNode(deviceId: 'node-d', name: 'Diana', profilePicture: '', x: 250, y: 550),
      ]);

      // Manually trigger Bellman-Ford updates
      // We run it three times to propagate tables through 3 hops
      for (int i = 0; i < 4; i++) {
        // Access private method helper by replicating exchange
        // Since we exposed it inside MockCommunicationService, we can just trigger coordinate calculations
        mockComm.updateNodePosition('host-device', 250, 250);
      }

      // Assert routing table sizes
      final routes = mockComm.nodes;
      
      // Node B is direct neighbor of Host, cost should be 1
      final nodeB = routes.firstWhere((n) => n.deviceId == 'node-b');
      expect(nodeB.routingTable['host-device'], equals(1));

      // Node C is connected to B, cost to Host should be 2 (Host -> B -> C)
      final nodeC = routes.firstWhere((n) => n.deviceId == 'node-c');
      expect(nodeC.routingTable['host-device'], equals(2));

      // Node D is connected to C, cost to Host should be 3 (Host -> B -> C -> D)
      final nodeD = routes.firstWhere((n) => n.deviceId == 'node-d');
      expect(nodeD.routingTable['host-device'], equals(3));
      
      // Hops should resolve correctly
      expect(nodeD.nextHops['host-device'], equals('node-c'));

      // Wait a moment for stream delivery of routing announcements to Host
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert Host knows how to route to B, C, and D
      final hostRoutes = routing.routingTable;
      expect(hostRoutes['node-b'], isNotNull);
      expect(hostRoutes['node-b']!.cost, equals(1));
      expect(hostRoutes['node-b']!.nextHopId, equals('node-b'));

      expect(hostRoutes['node-c'], isNotNull);
      expect(hostRoutes['node-c']!.cost, equals(2));
      expect(hostRoutes['node-c']!.nextHopId, equals('node-b'));

      expect(hostRoutes['node-d']!.nextHopId, equals('node-b'));
    });

    test('Audio Message payload transmission and Base64 consistency', () async {
      final rawAudioBytes = List<int>.generate(200, (i) => i % 256);
      final encodedBase64 = base64Encode(rawAudioBytes);

      final decodedBytes = base64Decode(encodedBase64);
      expect(decodedBytes, equals(rawAudioBytes));

      final recipientId = 'node-b';
      
      await storage.saveRoute(RouteModel(
        destinationId: 'node-b',
        nextHopId: 'node-b',
        cost: 1,
        timestamp: DateTime.now(),
      ));
      routing.routingTable['node-b'] = RouteModel(
        destinationId: 'node-b',
        nextHopId: 'node-b',
        cost: 1,
        timestamp: DateTime.now(),
      );

      await storage.saveUser(UserModel(
        userId: 'node-b',
        name: 'Bob',
        profilePicture: '',
        deviceId: 'node-b',
        publicKey: 'mock-public-key-b',
        createdAt: DateTime.now(),
      ));

      final success = await routing.sendMessage(recipientId, encodedBase64, 'audio', chatId: 'node-b');
      expect(success, isTrue);

      final messages = storage.getMessagesForChat('node-b');
      expect(messages, isNotEmpty);
      final audioMsg = messages.firstWhere((m) => m.messageType == 'audio');
      expect(audioMsg.content, equals(encodedBase64));
    });
  });
}
