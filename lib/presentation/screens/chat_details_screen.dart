import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/app_providers.dart';
import '../../providers/chat_providers.dart';
import '../../data/models/storage_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/security/encryption_service.dart';
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
  final FocusNode _inputFocusNode = FocusNode();
  
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _inputFocusNode.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
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
      _pickLocation();
    } else if (type == 'voice') {
      _startRecording();
    }
  }

  void _pickLocation() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LocationPickerSheet(),
    );
    if (result != null && mounted) {
      ref.read(messagesProvider(widget.chatId).notifier).sendLocationMessage(
        result['lat'] as double,
        result['lon'] as double,
        result['address'] as String,
      );
      _scrollToBottom();
    }
  }

  void _showFullMapViewer(BuildContext context, double lat, double lon, String address) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: AppTheme.obsidianBackground,
          child: Column(
            children: [
              // Custom top bar
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: AppTheme.textColorPrimary),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "TACTICAL RADAR MAP",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.mintGreen,
                                letterSpacing: 1.5,
                              ),
                            ),
                            Text(
                              address,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColorPrimary,
                                ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(color: AppTheme.borderLight, height: 1),
              
              // Full Screen Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lon),
                        initialZoom: 16.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.offline.mesh.chat',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lon),
                              width: 80,
                              height: 80,
                              child: Icon(
                                Icons.location_on,
                                color: AppTheme.crimsonRed,
                                size: 46,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: Alignment.center,
                            radius: 0.8,
                            colors: [
                              Colors.transparent,
                              AppTheme.obsidianBackground.withOpacity(0.1),
                              AppTheme.obsidianBackground.withOpacity(0.3),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Bottom tactical coordinates card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  border: Border(
                    top: BorderSide(color: AppTheme.borderLight, width: 1),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "COORDINATE DATUM (WGS-84)",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColorSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("LATITUDE", style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary)),
                              Text(
                                lat.toStringAsFixed(6),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppTheme.textColorPrimary,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("LONGITUDE", style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary)),
                              Text(
                                lon.toStringAsFixed(6),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppTheme.textColorPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.obsidianBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off_rounded, color: AppTheme.mintGreen, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Peer-to-Peer local mesh coordinates transfer complete. Map tile caches might be unavailable without internet connection.",
                                style: TextStyle(fontSize: 11, color: AppTheme.textColorSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showVerificationPanel() {
    final verifiedUsers = ref.read(verifiedUsersProvider);
    final isVerified = verifiedUsers.contains(widget.chatId);
    
    final myProfile = ref.read(profileProvider);
    final peerUser = ref.read(storageServiceProvider).getUser(widget.chatId);
    
    final myFingerprint = _getFingerprint(myProfile?.publicKey, myProfile?.userId ?? 'local_device');
    final peerFingerprint = _getFingerprint(peerUser?.publicKey, widget.chatId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double screenHeight = MediaQuery.of(context).size.height;
            return Container(
              height: screenHeight * 0.82,
              decoration: BoxDecoration(
                color: AppTheme.obsidianBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.borderLight, width: 1.5),
                ),
              ),
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // Top handle & header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppTheme.textColorSecondary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                              Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: AppTheme.mintGreen),
                                  SizedBox(width: 8),
                                  Text(
                                    "Peer Verification",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textColorPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: AppTheme.textColorSecondary),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Tab Bar
                    TabBar(
                      labelColor: AppTheme.mintGreenLight,
                      unselectedLabelColor: AppTheme.textColorSecondary,
                      indicatorColor: AppTheme.mintGreen,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: AppTheme.borderLight,
                      tabs: const [
                        Tab(text: "Compare Codes", icon: Icon(Icons.compare_arrows_rounded, size: 20)),
                        Tab(text: "Scan QR Identity", icon: Icon(Icons.qr_code_scanner_rounded, size: 20)),
                      ],
                    ),
                    
                    // Tab Content
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Tab 1: Compare Codes
                          SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Info Card
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: AppTheme.glassCardDecoration(
                                    color: AppTheme.surfaceColor.withOpacity(0.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock, color: AppTheme.electricBlue, size: 36),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          "To verify end-to-end security, compare the unique code below with the code on their screen. If they match, this chat session is 100% verified.",
                                          style: TextStyle(fontSize: 12, height: 1.45, color: AppTheme.textColorSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Own Fingerprint
                                Text(
                                  "YOUR IDENTITY FINGERPRINT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColorSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1120),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Text(
                                    myFingerprint,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.electricBlueLight,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                
                                // Peer Fingerprint
                                Text(
                                  "${widget.chatName.toUpperCase()}'S FINGERPRINT",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColorSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0A1120),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppTheme.borderLight),
                                  ),
                                  child: Text(
                                    peerFingerprint,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.mintGreenLight,
                                      letterSpacing: 0.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                
                                // Action Button
                                SafeArea(
                                  top: false,
                                  child: AnimatedPress(
                                    onTap: () async {
                                      final newStatus = !isVerified;
                                      await ref.read(verifiedUsersProvider.notifier).verifyUser(widget.chatId, newStatus);
                                      Navigator.of(context).pop();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            newStatus
                                                ? "Secured peer verified successfully!"
                                                : "Peer marked as unverified.",
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          backgroundColor: newStatus ? AppTheme.mintGreen : AppTheme.surfaceColor,
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: double.infinity,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        gradient: isVerified ? AppTheme.premiumRedGradient : AppTheme.premiumGreenGradient,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        isVerified ? "UNVERIFY PEER IDENTITY" : "MARK PEER AS VERIFIED",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Tab 2: Scan QR Identity
                          StatefulBuilder(
                            builder: (context, setInnerState) {
                              bool showScanner = false;
                              return Builder(
                                builder: (context) {
                                  return StatefulBuilder(
                                    builder: (context, setScannerState) {
                                      if (showScanner) {
                                        return _buildSimulatedScanner(
                                          context,
                                          onSuccess: () async {
                                            final updatedUser = UserModel(
                                              userId: widget.chatId,
                                              name: widget.chatName,
                                              profilePicture: peerUser?.profilePicture ?? '',
                                              deviceId: widget.chatId,
                                              publicKey: peerUser?.publicKey ?? "mock_public_key_for_${widget.chatId}",
                                              createdAt: peerUser?.createdAt ?? DateTime.now(),
                                            );
                                            await ref.read(storageServiceProvider).saveUser(updatedUser);
                                            await ref.read(verifiedUsersProvider.notifier).verifyUser(widget.chatId, true);
                                            
                                            if (context.mounted) {
                                              Navigator.of(context).pop(); // Close sheet
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Handshake complete! Secure identity verified via QR Scan.",
                                                    style: TextStyle(fontWeight: FontWeight.bold),
                                                  ),
                                                  backgroundColor: AppTheme.mintGreen,
                                                ),
                                              );
                                            }
                                          },
                                          onCancel: () {
                                            setScannerState(() {
                                              showScanner = false;
                                            });
                                          },
                                        );
                                      }
                                      
                                      final mySerializedInfo = json.encode({
                                        'userId': myProfile?.userId ?? '',
                                        'name': myProfile?.name ?? '',
                                        'publicKey': myProfile?.publicKey ?? '',
                                      });
                                      
                                      return Padding(
                                        padding: const EdgeInsets.all(20.0),
                                        child: Column(
                                          children: [
                                            Text(
                                              "YOUR SECURE HANDSHAKE CODE",
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textColorSecondary,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppTheme.mintGreen.withOpacity(0.2),
                                                    blurRadius: 16,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                              child: QrImageView(
                                                data: mySerializedInfo,
                                                version: QrVersions.auto,
                                                size: 180.0,
                                                gapless: false,
                                                backgroundColor: Colors.white,
                                                eyeStyle: const QrEyeStyle(
                                                  eyeShape: QrEyeShape.square,
                                                  color: Colors.black,
                                                ),
                                                dataModuleStyle: const QrDataModuleStyle(
                                                  dataModuleShape: QrDataModuleShape.square,
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              "Have the other peer scan this QR code with their device, or tap below to scan their code.",
                                              style: TextStyle(fontSize: 12, color: AppTheme.textColorSecondary),
                                              textAlign: TextAlign.center,
                                            ),
                                            const Spacer(),
                                            SafeArea(
                                              top: false,
                                              child: AnimatedPress(
                                                onTap: () {
                                                  setScannerState(() {
                                                    showScanner = true;
                                                  });
                                                },
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    gradient: AppTheme.premiumIndigoGradient,
                                                    borderRadius: BorderRadius.circular(25),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Row(
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 20),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        "SCAN PEER IDENTITY QR",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 0.8,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getFingerprint(String? key, String fallbackId) {
    final rawKey = (key != null && key.isNotEmpty) ? key : fallbackId;
    final hash = EncryptionService().sha256Hash(rawKey).toUpperCase();
    final List<String> blocks = [];
    for (int i = 0; i < hash.length && blocks.length < 6; i += 4) {
      blocks.add(hash.substring(i, min(i + 4, hash.length)));
    }
    return blocks.join(" - ");
  }

  Widget _buildSimulatedScanner(BuildContext context, {required VoidCallback onSuccess, required VoidCallback onCancel}) {
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          color: AppTheme.obsidianBackground,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                "BIOMETRIC MESH SCANNER",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mintGreen,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              
              // Animated grid scan viewfinder
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: AppTheme.mintGreen.withOpacity(0.5), width: 1.5),
                    ),
                    child: Stack(
                      children: [
                        // Viewfinder grid
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _ScannerGridPainter(),
                          ),
                        ),
                        
                        // Reticle corners
                        const _ScannerReticleCorner(alignment: Alignment.topLeft),
                        const _ScannerReticleCorner(alignment: Alignment.topRight),
                        const _ScannerReticleCorner(alignment: Alignment.bottomLeft),
                        const _ScannerReticleCorner(alignment: Alignment.bottomRight),
                        
                        // Moving scan laser line
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.05, end: 0.95),
                          duration: const Duration(milliseconds: 1500),
                          builder: (context, value, child) {
                            return Positioned(
                              top: value * MediaQuery.of(context).size.height * 0.42,
                              left: 20,
                              right: 20,
                              child: Container(
                                height: 3.5,
                                decoration: BoxDecoration(
                                  color: AppTheme.crimsonRed,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.crimsonRed.withOpacity(0.8),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          onEnd: () {
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                        
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_rounded, size: 72, color: Colors.white24),
                              const SizedBox(height: 12),
                              Text(
                                "Align QR code inside framework",
                                style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Simulated actions
              AnimatedPress(
                onTap: onSuccess,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppTheme.premiumGreenGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.mintGreen.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "SIMULATE SCAN SUCCESS",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onCancel,
                child: Text(
                  "Abort Scanning",
                  style: TextStyle(
                    color: AppTheme.textColorSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        SnackBar(
          content: const Text("Microphone permission is required to record voice notes."),
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
                Text(
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
          Text(label, style: TextStyle(color: AppTheme.textColorSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.chatId));
    final myProfile = ref.watch(profileProvider);
    final verifiedUsers = ref.watch(verifiedUsersProvider);
    
    final isGroup = widget.chatId == 'emergency_sos' || 
        (ref.read(storageServiceProvider).getChat(widget.chatId)?.type == 'group');
    final isVerified = verifiedUsers.contains(widget.chatId);

    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.chatName),
                if (!isGroup && isVerified) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.verified, color: AppTheme.mintGreen, size: 16),
                ],
              ],
            ),
            Text(
              "End-to-End Encrypted (AES-256)",
              style: TextStyle(fontSize: 10, color: AppTheme.mintGreenLight),
            ),
          ],
        ),
        actions: [
          if (!isGroup)
            IconButton(
              icon: Icon(
                isVerified ? Icons.shield : Icons.shield_outlined,
                color: isVerified ? AppTheme.mintGreen : AppTheme.textColorSecondary,
              ),
              onPressed: () => _showVerificationPanel(),
            ),
        ],
      ),
      body: Column(
        children: [
          // Security pairing banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            decoration: AppTheme.glassCardDecoration(
              color: const Color(0x1510B981),
              borderRadius: 12,
              borderColor: AppTheme.mintGreen.withOpacity(0.18),
              borderWidth: 1.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_rounded, size: 14, color: AppTheme.mintGreenLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "End-to-End Encrypted (AES-256). Peer verified via handshake.",
                    style: TextStyle(fontSize: 10, color: AppTheme.mintGreenLight, fontWeight: FontWeight.bold, letterSpacing: 0.1),
                  ),
                )
              ],
            ),
          ),

          // Message log feed wrapped with mesh background
          Expanded(
            child: _AnimatedMeshBackground(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        "No messages. Send a message to open connection.",
                        style: TextStyle(color: AppTheme.textColorSecondary.withOpacity(0.5)),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == myProfile?.userId;
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(message.messageId),
                          tween: Tween<double>(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 15 * (1.0 - value)),
                              child: Opacity(
                                opacity: value,
                                child: child,
                              ),
                            );
                          },
                          child: _buildMessageBubble(message, isMe),
                        );
                      },
                    ),
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
        decoration: BoxDecoration(
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
              const _RecordingWaveform(),
              const SizedBox(width: 12),
              Text(
                _formatDuration(_recordingSeconds),
                style: TextStyle(
                  color: AppTheme.textColorPrimary,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                icon: Icon(Icons.cancel_outlined, color: AppTheme.crimsonRed, size: 20),
                label: Text(
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

    final hasFocus = _inputFocusNode.hasFocus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.obsidianBackground,
        border: Border(
          top: BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            AnimatedPress(
              onTap: _showAttachmentSheet,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(Icons.add_circle_outline, color: AppTheme.mintGreen, size: 24),
              ),
            ),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1120),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasFocus ? AppTheme.mintGreen : AppTheme.borderLight,
                    width: hasFocus ? 1.5 : 1.0,
                  ),
                  boxShadow: hasFocus ? [
                    BoxShadow(
                      color: AppTheme.mintGreen.withOpacity(0.12),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ] : [],
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14, right: 2),
                      child: Text(
                        ">",
                        style: TextStyle(
                          color: AppTheme.mintGreen,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _inputFocusNode,
                        maxLines: null,
                        style: TextStyle(
                          color: AppTheme.textColorPrimary,
                          fontSize: 14,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: "Write message...",
                          hintStyle: TextStyle(
                            color: AppTheme.textColorSecondary,
                            fontSize: 14,
                            fontFamily: 'monospace',
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final isTextEmpty = value.text.trim().isEmpty;
                return AnimatedPress(
                  onTap: isTextEmpty ? _startRecording : _sendMessage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isTextEmpty ? AppTheme.surfaceColor : AppTheme.mintGreen.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isTextEmpty ? AppTheme.borderLight : AppTheme.mintGreen,
                        width: 1.0,
                      ),
                    ),
                    child: Icon(
                      isTextEmpty ? Icons.mic : Icons.send,
                      color: AppTheme.mintGreen,
                      size: 20,
                    ),
                  ),
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
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final palette = ThemeManager.currentTheme;

    final bubbleDecoration = isMe
        ? BoxDecoration(
            gradient: LinearGradient(
              colors: [palette.accent, palette.accentLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: palette.accentLight.withOpacity(0.3), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          )
        : BoxDecoration(
            color: palette.card,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: palette.border.withOpacity(0.2), width: 0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
            ],
          );

    final bubbleTextColor = isMe
        ? (palette.id == 'black' ? Colors.black : Colors.white)
        : palette.textPrimary;
    final bubbleSecondaryTextColor = isMe
        ? (palette.id == 'black' ? Colors.black54 : Colors.white70)
        : palette.textSecondary;
    final ticksColor = isMe
        ? (message.status == 'read'
            ? (palette.id == 'black' ? palette.accent : palette.success)
            : (palette.id == 'black' ? Colors.black45 : Colors.white54))
        : palette.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (!isMe) ...[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.secondary,
                    border: Border.all(color: palette.border.withOpacity(0.3), width: 1.0),
                  ),
                  child: const Text("👤", style: TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () => _showMessageHopsInfo(message),
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                  padding: const EdgeInsets.all(12),
                  decoration: bubbleDecoration,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMessageContent(message, isMe, bubbleTextColor, bubbleSecondaryTextColor),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.timestamp.toLocal().toString().substring(11, 16),
                            style: TextStyle(fontSize: 10, color: bubbleSecondaryTextColor),
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
                              color: ticksColor,
                            ),
                          const SizedBox(width: 6),
                          Icon(Icons.hub_outlined, size: 12, color: bubbleSecondaryTextColor),
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

  Widget _buildMessageContent(MessageModel message, bool isMe, Color textColor, Color secondaryTextColor) {
    final palette = ThemeManager.currentTheme;
    if (message.messageType == 'text') {
      return Text(
        message.content,
        style: TextStyle(color: textColor, fontSize: 14, height: 1.3),
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
              border: Border.all(color: palette.border.withOpacity(0.2)),
            ),
            child: Icon(Icons.image_outlined, size: 50, color: secondaryTextColor),
          ),
          const SizedBox(height: 6),
          Text("Photo Attachment", style: TextStyle(color: secondaryTextColor, fontSize: 12)),
        ],
      );
    } else if (message.messageType == 'document') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
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

      final latLonParts = coordinates.split(',');
      final double lat = double.tryParse(latLonParts.isNotEmpty ? latLonParts[0] : "") ?? 12.9716;
      final double lon = double.tryParse(latLonParts.length > 1 ? latLonParts[1] : "") ?? 77.5946;

      return GestureDetector(
        onTap: () => _showFullMapViewer(context, lat, lon, address),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: AbsorbPointer(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(lat, lon),
                      initialZoom: 14.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.offline.mesh.chat',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(lat, lon),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.location_on,
                              color: AppTheme.crimsonRed,
                              size: 30,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_rounded, size: 16, color: AppTheme.mintGreen),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColorPrimary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              "${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}",
              style: TextStyle(fontSize: 10, color: AppTheme.textColorSecondary),
            ),
          ],
        ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.hub_outlined, color: AppTheme.electricBlueLight),
              SizedBox(width: 8),
              Text("Message Hops Info", style: TextStyle(color: AppTheme.textColorPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Routing Path:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textColorSecondary)),
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
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.electricBlueLight,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text("Hop Count: ${message.routePath.length}", style: TextStyle(color: AppTheme.textColorPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text("Status: ${message.status.toUpperCase()}", style: TextStyle(color: AppTheme.textColorPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Close", style: TextStyle(color: AppTheme.mintGreen, fontWeight: FontWeight.bold)),
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
        decoration: BoxDecoration(
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

class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform();

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = [10, 20, 14, 26, 18, 12, 24, 16, 22, 10];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heights.length, (index) {
            final double animatedHeight = _heights[index] * (0.3 + 0.7 * _controller.value);
            return Container(
              width: 3.0,
              height: animatedHeight,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: AppTheme.crimsonRed,
                borderRadius: BorderRadius.circular(1.5),
              ),
            );
          }),
        );
      },
    );
  }
}

class _MiniEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;

  const _MiniEqualizer({required this.isPlaying, required this.color});

  @override
  State<_MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<_MiniEqualizer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _MiniEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final double val = widget.isPlaying ? (0.2 + 0.8 * _controller.value) : 0.3;
            final double height = (index == 0 ? 12 : index == 1 ? 16 : 8) * val;
            return Container(
              width: 2.0,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              color: widget.color,
            );
          }),
        );
      },
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
  double _playbackSpeed = 1.0;
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
        await _audioPlayer.setPlaybackRate(_playbackSpeed);
      } else {
        setState(() {
          _isLoading = true;
        });
        try {
          final source = await _getAudioSource();
          AudioService().registerPlaying(_audioPlayer);
          await _audioPlayer.play(source);
          await _audioPlayer.setPlaybackRate(_playbackSpeed);
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

  void _toggleSpeed() async {
    setState(() {
      if (_playbackSpeed == 1.0) {
        _playbackSpeed = 1.5;
      } else if (_playbackSpeed == 1.5) {
        _playbackSpeed = 2.0;
      } else {
        _playbackSpeed = 1.0;
      }
    });
    try {
      await _audioPlayer.setPlaybackRate(_playbackSpeed);
    } catch (e) {
      print("Error setting playback rate: $e");
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
    final palette = ThemeManager.currentTheme;
    final playerColor = widget.isMe ? Colors.white : palette.accent;
    final inactiveColor = widget.isMe ? Colors.white30 : palette.border.withOpacity(0.3);
    final textColor = widget.isMe ? Colors.white.withOpacity(0.8) : palette.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isMe ? Colors.white10 : palette.border.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause button
          _isLoading
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: playerColor,
                    ),
                  ),
                )
              : Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: playerColor.withOpacity(0.15),
                  ),
                  child: Center(
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: playerColor,
                        size: 22,
                      ),
                      onPressed: _togglePlay,
                    ),
                  ),
                ),
          const SizedBox(width: 12),
          
          // Waveform + Time/Speed column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform Row
                LayoutBuilder(
                  builder: (context, constraints) {
                    const int barCount = 24;
                    // Generate deterministic heights based on messageId hash to look like a real audio waveform
                    final heights = List.generate(barCount, (index) {
                      final seed = widget.message.messageId.hashCode + index * 13;
                      final base = 5.0 + (seed.abs() % 14).toDouble();
                      // Give it a more natural waveform curve shape (tapered edges, higher center)
                      final multiplier = 1.0 - ((index - barCount / 2).abs() / (barCount / 2)) * 0.4;
                      return base * multiplier;
                    });
                    
                    final progress = _duration.inMilliseconds > 0
                        ? _position.inMilliseconds / _duration.inMilliseconds
                        : 0.0;
                    final activeBarsCount = (progress * barCount).floor();
                    
                    void seekToPosition(Offset localPos) {
                      final double dx = localPos.dx;
                      final double fraction = (dx / constraints.maxWidth).clamp(0.0, 1.0);
                      final targetMs = (fraction * _duration.inMilliseconds).toInt();
                      _audioPlayer.seek(Duration(milliseconds: targetMs));
                    }
                    
                    return GestureDetector(
                      onHorizontalDragUpdate: (details) => seekToPosition(details.localPosition),
                      onTapDown: (details) => seekToPosition(details.localPosition),
                      child: Container(
                        height: 26,
                        color: Colors.transparent, // expanded tap/drag target area
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(barCount, (index) {
                            final isActive = index < activeBarsCount;
                            return Container(
                              width: 2.8,
                              height: heights[index],
                              decoration: BoxDecoration(
                                color: isActive ? playerColor : inactiveColor,
                                borderRadius: BorderRadius.circular(1.5),
                              ),
                            );
                          }),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 5),
                
                // Time & Speed Multiplier
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position) + " / " + (_duration == Duration.zero ? "0:00" : _formatDuration(_duration)),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        fontFamily: 'monospace',
                      ),
                    ),
                    GestureDetector(
                      onTap: _toggleSpeed,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: playerColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: playerColor.withOpacity(0.25), width: 0.8),
                        ),
                        child: Text(
                          "${_playbackSpeed.toStringAsFixed(1)}x",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: playerColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final MapController _mapController = MapController();
  LatLng _selectedLatLng = const LatLng(12.9716, 77.5946); // Default to Bangalore Campus
  String _selectedAddress = "Campus Library";

  final List<Map<String, dynamic>> _landmarks = [
    {'name': 'Campus Library', 'lat': 12.9716, 'lon': 77.5946},
    {'name': 'Central Cafeteria', 'lat': 12.9728, 'lon': 77.5925},
    {'name': 'Main Gate', 'lat': 12.9705, 'lon': 77.5910},
    {'name': 'Block A Science Lab', 'lat': 12.9740, 'lon': 77.5950},
    {'name': 'Sports Complex', 'lat': 12.9752, 'lon': 77.5930},
  ];

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      height: screenHeight * 0.8,
      decoration: BoxDecoration(
        color: AppTheme.obsidianBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        border: Border(
          top: BorderSide(color: AppTheme.borderLight, width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag handle and Title Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Column(
              children: [
                // Top drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.textColorSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: AppTheme.mintGreen),
                        SizedBox(width: 8),
                        Text(
                          "Share Location",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColorPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textColorSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // The Interactive Map
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderLight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selectedLatLng,
                        initialZoom: 15.0,
                        onTap: (tapPosition, point) {
                          setState(() {
                            _selectedLatLng = point;
                            _selectedAddress = "Custom Coordinates (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})";
                          });
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.offline.mesh.chat',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selectedLatLng,
                              width: 80,
                              height: 80,
                              child: Icon(
                                Icons.location_on,
                                color: AppTheme.crimsonRed,
                                size: 42,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Compass / Recenter Button overlay
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'recenter_fab',
                        backgroundColor: AppTheme.surfaceColor,
                        foregroundColor: AppTheme.mintGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: AppTheme.borderLight),
                        ),
                        onPressed: () {
                          _mapController.move(_selectedLatLng, 15.0);
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Landmarks horizontal list
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CAMPUS LANDMARKS (PRESETS)",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppTheme.textColorSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _landmarks.length,
              itemBuilder: (context, index) {
                final landmark = _landmarks[index];
                final isSelected = _selectedAddress == landmark['name'];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: AnimatedPress(
                    onTap: () {
                      setState(() {
                        _selectedLatLng = LatLng(landmark['lat'], landmark['lon']);
                        _selectedAddress = landmark['name'];
                      });
                      _mapController.move(_selectedLatLng, 15.0);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.mintGreen.withOpacity(0.15) : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppTheme.mintGreen : AppTheme.borderLight,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.place_rounded,
                            size: 16,
                            color: isSelected ? AppTheme.mintGreenLight : AppTheme.textColorSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            landmark['name'],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? AppTheme.textColorPrimary : AppTheme.textColorSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Display current selected details and action button
          Container(
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: AppTheme.glassCardDecoration(
                      color: AppTheme.surfaceColor.withOpacity(0.8),
                      borderRadius: 12,
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.black26,
                          child: Icon(Icons.place, color: AppTheme.crimsonRed),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedAddress,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textColorPrimary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Lat: ${_selectedLatLng.latitude.toStringAsFixed(5)}, Lon: ${_selectedLatLng.longitude.toStringAsFixed(5)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textColorSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedPress(
                    onTap: () {
                      Navigator.of(context).pop({
                        'lat': _selectedLatLng.latitude,
                        'lon': _selectedLatLng.longitude,
                        'address': _selectedAddress,
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppTheme.premiumGreenGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.mintGreen.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "SHARE LOCATION VIA MESH",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMeshBackground extends StatefulWidget {
  final Widget child;
  const _AnimatedMeshBackground({required this.child});

  @override
  State<_AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<_AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_MeshNode> _nodes = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nodes.isEmpty) {
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 15; i++) {
        _nodes.add(_MeshNode(
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
          velocity: Offset(
            (_random.nextDouble() - 0.5) * 0.8,
            (_random.nextDouble() - 0.5) * 0.8,
          ),
        ));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final size = MediaQuery.of(context).size;
        for (var node in _nodes) {
          node.position += node.velocity;
          if (node.position.dx < 0 || node.position.dx > size.width) {
            node.velocity = Offset(-node.velocity.dx, node.velocity.dy);
            node.position = Offset(
              node.position.dx.clamp(0.0, size.width),
              node.position.dy,
            );
          }
          if (node.position.dy < 0 || node.position.dy > size.height) {
            node.velocity = Offset(node.velocity.dx, -node.velocity.dy);
            node.position = Offset(
              node.position.dx,
              node.position.dy.clamp(0.0, size.height),
            );
          }
        }
        return CustomPaint(
          painter: _MeshBackgroundPainter(nodes: _nodes),
          child: widget.child,
        );
      },
    );
  }
}

class _MeshNode {
  Offset position;
  Offset velocity;
  _MeshNode({required this.position, required this.velocity});
}

class _MeshBackgroundPainter extends CustomPainter {
  final List<_MeshNode> nodes;
  _MeshBackgroundPainter({required this.nodes});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = AppTheme.borderLight.withOpacity(0.05)
      ..strokeWidth = 0.5;

    const double gridSpacing = 40.0;
    for (double x = 0; x < size.width; x += gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final linkPaint = Paint()..strokeWidth = 0.8;
    const double maxDistance = 150.0;

    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        final double dist = (nodes[i].position - nodes[j].position).distance;
        if (dist < maxDistance) {
          final double fraction = 1.0 - (dist / maxDistance);
          linkPaint.color = AppTheme.electricBlue.withOpacity(fraction * 0.15);
          canvas.drawLine(nodes[i].position, nodes[j].position, linkPaint);
        }
      }
    }

    final nodePaint = Paint()..color = AppTheme.mintGreen.withOpacity(0.4);
    final glowPaint = Paint()..color = AppTheme.mintGreen.withOpacity(0.12);

    for (var node in nodes) {
      canvas.drawCircle(node.position, 6.0, glowPaint);
      canvas.drawCircle(node.position, 2.5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ScannerGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.mintGreen.withOpacity(0.08)
      ..strokeWidth = 0.5;
    
    const double spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerReticleCorner extends StatelessWidget {
  final Alignment alignment;
  const _ScannerReticleCorner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    const double size = 20.0;
    const double thickness = 3.0;
    final color = AppTheme.mintGreen;

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(16),
        child: CustomPaint(
          painter: _ReticleCornerPainter(alignment: alignment, color: color, thickness: thickness),
        ),
      ),
    );
  }
}

class _ReticleCornerPainter extends CustomPainter {
  final Alignment alignment;
  final Color color;
  final double thickness;

  _ReticleCornerPainter({required this.alignment, required this.color, required this.thickness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke;

    final path = ui.Path();
    if (alignment == Alignment.topLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else if (alignment == Alignment.bottomRight) {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
