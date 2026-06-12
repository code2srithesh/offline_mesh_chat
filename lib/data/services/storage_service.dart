import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../models/storage_models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box _settingsBox;
  late Box _usersBox;
  late Box _chatsBox;
  late Box _messagesBox;
  late Box _routingBox;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    if (kIsWeb) {
      await Hive.initFlutter();
    } else {
      try {
        if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
          Hive.init('.');
        } else {
          final dir = await getApplicationDocumentsDirectory();
          await Hive.initFlutter(dir.path);
        }
      } catch (e) {
        print("Error getting app directory, using default Hive init: $e");
        Hive.init('.');
      }
    }

    _settingsBox = await Hive.openBox('settings');
    _usersBox = await Hive.openBox('users');
    _chatsBox = await Hive.openBox('chats');
    _messagesBox = await Hive.openBox('messages');
    _routingBox = await Hive.openBox('routing');

    _initialized = true;
  }

  // --- Profile Settings ---
  
  String? getMyUserId() => _settingsBox.get('my_user_id');
  Future<void> setMyUserId(String userId) async => await _settingsBox.put('my_user_id', userId);

  String? getPrivateKey() => _settingsBox.get('my_private_key');
  Future<void> savePrivateKey(String privateKey) async => await _settingsBox.put('my_private_key', privateKey);

  Future<UserModel?> getMyProfile() async {
    final myId = getMyUserId();
    if (myId == null) return null;
    return getUser(myId);
  }

  Future<void> saveMyProfile(UserModel user) async {
    await setMyUserId(user.userId);
    await saveUser(user);
  }

  // --- Users CRUD ---

  Future<void> saveUser(UserModel user) async {
    await _usersBox.put(user.userId, user.toMap());
  }

  UserModel? getUser(String userId) {
    final data = _usersBox.get(userId);
    if (data == null) return null;
    return UserModel.fromMap(Map<String, dynamic>.from(data));
  }

  List<UserModel> getAllUsers() {
    return _usersBox.values
        .map((data) => UserModel.fromMap(Map<String, dynamic>.from(data)))
        .toList();
  }

  // --- Chats CRUD ---

  Future<void> saveChat(ChatModel chat) async {
    await _chatsBox.put(chat.chatId, chat.toMap());
  }

  List<ChatModel> getAllChats() {
    final chats = _chatsBox.values
        .map((data) => ChatModel.fromMap(Map<String, dynamic>.from(data)))
        .toList();
    // Sort by timestamp or default order
    chats.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return chats;
  }

  ChatModel? getChat(String chatId) {
    final data = _chatsBox.get(chatId);
    if (data == null) return null;
    return ChatModel.fromMap(Map<String, dynamic>.from(data));
  }

  // --- Messages CRUD ---

  Future<void> saveMessage(MessageModel message) async {
    await _messagesBox.put(message.messageId, message.toMap());
    
    // Update chat's last message
    final chat = getChat(message.chatId);
    if (chat != null) {
      final updatedChat = ChatModel(
        chatId: chat.chatId,
        name: chat.name,
        type: chat.type,
        members: chat.members,
        lastMessageId: message.messageId,
        createdAt: chat.createdAt,
      );
      await saveChat(updatedChat);
    }
  }

  List<MessageModel> getMessagesForChat(String chatId) {
    final list = _messagesBox.values
        .map((data) => MessageModel.fromMap(Map<String, dynamic>.from(data)))
        .where((msg) => msg.chatId == chatId)
        .toList();
    list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  MessageModel? getMessage(String messageId) {
    final data = _messagesBox.get(messageId);
    if (data == null) return null;
    return MessageModel.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteMessage(String messageId) async {
    await _messagesBox.delete(messageId);
  }

  // --- Mesh Routing Table CRUD ---

  Future<void> saveRoute(RouteModel route) async {
    await _routingBox.put(route.destinationId, route.toMap());
  }

  Future<void> removeRoute(String destinationId) async {
    await _routingBox.delete(destinationId);
  }

  List<RouteModel> getRoutes() {
    return _routingBox.values
        .map((data) => RouteModel.fromMap(Map<String, dynamic>.from(data)))
        .toList();
  }

  // --- Clear Database ---
  Future<void> clearAllData() async {
    await _settingsBox.clear();
    await _usersBox.clear();
    await _chatsBox.clear();
    await _messagesBox.clear();
    await _routingBox.clear();
  }
}
