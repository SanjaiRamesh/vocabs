import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import '../utils/logger.dart';

// Platform helper
import 'platform_helper_io.dart';
import 'app_settings_service.dart';

class LocalTtsService {
  // Default fallback URL (can be overridden at runtime via AppSettingsService)
  static String _baseUrl =
      'https://unsoaked-nonprejudicially-carla.ngrok-free.dev';

  static const String _cacheDirectory = 'tts_cache';
  // Shared header for ngrok requests
  static const Map<String, String> _ngrokHeaders = {
    'ngrok-skip-browser-warning': 'true',
  };

  // TTS Configuration for child-friendly voice
  static const String _defaultFormat =
      'mp3'; // Indian English accent via Google TTS
  static const String _defaultLanguage = 'en'; // English

  FlutterSoundPlayer? _audioPlayer;
  static LocalTtsService? _instance;
  bool _isInitialized = false;
  bool _useSystemTts = false;

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

    try {
      // Load persisted base URL (if set)
      try {
        final configured = await AppSettingsService.getBaseUrl();
        if (configured != null && configured.trim().isNotEmpty) {
          _baseUrl = configured.trim();
          logDebug('Using configured TTS base URL: $_baseUrl');
        } else {
          logDebug('Using default TTS base URL: $_baseUrl');
        }
      } catch (e) {
        logDebug('Unable to load configured base URL: $e');
      }
      // On Windows, disable TTS for now due to compatibility issues
      if (isWindows()) {
        _useSystemTts = true;
        _isInitialized = true;
        logDebug('TTS disabled on Windows platform - using silent mode');
        return;
      }

      // Try to initialize FlutterSound for server-based TTS on Android and other platforms
      try {
        _audioPlayer = FlutterSoundPlayer();
        await _audioPlayer!.openPlayer();
        _useSystemTts = false;
        logDebug('FlutterSound initialized successfully');
      } catch (e) {
        logDebug('FlutterSound not available, using silent mode: $e');
        _useSystemTts = true;
      }

      // Create cache directory if it doesn't exist
      await _createCacheDirectory();

      _isInitialized = true;
      logDebug(
        'LocalTtsService initialized successfully (useSystemTts: $_useSystemTts)',
      );
    } catch (e) {
      logDebug('Error initializing LocalTtsService: $e');
      // Don't rethrow, just mark as failed and continue
      _isInitialized = false;
    }
  }

  /// Get the current base URL in use.
  static String get baseUrl => _baseUrl;

  /// Update the base URL at runtime and persist via AppSettingsService.
  static Future<void> setBaseUrl(String url) async {
    final sanitized = url.trim();
    if (sanitized.isEmpty) return;
    _baseUrl = sanitized;
    try {
      await AppSettingsService.setBaseUrl(sanitized);
      logDebug('Runtime base URL updated: $_baseUrl');
    } catch (e) {
      logDebug('Failed to persist base URL: $e');
    }
  }

  /// Dispose the service
  Future<void> dispose() async {
    if (!_isInitialized) return;

    try {
      if (!_useSystemTts && !isWindows() && _audioPlayer != null) {
        await _audioPlayer!.closePlayer();
      }
      _isInitialized = false;
      logDebug('LocalTtsService disposed');
    } catch (e) {
      logDebug('Error disposing LocalTtsService: $e');
    }
  }

  /// Create cache directory for storing audio files
  Future<void> _createCacheDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, _cacheDirectory));

      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
        logDebug('Created TTS cache directory: ${cacheDir.path}');
      }
    } catch (e) {
      logDebug('Error creating cache directory: $e');
      rethrow;
    }
  }

  /// Get the cache file path for a given text
  Future<String> _getCacheFilePath(String text, {String format = 'mp3'}) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = '${_sanitizeFileName(text)}.$format';
    return path.join(appDir.path, _cacheDirectory, fileName);
  }

  /// Sanitize text to create a valid filename
  String _sanitizeFileName(String text) {
    // Create a hash-like filename from the text to avoid file system issues
    final sanitized = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    // Limit length and add text hash for uniqueness
    final hash = text.hashCode.abs().toString();
    return '${sanitized.length > 20 ? sanitized.substring(0, 20) : sanitized}_$hash';
  }

  /// Check if audio file exists in cache
  Future<bool> _isFileCached(String filePath) async {
    final file = File(filePath);
    return await file.exists();
  }

  /// Download audio from TTS Flask service using GET request
  Future<Uint8List> _downloadAudioFromFlask(
    String text, {
    String format = 'mp3',
    String lang = 'en-in',
  }) async {
    try {
      logDebug('Requesting TTS for: "$text" (format: $format, lang: $lang)');

      // Build URL with query parameters
      final uri = Uri.parse('$_baseUrl/speak').replace(
        queryParameters: {'text': text, 'format': format, 'lang': lang},
      );

      logDebug('TTS Request URL: $uri');

      final response = await http
          .get(uri, headers: _ngrokHeaders)
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        logDebug(
          'Successfully received audio data (${response.bodyBytes.length} bytes)',
        );
        return response.bodyBytes;
      } else {
        throw Exception(
          'TTS Flask service returned status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      logDebug('Error downloading audio from Flask service: $e');
      rethrow;
    }
  }

  /// Save audio data to cache file
  Future<void> _saveToCache(String filePath, Uint8List audioData) async {
    try {
      final file = File(filePath);
      await file.writeAsBytes(audioData);
      logDebug('Saved audio to cache: $filePath');
    } catch (e) {
      logDebug('Error saving to cache: $e');
      rethrow;
    }
  }

  /// Speak with child-friendly default settings (Indian English accent)
  Future<void> speakChildFriendly(String text) async {
    await speak(text, format: _defaultFormat, lang: _defaultLanguage);
  }

  /// Speak the given text (convert and cache if needed, then play)
  Future<void> speak(
    String text, {
    String format = 'mp3',
    String lang = 'en',
    VoidCallback? onAudioStarted, // New callback parameter
  }) async {
    if (!_isInitialized) {
      logDebug(
        'Warning: LocalTtsService not initialized, attempting to initialize...',
      );
      await init();
      if (!_isInitialized) {
        logDebug('Failed to initialize TTS service');
        return;
      }
    }

    if (text.trim().isEmpty) {
      logDebug('Warning: Empty text provided to speak()');
      return;
    }

    // Stop any current playback to prevent overlapping
    await stop();

    try {
      if (_useSystemTts || isWindows()) {
        // On Windows, just log the text instead of speaking
        logDebug('TTS (silent mode): "$text"');
        // Simulate audio start for testing
        if (onAudioStarted != null) {
          Future.delayed(const Duration(milliseconds: 100), onAudioStarted);
        }
        return;
      } else {
        // Use server-based TTS with caching (Android and other platforms)
        logDebug('Using server TTS for: "$text"');
        final filePath = await _getCacheFilePath(text, format: format);

        // Check if file is already cached
        if (!await _isFileCached(filePath)) {
          logDebug('Audio not cached, downloading from Flask service...');

          // Download from Flask service with child-friendly settings
          final audioData = await _downloadAudioFromFlask(
            text,
            format: format, // Use mp3 for Indian English accent
            lang: lang,
          );

          // Save to cache
          await _saveToCache(filePath, audioData);
        } else {
          logDebug('Using cached audio: $filePath');
        }

        // Determine codec based on format
        final codec = format == 'mp3' ? Codec.mp3 : Codec.pcm16WAV;

        // Play the audio file
        await _audioPlayer?.startPlayer(fromURI: filePath, codec: codec);

        // Trigger callback immediately after starting player
        if (onAudioStarted != null) {
          onAudioStarted();
        }

        logDebug('Playing audio for: "$text" (format: $format, codec: $codec)');
      }
    } catch (e) {
      logDebug('TTS failed: $e');
      // On Android, we can fallback to silent mode if server TTS fails
      if (!isWindows()) {
        logDebug('Server TTS failed, continuing in silent mode');
      }
    }
  }

  /// Stop current playback
  Future<void> stop() async {
    if (!_isInitialized) return;

    try {
      // Stop FlutterSound player if available (Android and other platforms)
      if (!_useSystemTts && !isWindows() && _audioPlayer != null) {
        await _audioPlayer!.stopPlayer();
      }
      logDebug('Stopped audio playback');
    } catch (e) {
      logDebug('Error stopping playback: $e');
    }
  }

  /// Check if TTS Flask service is available
  Future<bool> isFlaskServiceAvailable() async {
    try {
      logDebug('Testing connection to TTS service: $_baseUrl');

      final response = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _ngrokHeaders)
          .timeout(const Duration(seconds: 5));

      final isAvailable = response.statusCode == 200;
      logDebug('TTS service availability: $isAvailable');

      if (isAvailable) {
        logDebug('TTS service response: ${response.body}');
      }

      return isAvailable;
    } catch (e) {
      logDebug('TTS Flask service not available: $e');
      logDebug('Possible solutions:');
      logDebug('1. Check if Flask server is running');
      logDebug('2. Verify device and PC are on same WiFi network');
      logDebug('3. Check Windows Firewall settings');
      logDebug('4. Try connecting via USB and port forwarding');
      return false;
    }
  }

  /// Comprehensive network connectivity test for debugging
  Future<Map<String, dynamic>> testNetworkConnectivity() async {
    final results = <String, dynamic>{};

    // Test 1: Basic internet connectivity
    try {
      logDebug('Testing internet connectivity...');
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));

      results['internet'] = response.statusCode == 200;
      logDebug('Internet connectivity: ${results['internet']}');
    } catch (e) {
      results['internet'] = false;
      results['internet_error'] = e.toString();
      logDebug('Internet connectivity failed: $e');
    }

    // Test 2: TTS service health check
    try {
      logDebug('Testing TTS service health...');
      final response = await http
          .get(Uri.parse('$_baseUrl/health'), headers: _ngrokHeaders)
          .timeout(const Duration(seconds: 5));

      results['tts_service'] = response.statusCode == 200;
      if (results['tts_service']) {
        results['tts_response'] = response.body;
      }
      logDebug('TTS service health: ${results['tts_service']}');
    } catch (e) {
      results['tts_service'] = false;
      results['tts_error'] = e.toString();
      logDebug('TTS service health failed: $e');
    }

    // Test 3: Network configuration info
    results['base_url'] = _baseUrl;
    results['platform'] = isAndroid() ? 'Android' : getOperatingSystem();

    // Test 4: Troubleshooting steps
    results['troubleshooting_steps'] = [
      'Ensure both device and PC are on same WiFi network',
      'Check Windows Firewall allows port 8080',
      'Verify Flask server is running on $_baseUrl',
      'Try restarting Flask server',
      'Check device WiFi connection',
    ];

    logDebug('=== NETWORK TEST RESULTS ===');
    logDebug('Base URL: ${results['base_url']}');
    logDebug('Platform: ${results['platform']}');
    logDebug('Internet: ${results['internet']}');
    logDebug('TTS Service: ${results['tts_service']}');
    logDebug('==============================');

    return results;
  }

  /// Clear all cached audio files
  Future<void> clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, _cacheDirectory));

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await _createCacheDirectory(); // Recreate empty directory
        logDebug('Cleared TTS cache');
      }
    } catch (e) {
      logDebug('Error clearing cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, _cacheDirectory));

      if (!await cacheDir.exists()) {
        return {'fileCount': 0, 'totalSize': 0};
      }

      final files = await cacheDir
          .list()
          .where((entity) => entity is File)
          .toList();
      int totalSize = 0;

      for (final file in files) {
        if (file is File) {
          try {
            final length = await file.length();
            totalSize += length;
          } catch (e) {
            logDebug('Error getting file size: $e');
          }
        }
      }

      return {
        'fileCount': files.length,
        'totalSize': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      logDebug('Error getting cache stats: $e');
      return {'fileCount': 0, 'totalSize': 0, 'error': e.toString()};
    }
  }

  /// Test helper method to access filename sanitization
  @visibleForTesting
  String sanitizeFileNameForTesting(String text) {
    return _sanitizeFileName(text);
  }

  /// Test helper method to check initialization status
  @visibleForTesting
  bool get isInitializedForTesting => _isInitialized;
}
