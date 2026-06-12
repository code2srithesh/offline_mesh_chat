import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/storage_models.dart';
import '../data/services/storage_service.dart';
import '../data/services/routing_service.dart';
import 'app_providers.dart';

// --- Chats State Notifier ---
class ChatsNotifier extends StateNotifier<List<ChatModel>> {
  final StorageService _storage;

  ChatsNotifier(this._storage) : super([]) {
    loadChats();
  }

  void loadChats() {
    state = _storage.getAllChats();
  }

  Future<void> createChat(String name, String type, List<String> members, {String? customId}) async {
    final chatId = customId ?? (type == 'individual' ? members.firstWhere((m) => m != _storage.getMyUserId(), orElse: () => 'unknown') : 'group_${DateTime.now().millisecondsSinceEpoch}');
    
    // Check if chat already exists
    final existing = _storage.getChat(chatId);
    if (existing != null) return;

    final newChat = ChatModel(
      chatId: chatId,
      name: name,
      type: type,
      members: members,
      createdAt: DateTime.now(),
    );

    await _storage.saveChat(newChat);
    loadChats();
  }

  void updateLastMessage(String chatId, String messageId) {
    loadChats(); // Reloads all chats and sorts them
  }
}

final chatsProvider = StateNotifierProvider<ChatsNotifier, List<ChatModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ChatsNotifier(storage);
});

// --- Messages State Notifier (Family-based for each Chat) ---
class MessagesNotifier extends StateNotifier<List<MessageModel>> {
  final String _chatId;
  final StorageService _storage;
  final RoutingService _routing;
  StreamSubscription? _receivedSubscription;
  StreamSubscription? _statusSubscription;

  MessagesNotifier(this._chatId, this._storage, this._routing) : super([]) {
    loadMessages();
    
    // Listen to routing incoming messages to immediately update current chat view
    _receivedSubscription = _routing.receivedMessageStream.listen((msg) {
      if (msg.chatId == _chatId) {
        state = [...state, msg];
      }
    });

    // Listen to message status updates (e.g. pending -> sent) to refresh ticks instantly
    _statusSubscription = _routing.messageStatusStream.listen((msg) {
      if (msg.chatId == _chatId) {
        state = [
          for (final m in state)
            if (m.messageId == msg.messageId) msg else m
        ];
      }
    });
  }

  void loadMessages() {
    state = _storage.getMessagesForChat(_chatId);
  }

  Future<bool> sendTextMessage(String text) async {
    final recipientId = _chatId; // For 1-to-1 chats, chatId is target userId.
    final success = await _routing.sendMessage(recipientId, text, 'text', chatId: _chatId);
    loadMessages();
    return success;
  }

  Future<bool> sendMediaMessage(String filePath, String type) async {
    final recipientId = _chatId;
    final success = await _routing.sendMessage(recipientId, filePath, type, chatId: _chatId);
    loadMessages();
    return success;
  }

  Future<bool> sendLocationMessage(double lat, double lon, String address) async {
    final recipientId = _chatId;
    final content = '$lat,$lon|$address';
    final success = await _routing.sendMessage(recipientId, content, 'location', chatId: _chatId);
    loadMessages();
    return success;
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    _statusSubscription?.cancel();
    super.dispose();
  }
}

final messagesProvider = StateNotifierProvider.family<MessagesNotifier, List<MessageModel>, String>((ref, chatId) {
  final storage = ref.watch(storageServiceProvider);
  final routing = ref.watch(routingServiceProvider);
  return MessagesNotifier(chatId, storage, routing);
});

// --- Emergency SOS Provider ---
class SOSNotifier extends StateNotifier<List<MessageModel>> {
  final StorageService _storage;
  final RoutingService _routing;
  StreamSubscription? _receivedSubscription;

  SOSNotifier(this._storage, this._routing) : super([]) {
    _loadSOSHistory();

    // Listen to incoming SOS messages
    _receivedSubscription = _routing.receivedMessageStream.listen((msg) {
      if (msg.messageType == 'sos') {
        state = [msg, ...state];
      }
    });
  }

  void _loadSOSHistory() {
    final allSos = _storage.getMessagesForChat('emergency_sos');
    allSos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = allSos;
  }

  Future<void> sendSOS(String text, double lat, double lon) async {
    await _routing.broadcastEmergencySOS(text, lat, lon);
    _loadSOSHistory();
  }

  @override
  void dispose() {
    _receivedSubscription?.cancel();
    super.dispose();
  }
}

final sosProvider = StateNotifierProvider<SOSNotifier, List<MessageModel>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final routing = ref.watch(routingServiceProvider);
  return SOSNotifier(storage, routing);
});
