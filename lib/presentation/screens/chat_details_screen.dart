import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../data/models/storage_models.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/audio_service.dart';


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
  final AudioService _audioService = AudioService();
  
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void dispose() {
    _recordingTimer?.cancel();
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
      _startRecording();
    }
  }

  void _startRecording() async {
    final path = await _audioService.startRecording();
    if (path != null) {
      setState(() {
        _isRecording = true;
        _recordingSeconds = 0;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recordingSeconds++;
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Microphone permission is required to record voice notes."),
          backgroundColor: AppTheme.crimsonRed,
        ),
      );
    }
  }

  void _cancelRecording() async {
    await _audioService.stopRecording(); // Stops and discards
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  void _stopAndSendRecording() async {
    _recordingTimer?.cancel();
    final path = await _audioService.stopRecording();
    setState(() {
      _isRecording = false;
    });

    if (path != null) {
      ref.read(messagesProvider(widget.chatId).notifier).sendVoiceMessage(path);
      _scrollToBottom();
    }
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
          _buildInputBar(context),
        ],
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(color: AppTheme.borderLight, width: 1),
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              const _BlinkingRecordDot(),
              const SizedBox(width: 8),
              Text(
                "Recording (${_formatDuration(_recordingSeconds)})",
                style: const TextStyle(
                  color: AppTheme.textColorPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: const Icon(Icons.cancel_outlined, color: AppTheme.crimsonRed, size: 20),
                label: const Text(
                  "Cancel",
                  style: TextStyle(color: AppTheme.crimsonRed, fontWeight: FontWeight.bold),
                ),
                onPressed: _cancelRecording,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mintGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.send, size: 16),
                label: const Text("Send"),
                onPressed: _stopAndSendRecording,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderLight, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppTheme.mintGreen),
              onPressed: _showAttachmentSheet,
              tooltip: "Attach simulated file",
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderLight, width: 1),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: const TextStyle(color: AppTheme.textColorPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    hintText: "Write message...",
                    hintStyle: TextStyle(color: AppTheme.textColorSecondary, fontSize: 15),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final isTextEmpty = value.text.trim().isEmpty;
                return IconButton(
                  icon: Icon(
                    isTextEmpty ? Icons.mic : Icons.send,
                    color: AppTheme.mintGreen,
                  ),
                  onPressed: isTextEmpty ? _startRecording : _sendMessage,
                  tooltip: isTextEmpty ? "Record Voice Note" : "Send Message",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
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
                      _buildMessageContent(message, isMe),
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

  Widget _buildMessageContent(MessageModel message, bool isMe) {
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
      return VoiceMessageBubble(message: message, isMe: isMe);
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

class _BlinkingRecordDot extends StatefulWidget {
  const _BlinkingRecordDot();

  @override
  State<_BlinkingRecordDot> createState() => _BlinkingRecordDotState();
}

class _BlinkingRecordDotState extends State<_BlinkingRecordDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: AppTheme.crimsonRed,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.crimsonRed,
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class VoiceMessageBubble extends StatefulWidget {
  final MessageModel message;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  String? _cachedFilePath;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudioListeners();
  }

  void _initAudioListeners() {
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
          if (state == PlayerState.completed) {
            _position = Duration.zero;
          }
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((pos) {
      if (mounted) {
        setState(() {
          _position = pos;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _duration = dur;
        });
      }
    });
  }

  Future<Source> _getAudioSource() async {
    if (kIsWeb) {
      return UrlSource('data:audio/aac;base64,${widget.message.content}');
    } else {
      if (_cachedFilePath == null) {
        final bytes = base64Decode(widget.message.content);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/audio_${widget.message.messageId}.m4a');
        if (!await file.exists()) {
          await file.writeAsBytes(bytes);
        }
        _cachedFilePath = file.path;
      }
      return DeviceFileSource(_cachedFilePath!);
    }
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_position > Duration.zero) {
        AudioService().registerPlaying(_audioPlayer);
        await _audioPlayer.resume();
      } else {
        setState(() {
          _isLoading = true;
        });
        try {
          final source = await _getAudioSource();
          AudioService().registerPlaying(_audioPlayer);
          await _audioPlayer.play(source);
        } catch (e) {
          print("Error playing audio: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error playing audio: $e")),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isLoading)
          SizedBox(
            width: 30,
            height: 30,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.isMe ? Colors.white : AppTheme.mintGreen,
              ),
            ),
          )
        else
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(
              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: widget.isMe ? Colors.white : AppTheme.mintGreen,
              size: 28,
            ),
            onPressed: _togglePlay,
          ),
        const SizedBox(width: 4),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: widget.isMe ? Colors.white : AppTheme.mintGreen,
              inactiveTrackColor: widget.isMe ? Colors.white30 : AppTheme.borderLight,
              thumbColor: widget.isMe ? Colors.white : AppTheme.mintGreen,
              overlayColor: widget.isMe ? Colors.white12 : AppTheme.mintGreen.withOpacity(0.12),
            ),
            child: Slider(
              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble()),
              max: _duration.inMilliseconds > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
              onChanged: (val) {
                _audioPlayer.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _formatDuration(_position) + " / " + (_duration == Duration.zero ? "0:00" : _formatDuration(_duration)),
          style: TextStyle(
            fontSize: 10,
            color: widget.isMe ? Colors.white70 : AppTheme.textColorSecondary,
          ),
        ),
      ],
    );
  }
}
