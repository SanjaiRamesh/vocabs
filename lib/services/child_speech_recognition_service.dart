import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

/// Enhanced speech recognition service optimized for children's reading
class ChildSpeechRecognitionService {
  static final ChildSpeechRecognitionService _instance =
      ChildSpeechRecognitionService._internal();
  factory ChildSpeechRecognitionService() => _instance;
  ChildSpeechRecognitionService._internal();

  late SpeechToText _speechToText;
  bool _isInitialized = false;
  bool _isListening = false;
  Timer? _listeningTimer;

  // Speech recognition callbacks
  Function(String)? _onResult;
  Function(String)? _onFinalResult;
  Function()? _onTimeout;
  Function(String)? _onError;

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      // Request microphone permission
      final micPermission = await Permission.microphone.request();
      if (!micPermission.isGranted) {
        debugPrint('Microphone permission denied');
        return false;
      }

      _speechToText = SpeechToText();
      final available = await _speechToText.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: ${error.errorMsg}');
          _onError?.call(error.errorMsg);
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          // IMPORTANT: Don't auto-stop on status changes
          // Only update listening state when manually stopped
          if (status == 'done' || status == 'notListening') {
            // Only set _isListening to false if we're not manually managing it
            // This prevents auto-stopping on pauses
            if (!_isListening) {
              debugPrint(
                'Speech recognition ended (was already stopped manually)',
              );
            }
          }
        },
      );

      _isInitialized = available;
      debugPrint('Speech recognition initialized: $available');
      return available;
    } catch (e) {
      debugPrint('Error initializing speech recognition: $e');
      return false;
    }
  }

  /// Start listening for child speech with enhanced configuration
  Future<void> startListening({
    required Function(String) onResult,
    required Function(String) onFinalResult,
    Function()? onTimeout,
    Function(String)? onError,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) {
        onError?.call('Speech recognition not available');
        return;
      }
    }

    // Store callbacks
    _onResult = onResult;
    _onFinalResult = onFinalResult;
    _onTimeout = onTimeout;
    _onError = onError;

    // Stop any existing listening session
    await stopListening();

    try {
      _isListening = true;

      // Set up timeout timer
      _listeningTimer = Timer(timeout, () {
        debugPrint('Speech recognition timeout');
        stopListening();
        _onTimeout?.call();
      });

      // Start listening with child-optimized settings - NO AUTO-STOPPING ON PAUSES
      await _speechToText.listen(
        onResult: (result) {
          final recognizedText = result.recognizedWords.toLowerCase().trim();
          debugPrint(
            'Speech result: "$recognizedText" (confidence: ${result.confidence})',
          );

          // Call partial result callback for real-time display
          _onResult?.call(recognizedText);

          // IMPORTANT: Do NOT process final results automatically
          // Only process when manually stopped by the child
          // This prevents auto-stopping on natural reading pauses
        },
        listenOptions: SpeechListenOptions(
          partialResults: true, // Show partial results for real-time feedback
          onDevice: false, // Use cloud for better accuracy
          cancelOnError: false, // Don't stop on minor errors
          listenMode:
              ListenMode.confirmation, // Keep listening for continuous speech
          sampleRate: 16000, // Optimal for child voices
          enableHapticFeedback: true, // Haptic feedback for children
        ),
      );

      debugPrint('Started listening for child speech...');
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      _onError?.call(e.toString());
    }
  }

  /// Stop listening and process final result
  Future<void> stopListening() async {
    if (_isListening) {
      debugPrint('Manually stopping speech recognition...');

      // Get the current partial result as the final result
      String finalText = '';
      if (_speechToText.isListening) {
        finalText = _speechToText.lastRecognizedWords.toLowerCase().trim();
        debugPrint('Final recognized text: "$finalText"');
      }

      // Stop the speech recognition
      await _speechToText.stop();
      _isListening = false;
      _listeningTimer?.cancel();

      // Process the final result - this is what the child actually read
      if (finalText.isNotEmpty) {
        debugPrint('Processing final result: "$finalText"');
        _onFinalResult?.call(finalText);
      } else {
        debugPrint('No text recognized, calling timeout handler');
        _onTimeout?.call();
      }
    }
    debugPrint('Stopped listening');
  }

  /// Check if currently listening
  bool get isListening => _isListening;

  /// Check if speech recognition is available
  bool get isAvailable => _isInitialized;

  /// Dispose resources
  void dispose() {
    stopListening();
    _listeningTimer?.cancel();
  }
}

/// Fuzzy matching service for child speech recognition
class ChildFriendlyMatcher {
  /// Calculate similarity between spoken and expected text
  static double calculateSimilarity(String spoken, String expected) {
    if (spoken.isEmpty || expected.isEmpty) return 0.0;

    // Normalize both strings
    final normalizedSpoken = _normalizeText(spoken);
    final normalizedExpected = _normalizeText(expected);

    // Apply child speech corrections
    final correctedSpoken = _applyChildSpeechCorrections(normalizedSpoken);

    // Calculate multiple similarity scores
    final levenshteinScore = _calculateLevenshteinSimilarity(
      correctedSpoken,
      normalizedExpected,
    );
    final phoneticScore = _calculatePhoneticSimilarity(
      correctedSpoken,
      normalizedExpected,
    );
    final wordOrderScore = _calculateWordOrderSimilarity(
      correctedSpoken,
      normalizedExpected,
    );

    // Weighted average (prioritize phonetic similarity for children)
    final finalScore =
        (levenshteinScore * 0.3) +
        (phoneticScore * 0.5) +
        (wordOrderScore * 0.2);

    debugPrint(
      'Similarity: "$spoken" vs "$expected" = ${(finalScore * 100).toStringAsFixed(1)}%',
    );
    debugPrint(
      '  - Levenshtein: ${(levenshteinScore * 100).toStringAsFixed(1)}%',
    );
    debugPrint('  - Phonetic: ${(phoneticScore * 100).toStringAsFixed(1)}%');
    debugPrint('  - Word Order: ${(wordOrderScore * 100).toStringAsFixed(1)}%');

    return finalScore;
  }

  /// Check if the spoken text is an acceptable match
  static bool isAcceptableMatch(
    String spoken,
    String expected, {
    double threshold = 0.75,
  }) {
    return calculateSimilarity(spoken, expected) >= threshold;
  }

  /// Normalize text for comparison
  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  /// Apply common child speech pattern corrections
  static String _applyChildSpeechCorrections(String text) {
    // Common child speech substitutions
    final corrections = {
      // TH sound substitutions
      'dis': 'this',
      'dat': 'that',
      'dey': 'they',
      'dere': 'there',
      'fink': 'think',
      'free': 'three',
      'wif': 'with',

      // R sound issues
      'wight': 'right',
      'wed': 'red',
      'wun': 'run',
      'weal': 'real',

      // L sound issues
      'yike': 'like',
      'yook': 'look',
      'yittle': 'little',

      // Final consonant dropping
      'ca': 'cat',
      'ba': 'bat',
      'do': 'dog',
      'bir': 'bird',

      // Common mispronunciations
      'aminal': 'animal',
      'pasghetti': 'spaghetti',
      'pasketti': 'spaghetti',
      'yellephant': 'elephant',
      'flutterby': 'butterfly',
    };

    String correctedText = text;
    for (final entry in corrections.entries) {
      correctedText = correctedText.replaceAll(entry.key, entry.value);
    }

    return correctedText;
  }

  /// Calculate Levenshtein distance similarity
  static double _calculateLevenshteinSimilarity(String a, String b) {
    if (a == b) return 1.0;

    final matrix = List.generate(
      a.length + 1,
      (i) => List.filled(b.length + 1, 0),
    );

    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    final maxLength = max(a.length, b.length);
    if (maxLength == 0) return 1.0;

    return 1.0 - (matrix[a.length][b.length] / maxLength);
  }

  /// Calculate phonetic similarity (simplified soundex-like approach)
  static double _calculatePhoneticSimilarity(String a, String b) {
    final phoneticA = _getPhoneticCode(a);
    final phoneticB = _getPhoneticCode(b);

    if (phoneticA == phoneticB) return 1.0;
    return _calculateLevenshteinSimilarity(phoneticA, phoneticB);
  }

  /// Generate simplified phonetic code
  static String _getPhoneticCode(String word) {
    if (word.isEmpty) return '';

    String code = word.toLowerCase();

    // Group similar sounds
    code = code.replaceAll(RegExp(r'[bfpv]+'), 'b');
    code = code.replaceAll(RegExp(r'[cgjkqsxz]+'), 'c');
    code = code.replaceAll(RegExp(r'[dt]+'), 'd');
    code = code.replaceAll(RegExp(r'[lr]+'), 'l');
    code = code.replaceAll(RegExp(r'[mn]+'), 'm');
    code = code.replaceAll(RegExp(r'[aeiou]+'), 'a');

    // Remove consecutive duplicates
    String result = '';
    for (int i = 0; i < code.length; i++) {
      if (i == 0 || code[i] != code[i - 1]) {
        result += code[i];
      }
    }

    return result;
  }

  /// Calculate word order similarity
  static double _calculateWordOrderSimilarity(String a, String b) {
    final wordsA = a.split(' ').where((w) => w.isNotEmpty).toList();
    final wordsB = b.split(' ').where((w) => w.isNotEmpty).toList();

    if (wordsA.isEmpty || wordsB.isEmpty) return 0.0;

    int matchCount = 0;
    final usedB = Set<int>();

    for (final wordA in wordsA) {
      for (int i = 0; i < wordsB.length; i++) {
        if (!usedB.contains(i) &&
            _calculateLevenshteinSimilarity(wordA, wordsB[i]) > 0.8) {
          matchCount++;
          usedB.add(i);
          break;
        }
      }
    }

    return matchCount / max(wordsA.length, wordsB.length);
  }
}
