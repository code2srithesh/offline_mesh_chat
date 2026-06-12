import 'dart:async';

enum PeerConnectionStatus {
  disconnected,
  connecting,
  connected,
}

class DiscoveredPeer {
  final String deviceId;
  final String name;
  final String profilePicture;
  final String connectionEndpoint; // Platform-dependent endpoint identifier

  DiscoveredPeer({
    required this.deviceId,
    required this.name,
    required this.profilePicture,
    required this.connectionEndpoint,
  });

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'name': name,
      'profilePicture': profilePicture,
      'connectionEndpoint': connectionEndpoint,
    };
  }
}

class CommPayload {
  final String senderDeviceId;
  final String data; // Encrypted or unencrypted payload string

  CommPayload({
    required this.senderDeviceId,
    required this.data,
  });
}

abstract class CommunicationService {
  /// Stream of discovered peers list changes
  Stream<List<DiscoveredPeer>> get discoveredPeersStream;

  /// Stream of active connected peer ids
  Stream<Map<String, PeerConnectionStatus>> get connectionStatusStream;

  /// Stream of incoming payloads
  Stream<CommPayload> get incomingPayloadStream;

  /// Initialize service
  Future<void> init();

  /// Start scanning for nearby devices
  Future<void> startDiscovery();

  /// Stop scanning
  Future<void> stopDiscovery();

  /// Start advertising self to nearby devices
  Future<void> startAdvertising(String name, String profilePictureBase64);

  /// Stop advertising
  Future<void> stopAdvertising();

  /// Initiate connection request to a discovered peer
  Future<void> connectToPeer(DiscoveredPeer peer);

  /// Disconnect from a specific peer
  Future<void> disconnectFromPeer(String deviceId);

  /// Send raw payload to a direct neighbor
  Future<bool> sendPayload(String targetDeviceId, String data);

  /// Get direct active connections list
  Map<String, PeerConnectionStatus> get activeConnections;
}
