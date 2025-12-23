import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../models/reading_assessment_result.dart';
import '../services/book_service.dart';
import '../services/assessment_result_service.dart';
import '../services/local_tts_service.dart';
import '../services/phonetic_service.dart';
import '../services/word_categorization_service.dart';
import '../services/child_speech_recognition_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

// --- Utility methods for IPA and Syllables ---
String _getWordIPA(String word) {
  final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (cleanWord.isEmpty) return word;
  try {
    return PhoneticService.getIPA(cleanWord);
  } catch (e) {
    return word;
  }
}

String _getWordSyllables(String word) {
  final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
  if (cleanWord.isEmpty) return word;
  try {
    return PhoneticService.getSyllables(cleanWord);
  } catch (e) {
    return word;
  }
}
// import 'package:flutter_tts/flutter_tts.dart';
// import 'dart:io' show Platform;

class BookReadingScreen extends StatefulWidget {
  final Book book;
  final int startingChapter;

  const BookReadingScreen({
    super.key,
    required this.book,
    this.startingChapter = 0,
  });

  @override
  State<BookReadingScreen> createState() => _BookReadingScreenState();
}

class _BookReadingScreenState extends State<BookReadingScreen>
    with TickerProviderStateMixin {
  // Word-by-word listening mode state
  bool _wordByWordMode = false;
  int? _activeWordIndex; // For UI feedback
  // Tamil Translation Feature State
  bool _translationMode = false;
  String? _tamilTranslation;
  bool _isTranslating = false;
  final Map<String, String> _translationCache = {};
  OnDeviceTranslator? _translator;
  // late FlutterTts _flutterTts;
  bool _tamilModelDownloaded = false;
  int _currentPageIndex = 0;
  int _currentSentenceIndex = 0;

  List<String> _pages = [];
  List<List<String>> _pagesSentences = []; // Store sentences per page

  bool _isLoading = true;
  bool _isAssessing = false;

  DateTime? _speechStartTime;
  DateTime? _speechEndTime;

  String _currentSpokenTranscript = '';

  // Speech Recognition State for Read Feature
  bool _isReading = false;
  bool _isListening = false;
  String _recognizedText = '';
  double _lastAccuracyScore = 0.0;
  double _currentReadingProgress = 0.0; // Track real-time reading progress
  int _readingAttempts = 0;
  static const int _maxReadingAttempts = 3;

  // Learning Tools State
  bool _phonicsMode = false;
  bool _ipaMode = false;
  bool _syllableMode = false;
  bool _comprehensionMode = false;

  // Word highlighting state for TTS
  int _currentWordIndex = -1;

  // Word highlight animation
  late AnimationController _highlightController;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Learning Tools Animation Controller
  late AnimationController _learningToolsController;
  late Animation<double> _learningToolsAnimation;

  // Speech Recognition Service
  late ChildSpeechRecognitionService _speechService;

  @override
  void initState() {
    super.initState();

    // Always initialize _speechService for all platforms to avoid LateInitializationError
    _speechService = ChildSpeechRecognitionService();
    if (!Platform.isWindows) {
      _speechService.initialize();
      _translator = OnDeviceTranslator(
        sourceLanguage: TranslateLanguage.english,
        targetLanguage: TranslateLanguage.tamil,
      );
      _checkTamilModel();
    }

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Learning Tools Animation
    _learningToolsController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _learningToolsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _learningToolsController,
        curve: Curves.elasticOut,
      ),
    );

    // Word Highlight Animation - bouncy and child-friendly
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _loadBookContent();
  }

  Future<void> _checkTamilModel() async {
    if (Platform.isWindows) return;
    print('[DEBUG] Checking if Tamil model is downloaded...');
    final modelManager = OnDeviceTranslatorModelManager();
    final isDownloaded = await modelManager.isModelDownloaded(
      TranslateLanguage.tamil.bcpCode,
    );
    print('[DEBUG] Tamil model downloaded: $isDownloaded');
    if (!isDownloaded) {
      print('[DEBUG] Downloading Tamil model...');
      await modelManager.downloadModel(TranslateLanguage.tamil.bcpCode);
      print('[DEBUG] Tamil model download complete.');
    }
    setState(() {
      _tamilModelDownloaded = true;
    });
  }

  Future<void> _toggleTranslationMode() async {
    print(
      '[DEBUG] _toggleTranslationMode called. Current mode: $_translationMode',
    );
    final newMode = !_translationMode;
    setState(() {
      _translationMode = newMode;
    });
    print('[DEBUG] Translation mode after toggle: $_translationMode');
    if (newMode) {
      print(
        '[DEBUG] Triggering _translateCurrentSentence from _toggleTranslationMode',
      );
      await _translateCurrentSentence();
      setState(() {}); // Force rebuild after translation result
    }
  }

  Future<void> _translateCurrentSentence() async {
    if (Platform.isWindows) {
      print('[DEBUG] Translation requested on Windows - not supported.');
      setState(() {
        _tamilTranslation = 'Translation not available on Windows.';
      });
      return;
    }
    print('[DEBUG] _pages: "+_pages.toString()+"');
    print('[DEBUG] _currentPageIndex: $_currentPageIndex');
    final text = _pages.isNotEmpty ? _pages[_currentPageIndex] : '';
    print('[DEBUG] Text to translate: "$text"');
    if (text.isEmpty) {
      print('[DEBUG] No text to translate.');
      return;
    }
    if (_translationCache.containsKey(text)) {
      print('[DEBUG] Using cached translation.');
      setState(() {
        _tamilTranslation = _translationCache[text];
      });
      return;
    }
    setState(() {
      _isTranslating = true;
    });
    try {
      print('[DEBUG] Calling ML Kit translator...');
      final result = await _translator!.translateText(text);
      print('[DEBUG] Translation result: "$result"');
      setState(() {
        _tamilTranslation = result;
        _translationCache[text] = result;
      });
    } catch (e, st) {
      print('[DEBUG] Translation failed: $e\n$st');
      setState(() {
        _tamilTranslation = 'Translation failed.';
      });
    } finally {
      setState(() {
        _isTranslating = false;
      });
    }
  }

  Future<void> _speakTamilTranslation() async {
    if (_tamilTranslation == null || _tamilTranslation!.isEmpty) return;
    // Use LocalTtsService to send Tamil text to gTTS server for playback on all platforms
    await LocalTtsService.instance.speak(
      _tamilTranslation!,
      lang: 'ta',
      format: 'mp3',
      onAudioStarted: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playing Tamil translation...'),
              backgroundColor: Colors.deepOrange,
              duration: Duration(milliseconds: 800),
            ),
          );
        }
      },
    );
  }

  @override
  void dispose() {
    // Dispose speech recognition service
    _speechService.dispose();

    // Dispose animation controllers
    _scaleController.dispose();
    _slideController.dispose();
    _learningToolsController.dispose();
    _highlightController.dispose();

    super.dispose();
  }

  List<String> _splitSentencesWithPunctuation(String text) {
    // Split sentences while preserving punctuation
    List<String> sentences = [];

    // Use regex to find sentence boundaries but keep the punctuation
    RegExp sentencePattern = RegExp(r'([^.!?]*[.!?]+)');
    Iterable<RegExpMatch> matches = sentencePattern.allMatches(text);

    for (RegExpMatch match in matches) {
      String sentence = match.group(0)?.trim() ?? '';
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    // Handle any remaining text that doesn't end with punctuation
    int lastIndex = matches.isNotEmpty ? matches.last.end : 0;
    if (lastIndex < text.length) {
      String remaining = text.substring(lastIndex).trim();
      if (remaining.isNotEmpty) {
        sentences.add(remaining);
      }
    }

    return sentences.where((s) => s.isNotEmpty).toList();
  }

  void _loadBookContent() {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load pages from book
      if (widget.book.pages.isNotEmpty) {
        _pages = widget.book.pages;
        for (final page in widget.book.pages) {
          // Split sentences while preserving punctuation
          final sentences = _splitSentencesWithPunctuation(page);
          _pagesSentences.add(sentences); // Add sentences for this page
        }
      }

      if (_pages.isEmpty) {
        _pages = ['This book appears to be empty. Please add some content.'];
        _pagesSentences = [
          ['This book appears to be empty'],
        ];
      }

      // Set starting position
      _currentPageIndex = widget.startingChapter.clamp(0, _pages.length - 1);
      _currentSentenceIndex = 0;

      setState(() {
        _isLoading = false;
      });

      // Start slide animation
      _slideController.forward();
      _learningToolsController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pages = ['Error loading book content: $e'];
        _pagesSentences = [
          ['Error loading book'],
        ];
      });
    }
  }

  void _previousPage() {
    debugPrint('Previous page called. Current page index: $_currentPageIndex');
    if (_currentPageIndex > 0) {
      HapticFeedback.lightImpact();
      _slideController.reset();
      setState(() {
        _currentPageIndex--;
        _currentSentenceIndex = 0;
      });
      debugPrint('Updated to page index: $_currentPageIndex');
      _slideController.forward();
    } else {
      debugPrint('Cannot go to previous page - already at first page');
    }
  }

  void _nextPage() {
    debugPrint(
      'Next page called. Current page index: $_currentPageIndex, Total pages: ${_pages.length}',
    );
    if (_currentPageIndex < _pages.length - 1) {
      HapticFeedback.lightImpact();
      _slideController.reset();
      setState(() {
        _currentPageIndex++;
        _currentSentenceIndex = 0;
      });
      debugPrint('Updated to page index: $_currentPageIndex');
      _slideController.forward();
    } else {
      debugPrint('Cannot go to next page - already at last page');
    }
  }

  void _showSettingsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reading Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('Text-to-Speech'),
              subtitle: const Text('Hear the text read aloud'),
              onTap: () {
                Navigator.pop(context);
                _speakCurrentSentence();
              },
            ),
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Reading Assessment'),
              subtitle: const Text('Practice reading evaluation'),
              onTap: () {
                Navigator.pop(context);
                _startAssessment();
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Bookmark Page'),
              subtitle: const Text('Save current progress'),
              onTap: () {
                Navigator.pop(context);
                _bookmarkCurrentPage();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _speakCurrentSentence() async {
    print('🔥 READING ALL SENTENCES ON PAGE');
    final currentPageSentences =
        (_pagesSentences.isNotEmpty &&
            _currentPageIndex < _pagesSentences.length)
        ? _pagesSentences[_currentPageIndex]
        : <String>[];

    print(
      '🔥 Found ${currentPageSentences.length} sentences: $currentPageSentences',
    );

    if (currentPageSentences.isNotEmpty) {
      // Combine all sentences on the page for continuous audio
      final fullPageText = currentPageSentences.join(' ');
      print('🔥 Reading full page text: "$fullPageText"');

      try {
        // Reset highlighting state
        setState(() {
          _currentSentenceIndex = 0;
          _currentWordIndex = -1;
        });

        // Speak and highlight the entire page content
        await _speakWithWordHighlightingFullPage(currentPageSentences);

        // Reset highlighting after completion
        if (mounted) {
          setState(() {
            _currentWordIndex = -1;
            _currentSentenceIndex = 0;
          });
        }
      } catch (e) {
        print('🔥 TTS Error: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('TTS Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _startAssessment() {
    final currentPageSentences =
        (_pagesSentences.isNotEmpty &&
            _currentPageIndex < _pagesSentences.length)
        ? _pagesSentences[_currentPageIndex]
        : <String>[];
    if (currentPageSentences.isNotEmpty &&
        _currentSentenceIndex < currentPageSentences.length) {
      setState(() {
        _isAssessing = true;
        _speechStartTime = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assessment started! Read the highlighted sentence aloud.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _finishAssessment() async {
    if (_speechStartTime != null) {
      _speechEndTime = DateTime.now();

      // Simulate speech recognition result (in real app, you'd use speech_to_text)
      final currentPageSentences =
          (_pagesSentences.isNotEmpty &&
              _currentPageIndex < _pagesSentences.length)
          ? _pagesSentences[_currentPageIndex]
          : <String>[];
      final currentSentence =
          (currentPageSentences.isNotEmpty &&
              _currentSentenceIndex < currentPageSentences.length)
          ? currentPageSentences[_currentSentenceIndex]
          : 'No sentence available';
      _currentSpokenTranscript =
          currentSentence; // Simulated perfect recognition

      final assessmentResult = ReadingAssessmentResult.fromBasicAssessment(
        targetSentence: currentSentence,
        spokenTranscript: _currentSpokenTranscript,
        speechStartTime: _speechStartTime!,
        speechEndTime: _speechEndTime!,
      );

      try {
        await AssessmentResultService.saveResult(
          assessmentResult,
          bookId: widget.book.id,
          bookTitle: widget.book.title,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Assessment completed! Accuracy: ${assessmentResult.accuracyPercentage.toStringAsFixed(1)}%',
              ),
              backgroundColor: assessmentResult.overallPassed
                  ? Colors.green
                  : Colors.orange,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving assessment: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      setState(() {
        _isAssessing = false;
        _speechStartTime = null;
        _speechEndTime = null;
      });
    }
  }

  void _bookmarkCurrentPage() async {
    try {
      final updatedBook = Book(
        id: widget.book.id,
        title: widget.book.title,
        author: widget.book.author,
        description: widget.book.description,
        coverImagePath: widget.book.coverImagePath,
        pages: widget.book.pages,
        createdAt: widget.book.createdAt,
        updatedAt: DateTime.now(),
        language: widget.book.language,
        difficulty: widget.book.difficulty,
        tags: widget.book.tags,
        readingTime: widget.book.readingTime,
        isFavorite: widget.book.isFavorite,
        userRating: widget.book.userRating,
        timesRead: widget.book.timesRead,
      );

      await BookService.saveBook(updatedBook);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving progress: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== READ FEATURE METHODS ====================

  /// Start the reading feature - child reads the current page aloud
  void _startReadingMode() async {
    final currentPageSentences =
        (_pagesSentences.isNotEmpty &&
            _currentPageIndex < _pagesSentences.length)
        ? _pagesSentences[_currentPageIndex]
        : <String>[];

    if (currentPageSentences.isEmpty) {
      _showMessage('No content to read on this page.', Colors.orange);
      return;
    }

    setState(() {
      _isReading = true;
      _readingAttempts = 0;
      _recognizedText = '';
      _lastAccuracyScore = 0.0;
      _currentReadingProgress = 0.0; // Reset progress for new session
    });

    _showMessage(
      '📖 Ready to read! Take as long as you need - you can pause, think, and continue reading. Only tap "Stop Reading" when you\'re completely done with the sentence.',
      Colors.blue,
    );
  }

  /// Start listening for child's speech

  void _startListeningForReading() async {
    // Guard: Do not run speech recognition on Windows
    if (Platform.isWindows) {
      _showMessage(
        'Speech recognition is not supported on Windows.',
        Colors.red,
      );
      return;
    }
    // Explicitly check/request microphone permission before initializing STT
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        debugPrint('Microphone permission denied by user.');
        _showMessage(
          'Microphone permission is required for speech recognition.',
          Colors.red,
        );
        return;
      }
    }
    debugPrint('Microphone permission granted. Proceeding to initialize STT.');
    if (!_speechService.isAvailable) {
      final initialized = await _speechService.initialize();
      debugPrint('Speech service initialized: $initialized');
      if (!initialized) {
        _showMessage(
          'Speech recognition not available. Please check microphone permissions.',
          Colors.red,
        );
        return;
      }
    }

    if (_isListening) {
      await _stopListening();
      return;
    }

    final currentPageSentences =
        (_pagesSentences.isNotEmpty &&
            _currentPageIndex < _pagesSentences.length)
        ? _pagesSentences[_currentPageIndex]
        : <String>[];

    if (currentPageSentences.isEmpty) return;

    final expectedText = currentPageSentences.join(' ');

    setState(() {
      _isListening = true;
      _recognizedText = '';
      _currentReadingProgress = 0.0; // Reset for new listening session
    });

    _showMessage(
      '📖 Reading the complete sentence... Take your time and read at your own pace! The app will wait for you - just tap "Stop Reading" when you finish.',
      Colors.green,
    );

    await _speechService.startListening(
      onResult: (partialResult) {
        if (mounted) {
          // Calculate real-time reading progress
          final expectedWords = expectedText
              .toLowerCase()
              .split(' ')
              .where((w) => w.isNotEmpty)
              .toList();
          final spokenWords = partialResult
              .toLowerCase()
              .split(' ')
              .where((w) => w.isNotEmpty)
              .toList();

          // Calculate progress as percentage of expected words spoken
          double progress = 0.0;
          if (expectedWords.isNotEmpty) {
            // Count how many expected words have been matched
            int matchedWords = 0;
            for (
              int i = 0;
              i < spokenWords.length && i < expectedWords.length;
              i++
            ) {
              if (spokenWords[i].contains(
                expectedWords[i].substring(
                  0,
                  (expectedWords[i].length * 0.6).round(),
                ),
              )) {
                matchedWords++;
              }
            }
            progress = matchedWords / expectedWords.length;
          }
          setState(() {
            _recognizedText = partialResult;
            _currentReadingProgress = progress;
          });
        }
      },
      onFinalResult: (finalResult) {
        if (mounted) {
          setState(() {
            _recognizedText = finalResult;
            _isListening = false;
            // _isReading remains true if user hasn't tapped Stop
          });
          // If still reading, restart listening
          if (_isReading) {
            Future.delayed(
              const Duration(milliseconds: 300),
              _startListeningForReading,
            );
          }
        }
      },
      onTimeout: () {
        if (mounted) {
          setState(() {
            _isListening = false;
            // _isReading remains true if user hasn't tapped Stop
          });
          _showMessage('Listening timed out. Resuming...', Colors.orange);
          // Removed automatic restart logic to prevent looping errors
          if (_isReading) {
            _showMessage('Listening timed out. Resuming...', Colors.orange);
            Future.delayed(
              const Duration(milliseconds: 300),
              _startListeningForReading,
            );
          } else {
            debugPrint(
              'Listening timed out but user stopped reading. No restart.',
            );
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _isReading = false; // Stop reading state
          });
        }
        _showMessage('Speech recognition error: $error', Colors.red);
      },
      timeout: const Duration(
        minutes: 5,
      ), // Kid-friendly: listen up to 5 minutes or until stopped
    );
  }

  /// Stop listening
  Future<void> _stopListening() async {
    await _speechService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  /// Process the speech recognition result
  void _processSpeechResult(String spokenText, String expectedText) async {
    await _stopListening();

    _readingAttempts++;
    final similarity = ChildFriendlyMatcher.calculateSimilarity(
      spokenText,
      expectedText,
    );

    setState(() {
      _lastAccuracyScore = similarity;
      _recognizedText = spokenText;
    });

    debugPrint('🎤 Speech Result: "$spokenText"');
    debugPrint('🎯 Expected: "$expectedText"');
    debugPrint('📊 Accuracy: ${(similarity * 100).toStringAsFixed(1)}%');

    // Determine success threshold based on attempt number
    double threshold = 0.75; // Base threshold
    if (_readingAttempts == 2)
      threshold = 0.65; // More lenient on second attempt
    if (_readingAttempts >= 3)
      threshold = 0.55; // Most lenient on third attempt

    if (similarity >= threshold) {
      _handleSuccessfulReading(similarity);
    } else if (_readingAttempts >= _maxReadingAttempts) {
      _handleMaxAttemptsReached();
    } else {
      _handleRetryNeeded(similarity);
    }
  }

  /// Handle successful reading
  void _handleSuccessfulReading(double accuracy) {
    final percentage = (accuracy * 100).toStringAsFixed(1);

    // Show encouraging feedback
    String message;
    Color color;

    if (accuracy >= 0.9) {
      message = '🌟 Excellent reading! ${percentage}% accuracy!';
      color = Colors.green;
    } else if (accuracy >= 0.8) {
      message = '👍 Great job! ${percentage}% accuracy!';
      color = Colors.green;
    } else {
      message = '😊 Good reading! ${percentage}% accuracy!';
      color = Colors.blue;
    }

    _showMessage(message, color);

    // Reset reading state
    setState(() {
      _isReading = false;
      _readingAttempts = 0;
    });

    // Optional: Auto-advance to next page after success
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _currentPageIndex < _pages.length - 1) {
        _nextPage();
      }
    });
  }

  /// Handle when retry is needed
  void _handleRetryNeeded(double accuracy) {
    final percentage = (accuracy * 100).toStringAsFixed(1);
    final attemptsLeft = _maxReadingAttempts - _readingAttempts;

    String message;
    if (accuracy < 0.5) {
      // Low accuracy - might be partial reading
      message =
          '📖 ${percentage}% - Try reading the whole sentence! You can do it! ($attemptsLeft attempts left)';
    } else if (_readingAttempts == 1) {
      message =
          '🤔 ${percentage}% - Let\'s try again! You can do it! ($attemptsLeft attempts left)';
    } else {
      message =
          '😊 ${percentage}% - One more try! Take your time! ($attemptsLeft attempts left)';
    }

    _showMessage(message, Colors.orange);
  }

  /// Handle when maximum attempts reached
  void _handleMaxAttemptsReached() {
    final percentage = (_lastAccuracyScore * 100).toStringAsFixed(1);

    _showMessage(
      '📚 ${percentage}% - Good effort! Let\'s hear how it sounds.',
      Colors.purple,
    );

    // Play the correct pronunciation
    Future.delayed(const Duration(seconds: 1), () {
      _speakCurrentSentence();
    });

    // Reset reading state
    setState(() {
      _isReading = false;
      _readingAttempts = 0;
    });
  }

  /// Handle speech recognition timeout (now very long timeout)
  void _handleSpeechTimeout() {
    _stopListening();
    _showMessage(
      '📚 That was a nice long reading session! Great job!',
      Colors.blue,
    );
  }

  /// Handle speech recognition error
  void _handleSpeechError(String error) {
    _stopListening();
    _showMessage('❌ Speech recognition error. Please try again.', Colors.red);
    debugPrint('Speech recognition error: $error');
  }

  /// Show a message to the user
  void _showMessage(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==================== END READ FEATURE METHODS ====================

  // Learning Tools Methods
  void _togglePhonicsMode() {
    setState(() {
      _phonicsMode = !_phonicsMode;
      if (_phonicsMode) {
        _ipaMode = false;
        _syllableMode = false;
        _comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleIpaMode() {
    setState(() {
      _ipaMode = !_ipaMode;
      if (_ipaMode) {
        _phonicsMode = false;
        _syllableMode = false;
        _comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleSyllableMode() {
    setState(() {
      _syllableMode = !_syllableMode;
      if (_syllableMode) {
        _phonicsMode = false;
        _ipaMode = false;
        _comprehensionMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleComprehensionMode() {
    setState(() {
      _comprehensionMode = !_comprehensionMode;
      if (_comprehensionMode) {
        _phonicsMode = false;
        _ipaMode = false;
        _syllableMode = false;
      }
    });
    HapticFeedback.lightImpact();
  }

  String _transformTextForLearning(String text) {
    // Always return original text - hints are now shown in top panel
    return text;
  }

  Widget _buildHighlightedHintText() {
    final currentPageSentences =
        (_pagesSentences.isNotEmpty &&
            _currentPageIndex < _pagesSentences.length)
        ? _pagesSentences[_currentPageIndex]
        : <String>[];

    if (currentPageSentences.isEmpty) return const SizedBox.shrink();

    final currentText = currentPageSentences.join(' ');
    final words = currentText.split(' ');

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: words.asMap().entries.map((entry) {
        int index = entry.key;
        String word = entry.value;
        final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
        final isHighlighted = _currentWordIndex == index;

        String hintText = '';
        if (_phonicsMode && cleanWord.length >= 1) {
          hintText = _getWordPhonics(cleanWord);
        } else if (_ipaMode && cleanWord.length >= 1) {
          hintText = _getWordIPA(cleanWord);
        } else if (_syllableMode && cleanWord.length >= 2) {
          hintText = _getWordSyllables(cleanWord);
        } else if (_comprehensionMode && cleanWord.length >= 1) {
          hintText = _getWordCategory(cleanWord.toLowerCase());
        }

        Widget wordWidget = Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1),
          padding: isHighlighted
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: isHighlighted
              ? BoxDecoration(
                  color: const Color(0xFF2196F3), // Friendly blue
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ],
                )
              : null,
          child: RichText(
            text: TextSpan(
              children: [
                // Original word
                TextSpan(
                  text: word,
                  style: TextStyle(
                    fontSize: 16,
                    color: isHighlighted ? Colors.white : Colors.deepPurple,
                    fontFamily: 'OpenDyslexic',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Hint text if available
                if (hintText.isNotEmpty &&
                    hintText != word &&
                    hintText != cleanWord) ...[
                  TextSpan(
                    text: ': ',
                    style: TextStyle(
                      fontSize: 16,
                      color: isHighlighted ? Colors.white : Colors.grey[600],
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  TextSpan(
                    text: hintText,
                    style: TextStyle(
                      fontSize: 16,
                      color: isHighlighted
                          ? Colors.white
                          : const Color(0xFFFF9800), // Warm orange
                      fontFamily: 'OpenDyslexic',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );

        // Add bouncing animation for highlighted word
        if (isHighlighted) {
          return AnimatedBuilder(
            animation: _highlightController,
            builder: (context, child) {
              return Transform.scale(
                scale:
                    1.0 +
                    (_scaleAnimation.value *
                        0.1), // Gentler 10% scale for hints
                child: wordWidget,
              );
            },
          );
        }

        return wordWidget;
      }).toList(),
    );
  }

  String _getWordPhonics(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.isEmpty) return word;

    // Auto-generate phonics for any word using professional dart_phonetics library
    return _generatePhonics(cleanWord);
  }

  String _generatePhonics(String word) {
    if (word.length <= 1) return word;

    try {
      // Use the professional dart_phonetics package - no manual lists needed!
      return PhoneticService.getPhonics(word);
    } catch (e) {
      // Simple fallback - split into basic phoneme groups
      return _simplePhonicsBreakdown(word);
    }
  }

  String _simplePhonicsBreakdown(String word) {
    // Minimal fallback - just basic vowel/consonant grouping
    if (word.length <= 2) return word;

    String result = '';
    List<String> vowels = ['a', 'e', 'i', 'o', 'u'];

    for (int i = 0; i < word.length; i++) {
      if (i > 0) {
        bool currentIsVowel = vowels.contains(word[i].toLowerCase());
        bool previousIsVowel = vowels.contains(word[i - 1].toLowerCase());

        if (currentIsVowel != previousIsVowel) {
          result += '-';
        }
      }
      result += word[i];
    }
    return result;
  }

  String _getWordCategory(String word) {
    return WordCategorizationService.getWordCategory(word);
  }

  Widget _buildHighlightedText(String text) {
    final words = text.split(' ');
    // If word-by-word mode, make each word tappable for TTS
    return Wrap(
      children: words.asMap().entries.map((entry) {
        int index = entry.key;
        String word = entry.value;
        bool isHighlighted = _currentWordIndex == index;
        bool isActiveWord = _activeWordIndex == index;

        Widget wordWidget = Container(
          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
          padding: isHighlighted || isActiveWord
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
              : const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: (isHighlighted || isActiveWord)
              ? BoxDecoration(
                  color: isActiveWord ? Colors.blue : const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ],
                )
              : null,
          child: Text(
            word + (index < words.length - 1 ? ' ' : ''),
            style: TextStyle(
              fontSize: MediaQuery.of(context).size.width > 600 ? 24 : 20,
              height: 1.6,
              color: (isHighlighted || isActiveWord)
                  ? Colors.white
                  : Colors.black87,
              fontFamily: 'OpenDyslexic',
              fontWeight: (isHighlighted || isActiveWord)
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        );

        // If in word-by-word mode, make word tappable
        if (_wordByWordMode) {
          return GestureDetector(
            onTap: () async {
              setState(() {
                _activeWordIndex = index;
              });
              await LocalTtsService.instance.speak(word);
              if (mounted) {
                setState(() {
                  _activeWordIndex = null;
                });
              }
            },
            child: wordWidget,
          );
        }

        // Add bouncing animation for highlighted word (normal mode)
        if (isHighlighted) {
          return AnimatedBuilder(
            animation: _highlightController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_scaleAnimation.value * 0.15),
                child: wordWidget,
              );
            },
          );
        }
        return wordWidget;
      }).toList(),
    );
  }

  Future<void> _speakWithWordHighlightingFullPage(
    List<String> sentences,
  ) async {
    print('🔥 IMPROVED: Speaking with better word highlighting sync');

    // Reset highlighting
    setState(() {
      _currentWordIndex = -1;
      _currentSentenceIndex = 0;
    });

    try {
      // Toggle for different approaches (set to true for word-by-word mode)
      const bool useWordByWordMode =
          false; // Change to true to test word-by-word mode

      if (useWordByWordMode) {
        // APPROACH 1: Word-by-word TTS (better sync but slower)
        await _speakWordByWord(sentences);
      } else {
        // APPROACH 2: Improved full-sentence with better timing
        await _speakFullPageWithImprovedTiming(sentences);
      }
    } catch (e) {
      debugPrint('Error in improved highlighting: $e');
      // Simple fallback
      await _fallbackHighlighting(sentences);
    }

    // Reset highlighting after completion
    if (mounted) {
      setState(() {
        _currentWordIndex = -1;
        _currentSentenceIndex = 0;
      });
    }
  }

  Future<void> _speakWordByWord(List<String> sentences) async {
    int globalWordIndex = 0;

    for (
      int sentenceIndex = 0;
      sentenceIndex < sentences.length;
      sentenceIndex++
    ) {
      if (!mounted) break;

      final sentence = sentences[sentenceIndex];
      final words = sentence.split(' ').where((w) => w.isNotEmpty).toList();

      setState(() {
        _currentSentenceIndex = sentenceIndex;
      });

      // Speak each word with intelligent punctuation handling
      for (int wordIndex = 0; wordIndex < words.length; wordIndex++) {
        if (!mounted) break;

        final originalWord = words[wordIndex];

        // Preserve punctuation for TTS but handle it intelligently
        String wordForTts = originalWord;
        int extraPauseMs = 0;

        // Check for punctuation that should add pauses
        if (originalWord.endsWith('.') ||
            originalWord.endsWith('!') ||
            originalWord.endsWith('?')) {
          extraPauseMs = 500; // Extra pause after sentence endings
        } else if (originalWord.endsWith(',') ||
            originalWord.endsWith(';') ||
            originalWord.endsWith(':')) {
          extraPauseMs = 250; // Extra pause after commas/semicolons
        }

        // For very short words with punctuation, keep the punctuation for natural TTS
        // For longer words, we can safely remove punctuation without affecting natural speech
        if (originalWord.replaceAll(RegExp(r'[^\w]'), '').length <= 2) {
          // Keep punctuation for short words like "I.", "no,", "go!"
          wordForTts = originalWord;
        } else {
          // For longer words, clean punctuation but add pause timing
          wordForTts = originalWord.replaceAll(RegExp(r'[^\w\s]'), '');
        }

        // Start speaking the word with callback for when audio starts
        if (wordForTts.isNotEmpty) {
          LocalTtsService.instance.speak(
            wordForTts,
            onAudioStarted: () {
              // Trigger bounce animation
              _highlightController.reset();
              _highlightController.forward();

              // Highlight current word - now synchronized with audio
              setState(() {
                _currentWordIndex = globalWordIndex;
              });
            },
          );
        }

        // Wait for word to complete with punctuation-aware timing
        int baseWordDuration =
            800 + // Base timing for word completion
            (wordForTts.replaceAll(RegExp(r'[^\w]'), '').length *
                40); // Base timing + 40ms per letter
        int totalDuration =
            baseWordDuration + extraPauseMs; // Add extra pause for punctuation
        await Future.delayed(Duration(milliseconds: totalDuration));

        globalWordIndex++;
      }

      // Small pause between sentences
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }

  Future<void> _speakFullPageWithImprovedTiming(List<String> sentences) async {
    // Combine all sentences
    final fullText = sentences.join(' ');
    final allWords = <String>[];
    final sentenceBoundaries = <int>[];

    // Build word list with sentence tracking
    for (
      int sentenceIndex = 0;
      sentenceIndex < sentences.length;
      sentenceIndex++
    ) {
      final words = sentences[sentenceIndex]
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      allWords.addAll(words);

      for (int i = 0; i < words.length; i++) {
        sentenceBoundaries.add(sentenceIndex);
      }
    }

    print('🔥 Speaking full page: ${allWords.length} words');

    // Start speaking the entire page WITH callback for when audio actually starts
    LocalTtsService.instance.speak(
      fullText,
      onAudioStarted: () {
        print('🔥 Audio started! Beginning word highlighting now...');
        // Start highlighting immediately when audio begins
        _startWordHighlighting(allWords, sentenceBoundaries);
      },
    );
  }

  /// Start word highlighting synchronized with audio
  void _startWordHighlighting(
    List<String> allWords,
    List<int> sentenceBoundaries,
  ) async {
    // Highlight words with improved timing
    for (int i = 0; i < allWords.length; i++) {
      if (!mounted) break;

      final currentWord = allWords[i];
      final currentSentenceIndex = sentenceBoundaries[i];

      // Update sentence highlighting
      if (_currentSentenceIndex != currentSentenceIndex) {
        setState(() {
          _currentSentenceIndex = currentSentenceIndex;
        });
      }

      // Trigger bounce animation
      _highlightController.reset();
      _highlightController.forward();

      // Highlight current word
      setState(() {
        _currentWordIndex = i;
      });

      // Enhanced timing calculation with better punctuation handling
      int baseDelay = 420; // Base delay for word pronunciation
      int lengthBonus =
          currentWord.replaceAll(RegExp(r'[^\w]'), '').length *
          35; // Per-character timing for letters only
      int punctuationDelay = 0;

      // More accurate punctuation detection and timing
      final cleanWord = currentWord.trim();

      // Strong sentence endings get longer pauses
      if (cleanWord.endsWith('.') ||
          cleanWord.endsWith('!') ||
          cleanWord.endsWith('?')) {
        punctuationDelay =
            600; // Longer pause for sentence endings to match TTS
      }
      // Commas and semicolons get medium pauses
      else if (cleanWord.endsWith(',') ||
          cleanWord.endsWith(';') ||
          cleanWord.endsWith(':')) {
        punctuationDelay = 300; // Medium pause for clause breaks
      }
      // Also check if punctuation is in the middle of "word" (like contractions)
      else if (cleanWord.contains(',') || cleanWord.contains(';')) {
        punctuationDelay = 200; // Shorter pause for mid-word punctuation
      }

      int totalDelay = baseDelay + lengthBonus + punctuationDelay;

      // Wait for the calculated duration
      await Future.delayed(Duration(milliseconds: totalDelay));
    }
  }

  Future<void> _fallbackHighlighting(List<String> sentences) async {
    final allWords = <String>[];
    final sentenceBoundaries = <int>[];

    for (
      int sentenceIndex = 0;
      sentenceIndex < sentences.length;
      sentenceIndex++
    ) {
      final words = sentences[sentenceIndex]
          .split(' ')
          .where((w) => w.isNotEmpty)
          .toList();
      allWords.addAll(words);

      for (int i = 0; i < words.length; i++) {
        sentenceBoundaries.add(sentenceIndex);
      }
    }

    for (int i = 0; i < allWords.length; i++) {
      if (!mounted) break;

      setState(() {
        _currentWordIndex = i;
        _currentSentenceIndex = sentenceBoundaries[i];
      });

      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  Widget _buildLearningToolButton({
    required String icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isActive ? activeColor : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.identity()..scale(isActive ? 1.2 : 1.0),
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive ? activeColor : Colors.white,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[DEBUG] BookReadingScreen build called. _isLoading=$_isLoading');
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final currentPage = _pages.isNotEmpty ? _pages[_currentPageIndex] : '';
    final displayText = _transformTextForLearning(currentPage);
    final progress = _pages.isNotEmpty
        ? (_currentPageIndex + 1) / _pages.length
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Main content
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE1F5FE),
                  Color(0xFFF3E5F5),
                  Color(0xFFE8F5E8),
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.deepPurple,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.deepPurple,
                                  fontFamily: 'OpenDyslexic',
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.book.author.isNotEmpty)
                                Text(
                                  'by ${widget.book.author}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _showSettingsDialog,
                          icon: const Icon(
                            Icons.settings,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Learning Tools Bar
                  AnimatedBuilder(
                    animation: _learningToolsAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _learningToolsAnimation.value,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6B73FF), Color(0xFF9C27B0)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Phonics Mode - Animal Theme
                              _buildLearningToolButton(
                                icon: _phonicsMode ? '🦁' : '🐨',
                                label: 'Sounds',
                                isActive: _phonicsMode,
                                onTap: _togglePhonicsMode,
                                activeColor: Colors.orange,
                              ),

                              // IPA Mode - Animal Theme
                              _buildLearningToolButton(
                                icon: _ipaMode ? '🦋' : '🐧',
                                label: 'IPA',
                                isActive: _ipaMode,
                                onTap: _toggleIpaMode,
                                activeColor: Colors.cyan,
                              ),

                              // Syllable Mode - School Theme
                              _buildLearningToolButton(
                                icon: _syllableMode ? '📖' : '📚',
                                label: 'Split',
                                isActive: _syllableMode,
                                onTap: _toggleSyllableMode,
                                activeColor: Colors.green,
                              ),

                              // Comprehension Mode - School Theme
                              _buildLearningToolButton(
                                icon: _comprehensionMode ? '🎓' : '🤔',
                                label: 'Quiz',
                                isActive: _comprehensionMode,
                                onTap: _toggleComprehensionMode,
                                activeColor: Colors.purple,
                              ),

                              // Tamil Translation Mode
                              _buildLearningToolButton(
                                icon: _translationMode ? '🈺' : '🌐',
                                label: 'Translate',
                                isActive: _translationMode,
                                onTap: () {
                                  print('[DEBUG] Translate button tapped');
                                  _toggleTranslationMode();
                                },
                                activeColor: Colors.deepOrange,
                              ),
                              // (Translation bar moved to top panel)
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Progress indicator
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Page ${_currentPageIndex + 1} of ${_pages.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Main reading area
                  Expanded(
                    child: Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width > 600
                            ? 32
                            : 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(25),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Top hint panel - clean and simple for all learning modes
                              if (_phonicsMode ||
                                  _ipaMode ||
                                  _syllableMode ||
                                  _comprehensionMode)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsets.only(bottom: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.deepPurple.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _phonicsMode
                                            ? 'Phonics'
                                            : _ipaMode
                                            ? 'Pronunciation'
                                            : _syllableMode
                                            ? 'Syllables'
                                            : 'Comprehension',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.deepPurple,
                                          fontFamily: 'OpenDyslexic',
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      _buildHighlightedHintText(),
                                    ],
                                  ),
                                ),

                              // Main content area
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  child: SingleChildScrollView(
                                    child: AnimatedBuilder(
                                      animation: _scaleAnimation,
                                      builder: (context, child) => Transform.scale(
                                        scale: _scaleAnimation.value,
                                        child: Container(
                                          decoration: _isAssessing
                                              ? BoxDecoration(
                                                  border: Border.all(
                                                    color: Colors.blue,
                                                    width: 2,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  color: Colors.blue.withAlpha(
                                                    25,
                                                  ),
                                                )
                                              : null,
                                          padding: _isAssessing
                                              ? const EdgeInsets.all(8)
                                              : null,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildHighlightedText(
                                                displayText,
                                              ),
                                              if (_translationMode)
                                                Container(
                                                  margin: const EdgeInsets.only(
                                                    top: 16,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.deepOrange
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      _isTranslating
                                                          ? const Center(
                                                              child:
                                                                  CircularProgressIndicator(),
                                                            )
                                                          : Text(
                                                              _tamilTranslation ??
                                                                  "No translation available",
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                color: Colors
                                                                    .deepOrange,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontFamily:
                                                                    'OpenDyslexic',
                                                              ),
                                                            ),
                                                      const SizedBox(height: 8),
                                                      ElevatedButton.icon(
                                                        onPressed:
                                                            _tamilTranslation ==
                                                                    null ||
                                                                _tamilTranslation!
                                                                    .isEmpty
                                                            ? null
                                                            : _speakTamilTranslation,
                                                        icon: const Icon(
                                                          Icons.volume_up,
                                                        ),
                                                        label: const Text(
                                                          "Speak Tamil",
                                                        ),
                                                        style:
                                                            ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .deepOrange,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              if (_isAssessing) ...[
                                const Divider(),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withAlpha(25),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      const Text(
                                        '🎤 Reading Assessment Active',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Read the highlighted text aloud clearly',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: _finishAssessment,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Finish Assessment'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Navigation controls
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Reading Mode Controls
                        if (_isReading) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: _isListening
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isListening
                                    ? Colors.green
                                    : Colors.blue,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _isListening
                                      ? '🎤 Reading in progress... Take your time!'
                                      : '', // Removed popup: '📖 Ready to read? Tap microphone to start',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isListening
                                        ? Colors.green
                                        : Colors.blue,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                                if (_recognizedText.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'You said: "$_recognizedText"',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                if (_lastAccuracyScore > 0) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Accuracy: ${(_lastAccuracyScore * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: _lastAccuracyScore >= 0.75
                                          ? Colors.green
                                          : Colors.orange,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    // Circular Progress Indicator for reading progress
                                    if (_isReading) ...[
                                      Container(
                                        width: 60,
                                        height: 60,
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              value: _isListening
                                                  ? _currentReadingProgress
                                                  : _lastAccuracyScore,
                                              strokeWidth: 6,
                                              backgroundColor: Colors.grey[300],
                                              valueColor: AlwaysStoppedAnimation<Color>(
                                                _isListening
                                                    ? (_currentReadingProgress >=
                                                              0.75
                                                          ? Colors.green
                                                          : _currentReadingProgress >=
                                                                0.5
                                                          ? Colors.orange
                                                          : Colors.blue)
                                                    : (_lastAccuracyScore >=
                                                              0.75
                                                          ? Colors.green
                                                          : _lastAccuracyScore >=
                                                                0.5
                                                          ? Colors.orange
                                                          : Colors.red),
                                              ),
                                            ),
                                            Text(
                                              _isListening
                                                  ? '${(_currentReadingProgress * 100).toInt()}%'
                                                  : '${(_lastAccuracyScore * 100).toInt()}%',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _isListening
                                                    ? (_currentReadingProgress >=
                                                              0.75
                                                          ? Colors.green
                                                          : _currentReadingProgress >=
                                                                0.5
                                                          ? Colors.orange
                                                          : Colors.blue)
                                                    : (_lastAccuracyScore >=
                                                              0.75
                                                          ? Colors.green
                                                          : _lastAccuracyScore >=
                                                                0.5
                                                          ? Colors.orange
                                                          : Colors.red),
                                                fontFamily: 'OpenDyslexic',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ] else ...[
                                      // Placeholder to maintain layout when no score yet
                                      SizedBox(width: 60),
                                    ],
                                    ElevatedButton.icon(
                                      onPressed: _startListeningForReading,
                                      icon: Icon(
                                        _isListening ? Icons.stop : Icons.mic,
                                      ),
                                      label: Text(
                                        _isListening
                                            ? 'Stop Reading'
                                            : 'Start Reading',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isListening
                                            ? Colors.red
                                            : Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _isReading = false;
                                          _readingAttempts = 0;
                                        });
                                        _stopListening();
                                      },
                                      icon: const Icon(Icons.close),
                                      label: const Text('Cancel'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Main Navigation Controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Previous Button
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: _currentPageIndex > 0
                                    ? _previousPage
                                    : null,
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: Text(
                                  'Previous',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentPageIndex > 0
                                      ? Colors.deepPurple.withAlpha(230)
                                      : Colors.grey.withAlpha(230),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Listen Button
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: _speakCurrentSentence,
                                icon: const Icon(Icons.volume_up, size: 18),
                                label: const Text(
                                  'Listen',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Listen word by word Button
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _wordByWordMode = !_wordByWordMode;
                                    _activeWordIndex = null;
                                  });
                                  // Stop any current TTS playback
                                  LocalTtsService.instance.stop();
                                },
                                icon: Icon(
                                  Icons.segment,
                                  size: 18,
                                  color: _wordByWordMode
                                      ? Colors.white
                                      : Colors.blue,
                                ),
                                label: Text(
                                  _wordByWordMode
                                      ? 'Word Mode On'
                                      : 'Word by Word',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _wordByWordMode
                                      ? Colors.blue
                                      : Colors.white,
                                  foregroundColor: _wordByWordMode
                                      ? Colors.white
                                      : Colors.blue,
                                  side: BorderSide(
                                    color: Colors.blue,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Read Button (NEW!)
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: _isReading
                                    ? null
                                    : () async {
                                        // Stop any word-by-word playback and exit mode
                                        setState(() {
                                          _wordByWordMode = false;
                                          _activeWordIndex = null;
                                        });
                                        await LocalTtsService.instance.stop();
                                        // Add a short delay to ensure audio resource is released
                                        await Future.delayed(
                                          const Duration(milliseconds: 300),
                                        );
                                        _startReadingMode();
                                      },
                                icon: const Icon(
                                  Icons.record_voice_over,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Read',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isReading
                                      ? Colors.grey.withAlpha(230)
                                      : Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // Next Button
                            Flexible(
                              child: ElevatedButton.icon(
                                onPressed: _currentPageIndex < _pages.length - 1
                                    ? _nextPage
                                    : null,
                                icon: const Icon(Icons.arrow_forward, size: 18),
                                label: Text(
                                  'Next',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _currentPageIndex < _pages.length - 1
                                      ? Colors.deepPurple.withAlpha(230)
                                      : Colors.grey.withAlpha(230),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Page indicator
                        const SizedBox(height: 8),
                        Text(
                          'Page ${_currentPageIndex + 1} of ${_pages.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontFamily: 'OpenDyslexic',
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
  }
}
