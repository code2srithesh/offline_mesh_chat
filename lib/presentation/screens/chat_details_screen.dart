import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../data/models/storage_models.dart';
import '../../core/theme/app_theme.dart';

class ChatDetailsScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;

  const ChatDetailsScreen({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  @override
  ConsumerState<ChatDetailsScreen> createState() => _ChatDetailsScreenState();
}

class _ChatDetailsScreenState extends ConsumerState<ChatDetailsScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    ref.read(messagesProvider(widget.chatId).notifier).sendTextMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _sendMockAttachment(String type) {
    Navigator.of(context).pop(); // Close sheet

    if (type == 'image') {
      ref.read(messagesProvider(widget.chatId).notifier).sendMediaMessage(
        'assets/images/mock_mesh_photo.png',
        'image',
      );
    } else if (type == 'pdf') {
      ref.read(messagesProvider(widget.chatId).notifier).sendMediaMessage(
        'documents/lecture_notes_3.pdf',
        'document',
      );
    } else if (type == 'location') {
      // Send mock location (e.g. Bangalore Campus Library)
      ref.read(messagesProvider(widget.chatId).notifier).sendLocationMessage(
        12.9722,
        77.5938,
        "Bangalore Central Library (Block C)",
      );
    } else if (type == 'voice') {
      ref.read(messagesProvider(widget.chatId).notifier).sendMediaMessage(
        'recordings/voice_note_1.m4a',
        'audio',
      );
    }
    _scrollToBottom();
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Attach File (Simulated Offline Transfer)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.textColorPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(Icons.image, "Photo", 'image', Colors.teal),
                    _buildAttachmentOption(Icons.picture_as_pdf, "Document", 'pdf', Colors.red),
                    _buildAttachmentOption(Icons.location_on, "Location", 'location', Colors.green),
                    _buildAttachmentOption(Icons.mic, "Voice", 'voice', Colors.orange),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, String type, Color color) {
    return GestureDetector(
      onTap: () => _sendMockAttachment(type),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withOpacity(0.2),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.textColorSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.chatId));
    final myProfile = ref.watch(profileProvider);

    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName),
            const Text(
              "End-to-End Encrypted (AES-256)",
              style: TextStyle(fontSize: 10, color: AppTheme.mintGreenLight),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Security pairing banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            color: const Color(0xFF161D30),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 12, color: AppTheme.mintGreen),
                SizedBox(width: 6),
                Text(
                  "Keys established automatically. Peer paired via public key exchange.",
                  style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary),
                )
              ],
            ),
          ),

          // Message log feed
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      "No messages. Send a message to open connection.",
                      style: TextStyle(color: AppTheme.textColorSecondary.withOpacity(0.5)),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == myProfile?.userId;
                      return _buildMessageBubble(message, isMe);
                    },
                  ),
          ),

          // Message input bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.mintGreen, size: 28),
                  onPressed: _showAttachmentSheet,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: const TextStyle(color: AppTheme.textColorPrimary),
                            decoration: const InputDecoration(
                              hintText: "Type message...",
                              hintStyle: TextStyle(color: AppTheme.textColorSecondary),
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send_rounded, color: AppTheme.mintGreen),
                          onPressed: _sendMessage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isMe) {
    final bubbleColor = isMe ? const Color(0xFF0F5244) : AppTheme.surfaceColor;
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppTheme.cardColor,
                  child: const Text("👤", style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _showMessageHopsInfo(message),
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                    ),
                    border: Border.all(color: AppTheme.borderLight, width: 0.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Render message content based on type
                      _buildMessageContent(message),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.timestamp.toLocal().toString().substring(11, 16),
                            style: const TextStyle(fontSize: 10, color: AppTheme.textColorSecondary),
                          ),
                          const SizedBox(width: 6),
                          if (isMe)
                            Icon(
                              message.status == 'read'
                                  ? Icons.done_all_rounded
                                  : message.status == 'sent'
                                      ? Icons.done_rounded
                                      : Icons.schedule_rounded,
                              size: 14,
                              color: message.status == 'read' ? AppTheme.mintGreen : AppTheme.textColorSecondary,
                            ),
                          const SizedBox(width: 6),
                          const Icon(Icons.hub_outlined, size: 12, color: AppTheme.electricBlueLight),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(MessageModel message) {
    if (message.messageType == 'text') {
      return Text(
        message.content,
        style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 14),
      );
    } else if (message.messageType == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Center(
              child: Icon(Icons.image_outlined, size: 50, color: AppTheme.textColorSecondary),
            ),
          ),
          const SizedBox(height: 6),
          const Text("Photo Attachment", style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 12)),
        ],
      );
    } else if (message.messageType == 'document') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            SizedBox(width: 8),
            Text(
              "lecture_notes_3.pdf",
              style: TextStyle(color: AppTheme.textColorPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    } else if (message.messageType == 'location') {
      final parts = message.content.split('|');
      final coordinates = parts[0];
      final address = parts.length > 1 ? parts[1] : "Bangalore Campus";
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 30, color: AppTheme.electricBlueLight),
                  SizedBox(height: 6),
                  Text("OpenStreetMap Preview", style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(address, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColorPrimary, fontSize: 12)),
          Text(coordinates, style: const TextStyle(fontSize: 10, color: AppTheme.textColorSecondary)),
        ],
      );
    } else if (message.messageType == 'audio') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, color: AppTheme.mintGreen, size: 30),
          const SizedBox(width: 6),
          // Custom waveform visualizer representation
          Row(
            children: List.generate(12, (index) {
              final h = [10.0, 24.0, 16.0, 8.0, 12.0, 20.0, 28.0, 14.0, 18.0, 8.0, 22.0, 12.0];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                height: h[index],
                width: 3,
                color: AppTheme.textColorSecondary,
              );
            }),
          ),
          const SizedBox(width: 8),
          const Text("0:12", style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary)),
        ],
      );
    }
    return Text(message.content);
  }

  void _showMessageHopsInfo(MessageModel message) {
    showDialog(
      context: context,
      builder: (context) {
        final pathString = message.routePath.isEmpty
            ? "Direct Connection"
            : message.routePath.join(" ➔ ");
        return AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Row(
            children: [
              Icon(Icons.hub_outlined, color: AppTheme.electricBlueLight),
              SizedBox(width: 8),
              Text("Message Hops Info", style: TextStyle(color: AppTheme.textColorPrimary)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Routing Path:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColorSecondary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Text(
                  pathString,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.electricBlueLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text("Hop Count: ${message.routePath.length}", style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 13)),
              const SizedBox(height: 6),
              Text("Status: ${message.status.toUpperCase()}", style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 13)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close", style: TextStyle(color: AppTheme.mintGreen)),
            )
          ],
        );
      },
    );
  }
}
