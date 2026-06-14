import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/storage_models.dart';
import '../data/services/communication_service.dart';
import '../data/services/mock_communication_service.dart';
import '../data/services/nearby_service.dart';
import '../data/services/storage_service.dart';
import '../data/services/routing_service.dart';
import '../core/security/encryption_service.dart';
import '../core/theme/app_theme.dart';

// --- System Services Providers ---
final storageServiceProvider = Provider<StorageService>((ref) => StorageService());
final encryptionServiceProvider = Provider<EncryptionService>((ref) => EncryptionService());

// --- Mode Selection (Simulation vs Native BLE/Nearby) ---
final simulationModeProvider = StateProvider<bool>((ref) => true); // Default to simulation mode for development/preview

// --- Selected Active Communication Service ---
final communicationServiceProvider = Provider<CommunicationService>((ref) {
  final isSim = ref.watch(simulationModeProvider);
  if (isSim) {
    return MockCommunicationService();
  } else {
    return NearbyService();
  }
});

// --- Routing Service Provider ---
final routingServiceProvider = Provider<RoutingService>((ref) {
  final commService = ref.watch(communicationServiceProvider);
  final routing = RoutingService();
  // We initialize the routing service with the active communication service
  routing.init(commService);
  return routing;
});

// --- Profile & Onboarding State Provider ---
class ProfileNotifier extends StateNotifier<UserModel?> {
  final StorageService _storage;
  final EncryptionService _encryption;

  ProfileNotifier(this._storage, this._encryption) : super(null) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    await _storage.init();
    var profile = await _storage.getMyProfile();
    if (profile == null) {
      final deviceId = const Uuid().v4();
      final keyPair = _encryption.generateKeyPair();
      profile = UserModel(
        userId: deviceId,
        name: "User_${deviceId.substring(0, 4)}",
        profilePicture: "🚀",
        deviceId: deviceId,
        publicKey: keyPair['publicKey']!,
        createdAt: DateTime.now(),
      );
      await _storage.saveMyProfile(profile);
      await _storage.savePrivateKey(keyPair['privateKey']!);
    }
    MockCommunicationService().setHostDetails(profile.userId, profile.name, profile.profilePicture);
    state = profile;
  }

  Future<void> createUserProfile(String name, String profilePicBase64) async {
    final deviceId = const Uuid().v4();
    final keyPair = _encryption.generateKeyPair();
    
    final newUser = UserModel(
      userId: deviceId,
      name: name,
      profilePicture: profilePicBase64,
      deviceId: deviceId,
      publicKey: keyPair['publicKey']!,
      createdAt: DateTime.now(),
    );

    await _storage.saveMyProfile(newUser);
    await _storage.savePrivateKey(keyPair['privateKey']!);
    
    // In simulation mode, sync host details as well
    MockCommunicationService().setHostDetails(deviceId, name, profilePicBase64);

    state = newUser;
  }

  Future<void> updateProfile(String name, String profilePicBase64) async {
    if (state == null) return;
    final updated = UserModel(
      userId: state!.userId,
      name: name,
      profilePicture: profilePicBase64,
      deviceId: state!.deviceId,
      publicKey: state!.publicKey,
      createdAt: state!.createdAt,
    );
    await _storage.saveMyProfile(updated);
    MockCommunicationService().setHostDetails(updated.userId, name, profilePicBase64);
    state = updated;
  }

  Future<void> resetKeys() async {
    if (state == null) return;
    final keyPair = _encryption.generateKeyPair();
    final updated = UserModel(
      userId: state!.userId,
      name: state!.name,
      profilePicture: state!.profilePicture,
      deviceId: state!.deviceId,
      publicKey: keyPair['publicKey']!,
      createdAt: state!.createdAt,
    );
    await _storage.saveMyProfile(updated);
    await _storage.savePrivateKey(keyPair['privateKey']!);
    // In simulation mode, set the new host details (host maintains same id/name but keys/identity rotate)
    MockCommunicationService().setHostDetails(updated.userId, updated.name, updated.profilePicture);
    state = updated;
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, UserModel?>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final encryption = ref.watch(encryptionServiceProvider);
  return ProfileNotifier(storage, encryption);
});

// --- Discovered Peers Stream Provider ---
final discoveredPeersProvider = StreamProvider<List<DiscoveredPeer>>((ref) {
  final comm = ref.watch(communicationServiceProvider);
  return comm.discoveredPeersStream;
});

// --- Active Connections Stream Provider ---
final activeConnectionsProvider = StreamProvider<Map<String, PeerConnectionStatus>>((ref) {
  final comm = ref.watch(communicationServiceProvider);
  return comm.connectionStatusStream;
});

// --- Simulation Logger Stream Provider ---
final simLogsProvider = StreamProvider<String>((ref) {
  return MockCommunicationService().simLogStream;
});

// --- Mesh Routing Logs Stream Provider ---
final routingLogsProvider = StreamProvider<String>((ref) {
  final routing = ref.watch(routingServiceProvider);
  return routing.routingLogStream;
});

// --- Verified Users Provider ---
class VerifiedUsersNotifier extends StateNotifier<Set<String>> {
  final StorageService _storage;
  
  VerifiedUsersNotifier(this._storage) : super({}) {
    _load();
  }

  void _load() {
    final verified = <String>{};
    for (var user in _storage.getAllUsers()) {
      if (_storage.isUserVerified(user.userId)) {
        verified.add(user.userId);
      }
    }
    state = verified;
  }

  Future<void> verifyUser(String userId, bool isVerified) async {
    await _storage.setUserVerification(userId, isVerified);
    if (isVerified) {
      state = {...state, userId};
    } else {
      final copy = Set<String>.from(state);
      copy.remove(userId);
      state = copy;
    }
  }
}

final verifiedUsersProvider = StateNotifierProvider<VerifiedUsersNotifier, Set<String>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return VerifiedUsersNotifier(storage);
});

// --- Theme Notifier ---
class ThemeNotifier extends StateNotifier<ThemePalette> {
  final StorageService _storage;

  ThemeNotifier(this._storage) : super(ThemeManager.defaultCyber) {
    _loadTheme();
  }

  void _loadTheme() {
    final themeId = _storage.getThemeId();
    final theme = ThemeManager.themes[themeId] ?? ThemeManager.defaultCyber;
    ThemeManager.currentTheme = theme;
    state = theme;
  }

  Future<void> changeTheme(String themeId) async {
    final theme = ThemeManager.themes[themeId] ?? ThemeManager.defaultCyber;
    await _storage.setThemeId(themeId);
    ThemeManager.currentTheme = theme;
    state = theme;
  }
}

final themePaletteProvider = StateNotifierProvider<ThemeNotifier, ThemePalette>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ThemeNotifier(storage);
});

