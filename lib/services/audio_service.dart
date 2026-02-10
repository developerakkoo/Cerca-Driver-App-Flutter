import 'package:audioplayers/audioplayers.dart';

/// AudioService - Singleton service for playing notification sounds
/// Supports both main app isolate and overlay isolate contexts
class AudioService {
  static AudioService? _instance;
  static AudioService get instance {
    _instance ??= AudioService._();
    return _instance!;
  }

  AudioService._();

  AudioPlayer? _audioPlayer;
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Initialize audio player
  /// Can be called multiple times safely
  Future<void> initialize() async {
    if (_isInitialized) {
      print('🔊 AudioService already initialized');
      return;
    }

    try {
      _audioPlayer = AudioPlayer();
      _isInitialized = true;
      print('✅ AudioService initialized successfully');
    } catch (e) {
      print('❌ Error initializing AudioService: $e');
      _isInitialized = false;
    }
  }

  /// Play ride request notification sound
  /// Works in both main app and overlay isolate contexts
  Future<void> playRideRequestSound() async {
    try {
      // Initialize if not already done
      if (!_isInitialized) {
        await initialize();
      }

      if (_audioPlayer == null) {
        print('⚠️ AudioPlayer not initialized, cannot play sound');
        return;
      }

      // Prevent multiple simultaneous plays
      if (_isPlaying) {
        print('⚠️ Sound already playing, skipping duplicate play');
        return;
      }

      _isPlaying = true;
      print('🔊 Playing ride request notification sound...');

      // Try MP3 first, then WAV
      String? soundPath;
      try {
        // Try to load MP3 file
        // AssetSource path is relative to assets/ folder
        soundPath = 'sounds/ride_request_notification.mp3';
        await _audioPlayer!.play(AssetSource(soundPath));
        print('✅ Playing sound: $soundPath');
      } catch (mp3Error) {
        print('⚠️ MP3 file not found, trying WAV: $mp3Error');
        try {
          // Fallback to WAV file
          soundPath = 'sounds/ride_request_notification.wav';
          await _audioPlayer!.play(AssetSource(soundPath));
          print('✅ Playing sound: $soundPath');
        } catch (wavError) {
          print('❌ Neither MP3 nor WAV sound file found');
          print('   MP3 error: $mp3Error');
          print('   WAV error: $wavError');
          print('   Please ensure sound file exists at: assets/sounds/ride_request_notification.mp3 or .wav');
          _isPlaying = false;
          return;
        }
      }

      // Listen for completion to reset playing flag
      _audioPlayer!.onPlayerComplete.listen((_) {
        _isPlaying = false;
        print('✅ Sound playback completed');
      });

      // Also handle errors
      _audioPlayer!.onLog.listen((message) {
        print('🔊 AudioPlayer log: $message');
      });
    } catch (e) {
      print('❌ Error playing ride request sound: $e');
      _isPlaying = false;
      // Don't throw - gracefully degrade if sound cannot play
    }
  }

  /// Stop current sound playback
  Future<void> stop() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        _isPlaying = false;
        print('🛑 Sound playback stopped');
      }
    } catch (e) {
      print('❌ Error stopping sound: $e');
    }
  }

  /// Dispose audio player resources
  Future<void> dispose() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.dispose();
        _audioPlayer = null;
        _isInitialized = false;
        _isPlaying = false;
        print('🧹 AudioService disposed');
      }
    } catch (e) {
      print('❌ Error disposing AudioService: $e');
    }
  }

  /// Check if sound is currently playing
  bool get isPlaying => _isPlaying;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
}

