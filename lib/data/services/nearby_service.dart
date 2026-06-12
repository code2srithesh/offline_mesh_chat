import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'communication_service.dart';

class NearbyService implements CommunicationService {
  static final NearbyService _instance = NearbyService._internal();
  factory NearbyService() => _instance;

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

  final Map<String, PeerConnectionStatus> _activeConnections = {};
  final Map<String, DiscoveredPeer> _discoveredPeers = {};

  final Strategy strategy = Strategy.P2P_CLUSTER;

  NearbyService._internal();

  @override
  Map<String, PeerConnectionStatus> get activeConnections => _activeConnections;

  @override
  Future<void> init() async {
    print("NearbyService initialized.");
  }

  bool get _isSupported => !kIsWeb && Platform.isAndroid;

  @override
  Future<void> startDiscovery() async {
    if (!_isSupported) {
      print("Discovery only supported on Android native.");
      return;
    }

    try {
      await Nearby().startDiscovery(
        "my_user_id", // We will substitute this
        strategy,
        onEndpointFound: (id, name, serviceId) {
          // Parse user information encoded in endpoint name
          // We can encode device information in the name: e.g. "name|deviceId|avatar"
          String peerName = name;
          String peerId = id;
          String avatar = "";

          final parts = name.split('|');
          if (parts.length >= 3) {
            peerName = parts[0];
            peerId = parts[1];
            avatar = parts[2];
          }

          final peer = DiscoveredPeer(
            deviceId: peerId,
            name: peerName,
            profilePicture: avatar,
            connectionEndpoint: id,
          );

          _discoveredPeers[id] = peer;
          _discoveredPeersController.add(_discoveredPeers.values.toList());
          
          // Auto connect
          connectToPeer(peer);
        },
        onEndpointLost: (id) {
          _discoveredPeers.remove(id);
          _discoveredPeersController.add(_discoveredPeers.values.toList());
        },
        serviceId: "com.offlinemesh.chat",
      );
    } catch (e) {
      print("Start discovery failed: $e");
    }
  }

  @override
  Future<void> stopDiscovery() async {
    if (!_isSupported) return;
    await Nearby().stopDiscovery();
    _discoveredPeers.clear();
    _discoveredPeersController.add([]);
  }

  @override
  Future<void> startAdvertising(String name, String profilePictureBase64) async {
    if (!_isSupported) {
      print("Advertising only supported on Android native.");
      return;
    }

    // Encode name, deviceId, and short picture hash into advertisement name (max limit is 130 bytes)
    final advName = "$name|android_device|${profilePictureBase64.substring(0, min(10, profilePictureBase64.length))}";

    try {
      await Nearby().startAdvertising(
        advName,
        strategy,
        onConnectionInitiated: (id, info) async {
          // Auto-accept connection requests
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (payload.type == PayloadType.BYTES) {
                final text = utf8.decode(payload.bytes!);
                
                // Find peer deviceId
                final peer = _discoveredPeers[endpointId];
                final peerId = peer?.deviceId ?? endpointId;

                _incomingPayloadController.add(CommPayload(
                  senderDeviceId: peerId,
                  data: text,
                ));
              }
            },
            onPayloadTransferUpdate: (endpointId, update) {},
          );
        },
        onConnectionResult: (id, status) {
          final peer = _discoveredPeers[id];
          final peerId = peer?.deviceId ?? id;

          if (status == Status.CONNECTED) {
            _activeConnections[peerId] = PeerConnectionStatus.connected;
          } else {
            _activeConnections[peerId] = PeerConnectionStatus.disconnected;
          }
          _connectionStatusController.add(Map.from(_activeConnections));
        },
        onDisconnected: (id) {
          final peer = _discoveredPeers[id];
          final peerId = peer?.deviceId ?? id;
          _activeConnections[peerId] = PeerConnectionStatus.disconnected;
          _connectionStatusController.add(Map.from(_activeConnections));
        },
        serviceId: "com.offlinemesh.chat",
      );
    } catch (e) {
      print("Start advertising failed: $e");
    }
  }

  @override
  Future<void> stopAdvertising() async {
    if (!_isSupported) return;
    await Nearby().stopAdvertising();
  }

  @override
  Future<void> connectToPeer(DiscoveredPeer peer) async {
    if (!_isSupported) return;
    
    _activeConnections[peer.deviceId] = PeerConnectionStatus.connecting;
    _connectionStatusController.add(Map.from(_activeConnections));

    try {
      await Nearby().requestConnection(
        "my_user_id",
        peer.connectionEndpoint,
        onConnectionInitiated: (id, info) async {
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (endpointId, payload) {
              if (payload.type == PayloadType.BYTES) {
                final text = utf8.decode(payload.bytes!);
                _incomingPayloadController.add(CommPayload(
                  senderDeviceId: peer.deviceId,
                  data: text,
                ));
              }
            },
            onPayloadTransferUpdate: (endpointId, update) {},
          );
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _activeConnections[peer.deviceId] = PeerConnectionStatus.connected;
          } else {
            _activeConnections[peer.deviceId] = PeerConnectionStatus.disconnected;
          }
          _connectionStatusController.add(Map.from(_activeConnections));
        },
        onDisconnected: (id) {
          _activeConnections[peer.deviceId] = PeerConnectionStatus.disconnected;
          _connectionStatusController.add(Map.from(_activeConnections));
        },
      );
    } catch (e) {
      print("Connect to peer failed: $e");
      _activeConnections[peer.deviceId] = PeerConnectionStatus.disconnected;
      _connectionStatusController.add(Map.from(_activeConnections));
    }
  }

  @override
  Future<void> disconnectFromPeer(String deviceId) async {
    if (!_isSupported) return;
    
    // Find matching endpoint
    final endpointId = _discoveredPeers.entries
        .firstWhere(
          (entry) => entry.value.deviceId == deviceId,
          orElse: () => MapEntry('', DiscoveredPeer(deviceId: '', name: '', profilePicture: '', connectionEndpoint: '')),
        )
        .key;

    if (endpointId.isNotEmpty) {
      await Nearby().disconnectFromEndpoint(endpointId);
      _activeConnections[deviceId] = PeerConnectionStatus.disconnected;
      _connectionStatusController.add(Map.from(_activeConnections));
    }
  }

  @override
  Future<bool> sendPayload(String targetDeviceId, String data) async {
    if (!_isSupported) return false;

    // Find endpoint
    final endpointId = _discoveredPeers.entries
        .firstWhere(
          (entry) => entry.value.deviceId == targetDeviceId,
          orElse: () => MapEntry('', DiscoveredPeer(deviceId: '', name: '', profilePicture: '', connectionEndpoint: '')),
        )
        .key;

    if (endpointId.isEmpty) return false;

    try {
      final bytes = utf8.encode(data);
      await Nearby().sendBytesPayload(endpointId, bytes);
      return true;
    } catch (e) {
      print("Send bytes payload failed: $e");
      return false;
    }
  }

  int min(int a, int b) => a < b ? a : b;
}
