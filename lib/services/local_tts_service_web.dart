import 'package:flutter/foundation.dart';

class LocalTtsService {
  static LocalTtsService? _instance;
  bool _isInitialized = false;

  // Private constructor
  LocalTtsService._();

  // Singleton instance
  static LocalTtsService get instance {
    _instance ??= LocalTtsService._();
    return _instance!;
  }

  /// Initialize the TTS service
  Future<void> init() async {
    if (_isInitialized) return;
    debugPrint('TTS disabled on web platform - using silent mode');
    _isInitialized = true;
  }

  /// Dispose the service
  Future<void> dispose() async {
    _isInitialized = false;
  }

  /// Speak with child-friendly default settings
  Future<void> speakChildFriendly(String text) async {
    debugPrint('TTS (web silent mode): "$text"');
  }

  /// Speak the given text
  Future<void> speak(
    String text, {
    String format = 'mp3',
    String lang = 'en',
    VoidCallback? onAudioStarted,
  }) async {
    debugPrint('TTS (web silent mode): "$text"');
    if (onAudioStarted != null) {
      Future.delayed(const Duration(milliseconds: 100), onAudioStarted);
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    // No-op on web
  }

  /// Check if TTS Flask service is available
  Future<bool> isFlaskServiceAvailable() async {
    return false; // Always false on web
  }

  /// Network connectivity test
  Future<Map<String, dynamic>> testNetworkConnectivity() async {
    return {
      'platform': 'web',
      'tts_service': false,
      'message': 'TTS not supported on web platform',
    };
  }

  /// Clear cache (no-op on web)
  Future<void> clearCache() async {}

  /// Get cache stats
  Future<Map<String, dynamic>> getCacheStats() async {
    return {'fileCount': 0, 'totalSize': 0, 'platform': 'web'};
  }

  /// Test helper
  @visibleForTesting
  String sanitizeFileNameForTesting(String text) {
    return text.replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Test helper
  @visibleForTesting
  bool get isInitializedForTesting => _isInitialized;
}
