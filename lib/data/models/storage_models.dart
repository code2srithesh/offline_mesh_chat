import 'dart:convert';

class UserModel {
  final String userId;
  final String name;
  final String profilePicture; // Base64 or local filepath
  final String deviceId;
  final String publicKey;
  final DateTime createdAt;

  UserModel({
    required this.userId,
    required this.name,
    required this.profilePicture,
    required this.deviceId,
    required this.publicKey,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'profilePicture': profilePicture,
      'deviceId': deviceId,
      'publicKey': publicKey,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      profilePicture: map['profilePicture'] ?? '',
      deviceId: map['deviceId'] ?? '',
      publicKey: map['publicKey'] ?? '',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  String toJson() => json.encode(toMap());
  factory UserModel.fromJson(String source) => UserModel.fromMap(json.decode(source));
}

class ChatModel {
  final String chatId;
  final String name;
  final String type; // 'individual' or 'group'
  final List<String> members;
  final String? lastMessageId;
  final DateTime createdAt;

  ChatModel({
    required this.chatId,
    required this.name,
    required this.type,
    required this.members,
    this.lastMessageId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'name': name,
      'type': type,
      'members': members,
      'lastMessageId': lastMessageId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      chatId: map['chatId'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'individual',
      members: List<String>.from(map['members'] ?? []),
      lastMessageId: map['lastMessageId'],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class MessageModel {
  final String messageId;
  final String chatId;
  final String senderId;
  final String receiverId; // Can be empty for group broadcast
  final String messageType; // 'text', 'image', 'video', 'audio', 'document', 'location', 'sos'
  final String content; // If encrypted, this is ciphertext
  final DateTime timestamp;
  final String status; // 'pending', 'sent', 'delivered', 'read'
  final bool isEncrypted;
  final List<String> routePath; // Trace of deviceIds representing the message path
  final String? replyToId;
  final String? replyToContent;
  final Map<String, String> reactions; // userId -> emoji

  MessageModel({
    required this.messageId,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.messageType,
    required this.content,
    required this.timestamp,
    required this.status,
    this.isEncrypted = false,
    this.routePath = const [],
    this.replyToId,
    this.replyToContent,
    this.reactions = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'messageType': messageType,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'isEncrypted': isEncrypted,
      'routePath': routePath,
      'replyToId': replyToId,
      'replyToContent': replyToContent,
      'reactions': reactions,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      messageType: map['messageType'] ?? 'text',
      content: map['content'] ?? '',
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      status: map['status'] ?? 'pending',
      isEncrypted: map['isEncrypted'] ?? false,
      routePath: List<String>.from(map['routePath'] ?? []),
      replyToId: map['replyToId'],
      replyToContent: map['replyToContent'],
      reactions: Map<String, String>.from(map['reactions'] ?? {}),
    );
  }

  MessageModel copyWith({
    String? status,
    List<String>? routePath,
    String? content,
    String? replyToId,
    String? replyToContent,
    Map<String, String>? reactions,
  }) {
    return MessageModel(
      messageId: messageId,
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      messageType: messageType,
      content: content ?? this.content,
      timestamp: timestamp,
      status: status ?? this.status,
      isEncrypted: isEncrypted,
      routePath: routePath ?? this.routePath,
      replyToId: replyToId ?? this.replyToId,
      replyToContent: replyToContent ?? this.replyToContent,
      reactions: reactions ?? this.reactions,
    );
  }
}

class MediaModel {
  final String mediaId;
  final String messageId;
  final String filePath;
  final String mediaType; // 'image', 'video', 'audio', 'document'
  final int fileSize;
  final DateTime timestamp;

  MediaModel({
    required this.mediaId,
    required this.messageId,
    required this.filePath,
    required this.mediaType,
    required this.fileSize,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'mediaId': mediaId,
      'messageId': messageId,
      'filePath': filePath,
      'mediaType': mediaType,
      'fileSize': fileSize,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory MediaModel.fromMap(Map<String, dynamic> map) {
    return MediaModel(
      mediaId: map['mediaId'] ?? '',
      messageId: map['messageId'] ?? '',
      filePath: map['filePath'] ?? '',
      mediaType: map['mediaType'] ?? 'image',
      fileSize: map['fileSize'] ?? 0,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class RouteModel {
  final String destinationId;
  final String nextHopId;
  final int cost;
  final DateTime timestamp;

  RouteModel({
    required this.destinationId,
    required this.nextHopId,
    required this.cost,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'destinationId': destinationId,
      'nextHopId': nextHopId,
      'cost': cost,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RouteModel.fromMap(Map<String, dynamic> map) {
    return RouteModel(
      destinationId: map['destinationId'] ?? '',
      nextHopId: map['nextHopId'] ?? '',
      cost: map['cost'] ?? 1,
      timestamp: DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}
