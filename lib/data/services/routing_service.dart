import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';
import '../../core/security/encryption_service.dart';
import '../models/storage_models.dart';
import 'communication_service.dart';
import 'storage_service.dart';

class RoutingService {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  final _uuid = const Uuid();
  final _storage = StorageService();
  final _encryption = EncryptionService();
  
  late CommunicationService _commService;
  StreamSubscription? _payloadSubscription;
  StreamSubscription? _connSubscription;
  Timer? _advertisementTimer;
  Timer? _queueTimer;

  // Local routing table in memory for fast operations
  final Map<String, RouteModel> _routingTable = {};
  
  // Local store-and-forward queue in memory (could also be backed by Hive)
  final List<MessageModel> _storeAndForwardQueue = [];

  // Generic packet queue for store-and-forward (e.g. ACKs and forwarded packets)
  final List<Map<String, dynamic>> _packetQueue = [];

  // Message stream to notify UI about new messages received
  final StreamController<MessageModel> _receivedMessageController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get receivedMessageStream => _receivedMessageController.stream;

  // Status stream to notify UI about message status updates (e.g. pending to sent)
  final StreamController<MessageModel> _messageStatusController = StreamController<MessageModel>.broadcast();
  Stream<MessageModel> get messageStatusStream => _messageStatusController.stream;

  // Stream for logging routing updates to the UI
  final StreamController<String> _routingLogController = StreamController<String>.broadcast();
  Stream<String> get routingLogStream => _routingLogController.stream;

  void logRoute(String message) {
    print("[ROUTING] $message");
    _routingLogController.add("[${DateTime.now().toString().substring(11, 19)}] $message");
  }

  Future<void> init(CommunicationService commService) async {
    _commService = commService;
    await _commService.init();
    
    // Load existing routes from Storage
    final savedRoutes = _storage.getRoutes();
    for (var r in savedRoutes) {
      _routingTable[r.destinationId] = r;
    }

    _payloadSubscription?.cancel();
    _payloadSubscription = _commService.incomingPayloadStream.listen(_onPayloadReceived);

    _connSubscription?.cancel();
    _connSubscription = _commService.connectionStatusStream.listen(_onConnectionStatusChanged);

    // Setup periodic updates: advertisement every 10 seconds (only if not in a test)
    _advertisementTimer?.cancel();
    _queueTimer?.cancel();
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _advertisementTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        _sendRoutingAdvertisement();
      });

      // Setup periodic store-and-forward checks: every 5 seconds
      _queueTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _processStoreAndForwardQueue();
      });
    }

    logRoute("RoutingService initialized with ${_routingTable.length} existing routes.");
  }

  Map<String, RouteModel> get routingTable => _routingTable;

  // --- Sending Messages via Mesh ---

  Future<bool> sendMessage(String recipientId, String content, String messageType, {
    String chatId = '',
    String? replyToId,
    String? replyToContent,
  }) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return false;

    final actualChatId = chatId.isNotEmpty ? chatId : recipientId; // For 1-to-1, chatId is recipientId
    final msgId = _uuid.v4();

    // Derive symmetric key if encrypted
    // For 1-to-1: if we have paired public keys, encrypt.
    // In our simplified version, we encrypt the content using recipient's public key (RSA) or symmetric key.
    // Let's use asymmetric encryption for message payloads directly, or fall back to AES.
    final recipientUser = _storage.getUser(recipientId);
    String encryptedContent = content;
    bool isEnc = false;

    if (recipientUser != null && recipientUser.publicKey.isNotEmpty) {
      encryptedContent = _encryption.encryptWithPublicKey(content, recipientUser.publicKey);
      isEnc = true;
      logRoute("Message is encrypted for recipient ${recipientUser.name}");
    }

    final message = MessageModel(
      messageId: msgId,
      chatId: actualChatId,
      senderId: myProfile.userId,
      receiverId: recipientId,
      messageType: messageType,
      content: encryptedContent,
      timestamp: DateTime.now(),
      status: 'pending',
      isEncrypted: isEnc,
      routePath: [myProfile.userId],
      replyToId: replyToId,
      replyToContent: replyToContent,
    );

    // Save message locally in Hive
    await _storage.saveMessage(message);

    // Check if group/community broadcast
    final chat = _storage.getChat(actualChatId);
    final isGroup = actualChatId == 'emergency_sos' || actualChatId.startsWith('community_') || (chat != null && chat.type == 'group');

    if (isGroup) {
      final packet = {
        'payloadType': 'group_message',
        'messageId': msgId,
        'chatId': actualChatId,
        'senderId': myProfile.userId,
        'messageType': messageType,
        'content': content,
        'timestamp': message.timestamp.toIso8601String(),
        'hops': [myProfile.userId],
        'replyToId': replyToId,
        'replyToContent': replyToContent,
      };

      final payloadString = json.encode(packet);
      final connections = _commService.activeConnections;
      bool sentAny = false;

      connections.forEach((peerId, status) {
        if (status == PeerConnectionStatus.connected) {
          _commService.sendPayload(peerId, payloadString);
          sentAny = true;
        }
      });

      final updated = message.copyWith(status: sentAny ? 'sent' : 'pending', routePath: [myProfile.userId]);
      await _storage.saveMessage(updated);
      _messageStatusController.add(updated);

      if (!sentAny) {
        logRoute("No neighbors online for group $actualChatId. Queued in store-and-forward.");
        _storeAndForwardQueue.add(updated);
      } else {
        logRoute("Broadcasted group message $msgId for $actualChatId to neighbors.");
      }
      return sentAny;
    }

    // Look up Next Hop
    final route = _routingTable[recipientId];
    if (route != null) {
      final isNextHopConnected = _commService.activeConnections[route.nextHopId] == PeerConnectionStatus.connected;
      if (isNextHopConnected) {
        final success = await _deliverPacket(route.nextHopId, message);
        if (success) {
          final updated = message.copyWith(status: 'sent', routePath: [myProfile.userId, route.nextHopId]);
          await _storage.saveMessage(updated);
          _messageStatusController.add(updated); // Emit update to trigger tick change
          logRoute("Sent message $msgId -> Next Hop: ${route.nextHopId}");
          return true;
        }
      } else {
        logRoute("Next Hop ${route.nextHopId} for destination $recipientId is currently disconnected.");
      }
    }

    // Unreachable: enqueue
    logRoute("Destination $recipientId unreachable. Message $msgId added to store-and-forward queue.");
    _storeAndForwardQueue.add(message);
    return false;
  }

  Future<bool> _deliverPacket(String nextHopId, MessageModel message) async {
    final packet = {
      'payloadType': 'mesh_message',
      'messageId': message.messageId,
      'chatId': message.chatId,
      'senderId': message.senderId,
      'receiverId': message.receiverId,
      'messageType': message.messageType,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'isEncrypted': message.isEncrypted,
      'hops': message.routePath,
      'replyToId': message.replyToId,
      'replyToContent': message.replyToContent,
    };
    
    final payloadString = json.encode(packet);
    return await _commService.sendPayload(nextHopId, payloadString);
  }

  // --- Broadcast Emergency SOS ---

  Future<void> broadcastEmergencySOS(String text, double lat, double lon) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final sosId = _uuid.v4();
    final contentMap = {
      'message': text,
      'latitude': lat,
      'longitude': lon,
    };

    final message = MessageModel(
      messageId: sosId,
      chatId: 'emergency_sos',
      senderId: myProfile.userId,
      receiverId: '', // Broadcast
      messageType: 'sos',
      content: json.encode(contentMap),
      timestamp: DateTime.now(),
      status: 'sent',
      isEncrypted: false,
      routePath: [myProfile.userId],
    );

    // Save locally
    await _storage.saveMessage(message);

    final packet = {
      'payloadType': 'sos_broadcast',
      'messageId': sosId,
      'senderId': myProfile.userId,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'hops': [myProfile.userId],
    };

    final payloadString = json.encode(packet);
    logRoute("🚨 BROADCASTING EMERGENCY SOS ALERT!");

    // Flood to all active direct connections
    final connections = _commService.activeConnections;
    connections.forEach((peerId, status) {
      if (status == PeerConnectionStatus.connected) {
        _commService.sendPayload(peerId, payloadString);
      }
    });
  }

  // --- Handle Incoming Payloads ---

  Future<void> _onPayloadReceived(CommPayload payload) async {
    try {
      final packet = json.decode(payload.data) as Map<String, dynamic>;
      final type = packet['payloadType'] as String;

      if (type == 'routing_announcement') {
        _handleRoutingAnnouncement(payload.senderDeviceId, packet['routingTable'] as Map<String, dynamic>);
      } else if (type == 'mesh_message') {
        _handleIncomingMeshMessage(payload.senderDeviceId, packet);
      } else if (type == 'sos_broadcast') {
        _handleIncomingSOS(payload.senderDeviceId, packet);
      } else if (type == 'mesh_ack') {
        _handleIncomingMeshAck(payload.senderDeviceId, packet);
      } else if (type == 'group_message') {
        _handleIncomingGroupMessage(payload.senderDeviceId, packet);
      } else if (type == 'mesh_reaction') {
        _handleIncomingMeshReaction(payload.senderDeviceId, packet);
      }
    } catch (e) {
      logRoute("Error parsing incoming payload from ${payload.senderDeviceId}: $e");
    }
  }

  void _handleRoutingAnnouncement(String senderId, Map<String, dynamic> neighborTable) {
    bool tableChanged = false;
    final now = DateTime.now();

    // First update the direct link to the sender with cost 1
    if (!_routingTable.containsKey(senderId) || _routingTable[senderId]!.cost > 1) {
      final route = RouteModel(
        destinationId: senderId,
        nextHopId: senderId,
        cost: 1,
        timestamp: now,
      );
      _routingTable[senderId] = route;
      _storage.saveRoute(route);
      tableChanged = true;
      logRoute("Updated direct route to neighbor $senderId");
    }

    // Identify destinations that currently next-hop through this neighbor
    final routedViaSender = _routingTable.entries
        .where((entry) => entry.value.nextHopId == senderId && entry.key != senderId)
        .map((entry) => entry.key)
        .toList();

    // If the neighbor no longer advertises a route to those destinations, we must drop them
    for (var destId in routedViaSender) {
      if (!neighborTable.containsKey(destId)) {
        _routingTable.remove(destId);
        _storage.removeRoute(destId);
        tableChanged = true;
        logRoute("Route to $destId via $senderId lost (neighbor removed it)");
      }
    }

    // Now inspect neighbor's advertisements
    neighborTable.forEach((destId, routeData) {
      // Don't route back to ourselves
      final myId = _storage.getMyUserId();
      if (destId == myId) return;

      final neighborCost = routeData['cost'] as int;
      final cost = neighborCost + 1;
      final currentRoute = _routingTable[destId];

      if (currentRoute == null) {
        if (cost < 999) {
          // New route found
          final route = RouteModel(
            destinationId: destId,
            nextHopId: senderId,
            cost: cost,
            timestamp: now,
          );
          _routingTable[destId] = route;
          _storage.saveRoute(route);
          tableChanged = true;
          logRoute("Found route to $destId via $senderId (cost: $cost)");
        }
      } else {
        if (currentRoute.nextHopId == senderId) {
          // If the next hop changed their cost, we must accept it (even if higher)
          if (cost >= 999) {
            _routingTable.remove(destId);
            _storage.removeRoute(destId);
            tableChanged = true;
            logRoute("Route to $destId via $senderId became unreachable");
          } else if (currentRoute.cost != cost) {
            final route = RouteModel(
              destinationId: destId,
              nextHopId: senderId,
              cost: cost,
              timestamp: now,
            );
            _routingTable[destId] = route;
            _storage.saveRoute(route);
            tableChanged = true;
            logRoute("Updated cost to $destId via $senderId from ${currentRoute.cost} to $cost");
          }
        } else {
          // If advertisement comes from a different next hop, only update if it is shorter
          if (cost < currentRoute.cost && cost < 999) {
            final route = RouteModel(
              destinationId: destId,
              nextHopId: senderId,
              cost: cost,
              timestamp: now,
            );
            _routingTable[destId] = route;
            _storage.saveRoute(route);
            tableChanged = true;
            logRoute("Found shorter route to $destId via $senderId (cost: $cost, old cost: ${currentRoute.cost})");
          }
        }
      }
    });

    if (tableChanged) {
      // Re-advertise our updated table soon
      _sendRoutingAdvertisement();
    }
  }

  Future<void> _handleIncomingMeshMessage(String senderId, Map<String, dynamic> packet) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final msgId = packet['messageId'] as String? ?? '';
    final receiverId = packet['receiverId'] as String? ?? '';
    if (msgId.isEmpty || receiverId.isEmpty) return;
    
    final hops = List<String>.from(packet['hops'] ?? []);

    // 1. Check if we have already handled this message (prevent duplicate loops)
    if (_storage.getMessage(msgId) != null) {
      return;
    }

    if (hops.contains(myProfile.userId)) {
      // Loop detected, discard
      return;
    }

    // Add myself to hops path
    hops.add(myProfile.userId);
    packet['hops'] = hops;

    if (receiverId == myProfile.userId) {
      // Message is for me!
      logRoute("🎉 Message received destined for me from ${packet['senderId']}!");

      String decryptedContent = packet['content'];
      final privateKey = _storage.getPrivateKey();
      if (packet['isEncrypted'] == true && privateKey != null && privateKey.isNotEmpty) {
        decryptedContent = _encryption.decryptWithPrivateKey(decryptedContent, privateKey);
      }

      final message = MessageModel(
        messageId: msgId,
        chatId: packet['chatId'],
        senderId: packet['senderId'],
        receiverId: receiverId,
        messageType: packet['messageType'],
        content: decryptedContent,
        timestamp: DateTime.parse(packet['timestamp']),
        status: 'read',
        isEncrypted: packet['isEncrypted'],
        routePath: hops,
        replyToId: packet['replyToId'],
        replyToContent: packet['replyToContent'],
      );

      // Save message locally
      await _storage.saveMessage(message);
      
      // Save sender user context if not known (add placeholder profile)
      if (_storage.getUser(message.senderId) == null) {
        final unknownUser = UserModel(
          userId: message.senderId,
          name: "Peer ${message.senderId.substring(0, 4)}",
          profilePicture: "",
          deviceId: message.senderId,
          publicKey: "",
          createdAt: DateTime.now(),
        );
        await _storage.saveUser(unknownUser);
      }

      // Create Chat session if it does not exist
      if (_storage.getChat(message.chatId) == null) {
        final chat = ChatModel(
          chatId: message.chatId,
          name: _storage.getUser(message.senderId)?.name ?? "Direct Chat",
          type: 'individual',
          members: [myProfile.userId, message.senderId],
          createdAt: DateTime.now(),
        );
        await _storage.saveChat(chat);
      }

      // Emit message to UI listeners
      _receivedMessageController.add(message);

      // Send E2E Acknowledgment back to sender
      _sendMeshAck(message.senderId, msgId);
    } else {
      // Forward to next hop
      logRoute("Message $msgId is for $receiverId. Relay message...");
      final nextRoute = _routingTable[receiverId];
      if (nextRoute != null) {
        final payloadString = json.encode(packet);
        final success = await _commService.sendPayload(nextRoute.nextHopId, payloadString);
        if (success) {
          logRoute("Message $msgId relayed successfully to ${nextRoute.nextHopId}");
        } else {
          // Failed to forward, store and forward queue
          logRoute("Failed to relay message $msgId. Adding to store-and-forward queue.");
          final message = MessageModel.fromMap(packet);
          _storeAndForwardQueue.add(message);
        }
      } else {
        // No route, store and forward queue
        logRoute("No route to $receiverId. Message $msgId queued in store-and-forward.");
        final message = MessageModel.fromMap(packet);
        _storeAndForwardQueue.add(message);
      }
    }
  }

  Future<void> _sendMeshAck(String originalSenderId, String messageId) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final ackPacket = {
      'payloadType': 'mesh_ack',
      'messageId': messageId,
      'senderId': myProfile.userId,
      'receiverId': originalSenderId,
      'hops': [myProfile.userId],
    };

    final route = _routingTable[originalSenderId];
    if (route != null) {
      final payloadString = json.encode(ackPacket);
      final success = await _commService.sendPayload(route.nextHopId, payloadString);
      if (success) {
        logRoute("Sent ACK for message $messageId -> Next Hop: ${route.nextHopId}");
        return;
      }
    }
    logRoute("Destination $originalSenderId unreachable for ACK. Queued ACK in store-and-forward.");
    _packetQueue.add(ackPacket);
  }

  Future<void> _handleIncomingMeshAck(String senderId, Map<String, dynamic> packet) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final msgId = packet['messageId'] as String? ?? '';
    final receiverId = packet['receiverId'] as String? ?? '';
    if (msgId.isEmpty || receiverId.isEmpty) return;

    final hops = List<String>.from(packet['hops'] ?? []);
    if (hops.contains(myProfile.userId)) return;
    hops.add(myProfile.userId);
    packet['hops'] = hops;

    if (receiverId == myProfile.userId) {
      logRoute("🎉 Received E2E ACK for message $msgId!");
      final existingMsg = _storage.getMessage(msgId);
      if (existingMsg != null) {
        final updated = existingMsg.copyWith(status: 'read');
        await _storage.saveMessage(updated);
        _messageStatusController.add(updated);
      }
    } else {
      // Forward ACK to next hop
      logRoute("ACK $msgId is for $receiverId. Relay ACK...");
      final nextRoute = _routingTable[receiverId];
      if (nextRoute != null) {
        final payloadString = json.encode(packet);
        final success = await _commService.sendPayload(nextRoute.nextHopId, payloadString);
        if (success) {
          logRoute("ACK $msgId relayed successfully to ${nextRoute.nextHopId}");
        } else {
          logRoute("Failed to relay ACK $msgId. Queueing in packet queue.");
          _packetQueue.add(packet);
        }
      } else {
        logRoute("No route to $receiverId for ACK. Queueing in packet queue.");
        _packetQueue.add(packet);
      }
    }
  }

  Future<void> _handleIncomingGroupMessage(String senderId, Map<String, dynamic> packet) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final msgId = packet['messageId'] as String? ?? '';
    final chatId = packet['chatId'] as String? ?? '';
    if (msgId.isEmpty || chatId.isEmpty) return;

    final hops = List<String>.from(packet['hops'] ?? []);
    if (_storage.getMessage(msgId) != null || hops.contains(myProfile.userId)) {
      return; // Already handled or loop
    }

    logRoute("👥 Incoming Group message received for $chatId from ${packet['senderId']}");
    hops.add(myProfile.userId);
    packet['hops'] = hops;

    final message = MessageModel(
      messageId: msgId,
      chatId: chatId,
      senderId: packet['senderId'],
      receiverId: '', // Group
      messageType: packet['messageType'],
      content: packet['content'],
      timestamp: DateTime.parse(packet['timestamp']),
      status: 'read',
      isEncrypted: false,
      routePath: hops,
    );

    // Save locally
    await _storage.saveMessage(message);

    // Create Chat session if not exists
    if (_storage.getChat(chatId) == null) {
      final chat = ChatModel(
        chatId: chatId,
        name: chatId.replaceAll('community_', '').replaceAll('_', ' ').toUpperCase(),
        type: 'group',
        members: [myProfile.userId],
        createdAt: DateTime.now(),
      );
      await _storage.saveChat(chat);
    }

    _receivedMessageController.add(message);

    // Flood to all neighbors except those in hops list
    final connections = _commService.activeConnections;
    connections.forEach((peerId, status) {
      if (status == PeerConnectionStatus.connected && !hops.contains(peerId)) {
        logRoute("Re-flooding group message $msgId to neighbor $peerId");
        final payloadString = json.encode(packet);
        _commService.sendPayload(peerId, payloadString);
      }
    });
  }

  Future<void> sendReaction(String chatId, String messageId, String emoji) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    // Save locally
    final msg = _storage.getMessage(messageId);
    if (msg != null) {
      final updatedReactions = Map<String, String>.from(msg.reactions);
      updatedReactions[myProfile.userId] = emoji;
      final updatedMsg = msg.copyWith(reactions: updatedReactions);
      await _storage.saveMessage(updatedMsg);
      _messageStatusController.add(updatedMsg);
    }

    // Determine receiverId and broadcast/forward
    final chat = _storage.getChat(chatId);
    final isGroup = chatId == 'emergency_sos' || chatId.startsWith('community_') || (chat != null && chat.type == 'group');

    final packet = {
      'payloadType': 'mesh_reaction',
      'messageId': messageId,
      'chatId': chatId,
      'senderId': myProfile.userId,
      'receiverId': isGroup ? '' : chatId, // For 1-to-1, receiverId is chatId
      'emoji': emoji,
      'hops': [myProfile.userId],
    };

    final payloadString = json.encode(packet);

    if (isGroup) {
      // Flood group reaction
      final connections = _commService.activeConnections;
      connections.forEach((peerId, status) {
        if (status == PeerConnectionStatus.connected) {
          _commService.sendPayload(peerId, payloadString);
        }
      });
      logRoute("Broadcasted reaction for message $messageId in group $chatId");
    } else {
      // Route 1-to-1 reaction
      final route = _routingTable[chatId];
      if (route != null) {
        final success = await _commService.sendPayload(route.nextHopId, payloadString);
        if (success) {
          logRoute("Sent reaction for message $messageId to next hop ${route.nextHopId}");
        } else {
          _packetQueue.add(packet);
        }
      } else {
        _packetQueue.add(packet);
      }
    }
  }

  Future<void> _handleIncomingMeshReaction(String senderId, Map<String, dynamic> packet) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final msgId = packet['messageId'] as String? ?? '';
    final chatId = packet['chatId'] as String? ?? '';
    final senderUserId = packet['senderId'] as String? ?? '';
    final receiverId = packet['receiverId'] as String? ?? '';
    final emoji = packet['emoji'] as String? ?? '';
    if (msgId.isEmpty || chatId.isEmpty || senderUserId.isEmpty || emoji.isEmpty) return;

    final hops = List<String>.from(packet['hops'] ?? []);
    if (hops.contains(myProfile.userId)) return;
    hops.add(myProfile.userId);
    packet['hops'] = hops;

    final isGroup = chatId == 'emergency_sos' || chatId.startsWith('community_') || receiverId.isEmpty;

    // Update local message reactions if message exists in our database
    final existingMsg = _storage.getMessage(msgId);
    if (existingMsg != null) {
      final updatedReactions = Map<String, String>.from(existingMsg.reactions);
      updatedReactions[senderUserId] = emoji;
      final updatedMsg = existingMsg.copyWith(reactions: updatedReactions);
      await _storage.saveMessage(updatedMsg);
      _messageStatusController.add(updatedMsg);
      logRoute("Applied incoming reaction ($emoji) from $senderUserId to message $msgId");
    }

    if (isGroup) {
      // Re-flood group reaction to neighbors who haven't seen it
      final connections = _commService.activeConnections;
      connections.forEach((peerId, status) {
        if (status == PeerConnectionStatus.connected && !hops.contains(peerId)) {
          final payloadString = json.encode(packet);
          _commService.sendPayload(peerId, payloadString);
        }
      });
    } else {
      if (receiverId == myProfile.userId) {
        // Destination reached
        logRoute("Reaction successfully delivered to me.");
      } else {
        // Forward reaction packet to next hop
        logRoute("Relaying reaction for message $msgId to $receiverId...");
        final nextRoute = _routingTable[receiverId];
        if (nextRoute != null) {
          final payloadString = json.encode(packet);
          final success = await _commService.sendPayload(nextRoute.nextHopId, payloadString);
          if (!success) {
            _packetQueue.add(packet);
          }
        } else {
          _packetQueue.add(packet);
        }
      }
    }
  }

  void _handleIncomingSOS(String senderId, Map<String, dynamic> packet) async {
    final myProfile = await _storage.getMyProfile();
    if (myProfile == null) return;

    final msgId = packet['messageId'] as String;
    final hops = List<String>.from(packet['hops'] ?? []);

    if (_storage.getMessage(msgId) != null || hops.contains(myProfile.userId)) {
      return; // Already seen or loop
    }

    logRoute("🚨 Incoming Emergency SOS received from ${packet['senderId']}");
    hops.add(myProfile.userId);
    packet['hops'] = hops;

    final message = MessageModel(
      messageId: msgId,
      chatId: 'emergency_sos',
      senderId: packet['senderId'],
      receiverId: '',
      messageType: 'sos',
      content: packet['content'],
      timestamp: DateTime.parse(packet['timestamp']),
      status: 'read',
      isEncrypted: false,
      routePath: hops,
    );

    // Save locally
    await _storage.saveMessage(message);
    _receivedMessageController.add(message);

    // Ensure sender details exist
    if (_storage.getUser(message.senderId) == null) {
      final user = UserModel(
        userId: message.senderId,
        name: "SOS Alert Sender",
        profilePicture: "",
        deviceId: message.senderId,
        publicKey: "",
        createdAt: DateTime.now(),
      );
      await _storage.saveUser(user);
    }

    // Forward SOS to all direct neighbors except neighbors in hops list
    final connections = _commService.activeConnections;
    connections.forEach((peerId, status) {
      if (status == PeerConnectionStatus.connected && !hops.contains(peerId)) {
        logRoute("Re-flooding SOS $msgId to neighbor $peerId");
        final payloadString = json.encode(packet);
        _commService.sendPayload(peerId, payloadString);
      }
    });
  }

  // --- Routing Table Advertisement ---

  void _sendRoutingAdvertisement() async {
    final myId = _storage.getMyUserId();
    if (myId == null) return;

    // Build announcement payload
    final Map<String, Map<String, dynamic>> routesData = {};
    _routingTable.forEach((dest, route) {
      routesData[dest] = {
        'cost': route.cost,
      };
    });

    // Add myself
    routesData[myId] = {
      'cost': 0,
    };

    final announcement = {
      'payloadType': 'routing_announcement',
      'senderId': myId,
      'routingTable': routesData,
    };

    final payloadString = json.encode(announcement);

    // Send to all direct neighbors
    final connections = _commService.activeConnections;
    connections.forEach((peerId, status) {
      if (status == PeerConnectionStatus.connected) {
        _commService.sendPayload(peerId, payloadString);
      }
    });
  }

  // --- Store and Forward Processing ---

  void _processStoreAndForwardQueue() async {
    final myProfile = await _storage.getMyProfile();
    final myId = myProfile?.userId;

    // Process outgoing/relayed messages
    if (_storeAndForwardQueue.isNotEmpty) {
      final List<MessageModel> queueCopy = List.from(_storeAndForwardQueue);
      _storeAndForwardQueue.clear();

      for (var msg in queueCopy) {
        final dest = msg.receiverId;
        final route = _routingTable[dest];
        
        if (route != null) {
          final isNextHopConnected = _commService.activeConnections[route.nextHopId] == PeerConnectionStatus.connected;
          if (isNextHopConnected) {
            logRoute("Flushing store-and-forward message ${msg.messageId} to $dest via next hop ${route.nextHopId}");
            final success = await _deliverPacket(route.nextHopId, msg);
            if (success) {
              if (msg.senderId == myId) {
                final updated = msg.copyWith(status: 'sent', routePath: [...msg.routePath, route.nextHopId]);
                await _storage.saveMessage(updated);
                _messageStatusController.add(updated); // Emit update to trigger tick change
              }
            } else {
              // Re-queue
              _storeAndForwardQueue.add(msg);
            }
          } else {
            // Keep in queue (next hop currently disconnected)
            _storeAndForwardQueue.add(msg);
          }
        } else {
          // Keep in queue (no route)
          _storeAndForwardQueue.add(msg);
        }
      }
    }

    // Process raw packet queue (ACKs or general forward payloads)
    if (_packetQueue.isNotEmpty) {
      final List<Map<String, dynamic>> packetQueueCopy = List.from(_packetQueue);
      _packetQueue.clear();

      for (var packet in packetQueueCopy) {
        final dest = packet['receiverId'] as String? ?? '';
        final route = _routingTable[dest];

        if (route != null) {
          final isNextHopConnected = _commService.activeConnections[route.nextHopId] == PeerConnectionStatus.connected;
          if (isNextHopConnected) {
            logRoute("Flushing queued packet to $dest via next hop ${route.nextHopId}");
            final payloadString = json.encode(packet);
            final success = await _commService.sendPayload(route.nextHopId, payloadString);
            if (!success) {
              _packetQueue.add(packet);
            }
          } else {
            _packetQueue.add(packet);
          }
        } else {
          _packetQueue.add(packet);
        }
      }
    }
  }

  // --- Handle Connection Transitions ---
  void _onConnectionStatusChanged(Map<String, PeerConnectionStatus> statusMap) {
    statusMap.forEach((peerId, status) {
      if (status == PeerConnectionStatus.disconnected) {
        // Link broke: clean routing table routes that go through this peer
        final routesToRemove = <String>[];
        _routingTable.forEach((dest, route) {
          if (route.nextHopId == peerId) {
            routesToRemove.add(dest);
          }
        });

        for (var r in routesToRemove) {
          _routingTable.remove(r);
          _storage.removeRoute(r);
          logRoute("Link broke to $peerId. Route to $r removed.");
        }
      }
    });
  }

  void dispose() {
    _payloadSubscription?.cancel();
    _connSubscription?.cancel();
    _advertisementTimer?.cancel();
    _queueTimer?.cancel();
    _receivedMessageController.close();
    _routingLogController.close();
    _messageStatusController.close();
  }
}
