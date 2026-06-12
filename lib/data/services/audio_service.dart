import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  AudioPlayer? _currentPlayer;

  AudioRecorder get recorder => _recorder;

  /// Starts recording audio. Saves the file at a generated path in the temporary directory.
  Future<String?> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        print("Audio recording permission denied.");
        return null;
      }

      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 24000, // 24kbps - optimized for offline mesh transport (~3KB per second)
          sampleRate: 16000, // 16kHz
        ),
        path: path,
      );
      print("Recording started at: $path");
      return path;
    } catch (e) {
      print("Error starting recording: $e");
      return null;
    }
  }

  /// Stops recording and returns the path to the recorded file.
  Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      print("Recording stopped. File saved at: $path");
      return path;
    } catch (e) {
      print("Error stopping recording: $e");
      return null;
    }
  }

  /// Checks if the recorder is currently recording.
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  /// Registers and stops the previous player when a new audio note starts playing.
  void registerPlaying(AudioPlayer player) {
    if (_currentPlayer != null && _currentPlayer != player) {
      try {
        _currentPlayer!.stop();
      } catch (e) {
        print("Error stopping previous audio player: $e");
      }
    }
    _currentPlayer = player;
  }

  /// Stops the active audio player session.
  void stopCurrent() {
    _currentPlayer?.stop();
    _currentPlayer = null;
  }

  /// Clean up recorder resources.
  void dispose() {
    _recorder.dispose();
  }
}
