import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models/word_list.dart';
import '../models/word_attempt.dart';
import '../services/word_attempt_service.dart';
import '../services/spaced_repetition_service.dart';
import '../services/gamification_service.dart';
import '../services/local_tts_service.dart';
import '../widgets/gamification_widgets.dart';
import '../utils/practice_time_tracker.dart';

class PracticeScreen extends StatefulWidget {
  final WordList wordList;
  final String mode; // 'auditory' or 'visual'

  const PracticeScreen({super.key, required this.wordList, required this.mode});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late LocalTtsService _ttsService;
  late SpeechToText _speechToText;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  PracticeTimeTracker? _practiceTimeTracker;

  int _currentWordIndex = 0;
  String _currentWord = '';
  String _userInput = '';
  bool _isListening = false;
  bool _showResult = false;
  String _resultMessage = '';
  Color _resultColor = Colors.green;

  // Practice session results tracking
  final List<Map<String, dynamic>> _practiceResults = [];

  // Gamification tracking
  int _coinsEarned = 0;
  final List<String> _achievementsUnlocked = [];
  final List<Widget> _rewardNotifications = [];
  late GlobalKey<State> _gamificationHeaderKey;

  // Visual mode variables
  Timer? _visualWordTimer;
  Timer? _autoRecordTimer;
  Timer? _countdownTimer;

  // Auditory mode variables
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _gamificationHeaderKey = GlobalKey<State>();

    // Initialize and start PracticeTimeTracker
    final userLocalId =
        'local_user'; // Replace with actual user ID if available
    final today = DateTime.now().toIso8601String().split('T')[0];
    _practiceTimeTracker = PracticeTimeTracker(
      userLocalId: userLocalId,
      date: today,
    );
    _practiceTimeTracker!.start();

    _initializeTTS();
    _initializeSpeechToText();
    _setupAnimations();
    _startPractice();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  void _initializeTTS() async {
    _ttsService = LocalTtsService.instance;
    await _ttsService.init();

    // Check if Flask service is available
    final isAvailable = await _ttsService.isFlaskServiceAvailable();
    if (!isAvailable) {
      debugPrint(
        'Warning: TTS Flask service is not available at 127.0.0.1:8080',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'TTS service unavailable. Please start the TTS Flask server.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _initializeSpeechToText() {
    _speechToText = SpeechToText();
  }

  void _startPractice() {
    if (widget.wordList.words.isNotEmpty) {
      _currentWord = widget.wordList.words[_currentWordIndex];

      if (widget.mode == 'auditory') {
        _speakWord(_currentWord);
        // Clear text input for auditory mode
        _textController.clear();
      } else if (widget.mode == 'visual') {
        _startVisualWordDisplay();
        // Visual mode now waits for user to press mic button
      }
    }
  }

  void _startVisualWordDisplay() {
    // Visual mode now uses audio input, no auto-advance timer needed
    // Words stay visible until user interacts
  }

  void _startListeningWithTimeout() async {
    // Cancel any existing timers
    _autoRecordTimer?.cancel();
    _countdownTimer?.cancel();

    if (!_isListening) {
      bool available = await _speechToText.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _userInput = ''; // Clear previous input
        });

        // Start 7-second timer for each word
        _countdownTimer = Timer(const Duration(seconds: 7), () {
          // Time's up - stop listening automatically
          if (_isListening && mounted) {
            _stopListening();
          }
        });

        _speechToText.listen(
          onResult: (result) {
            setState(() {
              _userInput = result.recognizedWords.toLowerCase();
            });

            // Auto-stop when speech is final (user finished speaking)
            if (result.finalResult && _userInput.trim().isNotEmpty) {
              _stopListening();
              // Auto-submit after a short delay to show what was heard
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted) {
                  _checkAnswer();
                }
              });
            }
          },
          onSoundLevelChange: (level) {
            // Handle sound level changes if needed
          },
          listenOptions: SpeechListenOptions(
            partialResults: true, // Show partial results while speaking
          ),
        );
      }
    }
  }

  void _speakWord(String word) async {
    try {
      await _ttsService.speakChildFriendly(word);
    } catch (e) {
      debugPrint('Error speaking word "$word": $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio for "$word"'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _stopListening() {
    if (_isListening) {
      _speechToText.stop();
      _countdownTimer?.cancel();
      setState(() {
        _isListening = false;
      });
    }
  }

  void _checkAnswer() async {
    String userAnswer;

    // Get user input based on mode
    if (widget.mode == 'visual') {
      userAnswer = _userInput.toLowerCase().trim();
    } else {
      userAnswer = _textController.text.toLowerCase().trim();
    }

    // Handle empty input - mark as missed attempt
    bool isCorrect = false;
    String resultType = 'incorrect';

    if (userAnswer.isEmpty) {
      resultType = 'missed';
      userAnswer = '(no response)';
    } else {
      String correctAnswer = _currentWord.toLowerCase().trim();
      isCorrect = _fuzzyMatch(correctAnswer, userAnswer);
      resultType = isCorrect ? 'correct' : 'incorrect';
    }

    // Record the attempt - now includes missed attempts
    await _recordAttempt(userAnswer, isCorrect, resultType);

    // If correct in visual mode, move to next word immediately
    if (widget.mode == 'visual' && isCorrect) {
      _nextWord();
      return;
    }

    setState(() {
      _showResult = true;
      if (userAnswer == '(no response)') {
        _resultMessage = 'No response detected. Try again!';
        _resultColor = Colors.orange;
      } else {
        _resultMessage = isCorrect ? 'Correct! Well done!' : 'Try again!';
        _resultColor = isCorrect ? Colors.green : Colors.red;
      }
    });

    // Play animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Show result longer for visual mode, auto-advance after showing result
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _nextWord();
      }
    });
  }

  Future<void> _recordAttempt(
    String userAnswer,
    bool isCorrect,
    String resultType,
  ) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_student';

    // ✅ INITIALIZE REVIEW PLAN FIRST (if this is the first practice)
    final existingPlan = await SpacedRepetitionService.getWordReviewPlan(
      userId,
      _currentWord,
    );
    if (existingPlan == null) {
      await SpacedRepetitionService.initializeWordReviewPlan(
        userId,
        _currentWord,
        today,
      );
    }

    // ✅ NOW get the repetition step (after review dates are created)
    final repetitionStep =
        await SpacedRepetitionService.getRepetitionStepForDate(
          userId,
          _currentWord,
          today,
        );

    final attempt = WordAttempt(
      userId: userId,
      word: _currentWord,
      date: today,
      result: resultType, // Use the passed result type instead of calculating
      type: widget.mode,
      repetitionStep: repetitionStep, // ✅ Use the calculated step
      subject: widget.wordList.subject,
      listName: widget.wordList.listName,
      heardOrTyped: userAnswer,
    );

    // Debug logging
    debugPrint('DEBUG: Recording attempt for word: $_currentWord');
    debugPrint('DEBUG: Repetition Step: $repetitionStep');
    debugPrint('DEBUG: Mode: ${widget.mode}');
    debugPrint('DEBUG: User answer: $userAnswer');
    debugPrint('DEBUG: Is correct: $isCorrect');
    debugPrint('DEBUG: Result type: $resultType');
    debugPrint('DEBUG: Subject: ${widget.wordList.subject}');
    debugPrint('DEBUG: List: ${widget.wordList.listName}');

    // Store result for practice summary
    _practiceResults.add({
      'word': _currentWord,
      'heard': userAnswer,
      'result': resultType,
      'isCorrect': isCorrect,
    });

    await WordAttemptService.saveAttempt(attempt);

    // Log the attempt (only first attempt on this date is recorded)
    await SpacedRepetitionService.logWordAttempt(
      userId,
      _currentWord,
      today,
      isCorrect ? 'correct' : 'incorrect',
      userAnswer,
    );

    // Process gamification rewards for correct answers
    if (isCorrect) {
      await _processGamificationReward();
    }

    debugPrint('DEBUG: Attempt saved successfully');
  }

  Future<void> _processGamificationReward() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Update practice statistics and get newly unlocked achievements
      final newAchievements = await GamificationService.updatePracticeStats(
        userId: userId,
        isCorrect: true,
        totalQuestions: 1,
        correctAnswers: 1,
      );

      // Show coin reward notification (coins are awarded automatically by updatePracticeStats)
      const coinsPerCorrect = 5;
      setState(() {
        _coinsEarned += coinsPerCorrect;
      });
      _showRewardNotification(coinsPerCorrect, 'Correct!');

      // Refresh gamification header to show updated coins
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          try {
            final headerState = _gamificationHeaderKey.currentState as dynamic;
            if (headerState != null && headerState.refresh is Function) {
              headerState.refresh();
            }
          } catch (e) {
            debugPrint('Error refreshing gamification header: $e');
          }
        }
      });

      // Show achievement notifications for newly unlocked achievements
      for (final achievement in newAchievements) {
        setState(() {
          _achievementsUnlocked.add(achievement.name);
        });
        _showAchievementNotification(
          achievement.name,
          achievement.description,
          achievement.rewardAmount,
        );
      }
    } catch (e) {
      debugPrint('Error processing gamification reward: $e');
    }
  }

  void _showRewardNotification(int coins, String message) {
    final notification = RewardNotification(
      coins: coins,
      message: message,
      onComplete: () {
        setState(() {
          _rewardNotifications.removeAt(0);
        });
      },
    );

    setState(() {
      _rewardNotifications.add(notification);
    });
  }

  void _showAchievementNotification(
    String name,
    String description,
    int coinReward,
  ) {
    final notification = AchievementNotification(
      achievementName: name,
      description: description,
      coinReward: coinReward,
      onComplete: () {
        setState(() {
          _rewardNotifications.removeAt(0);
        });
      },
    );

    setState(() {
      _rewardNotifications.add(notification);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _practiceTimeTracker?.didChangeAppLifecycleState(state);
  }

  void _nextWord() {
    setState(() {
      _showResult = false;
      _userInput = '';
    });

    // Cancel any existing timers
    _visualWordTimer?.cancel();
    _autoRecordTimer?.cancel();
    _countdownTimer?.cancel();

    if (_currentWordIndex < widget.wordList.words.length - 1) {
      _currentWordIndex++;
      _currentWord = widget.wordList.words[_currentWordIndex];

      if (widget.mode == 'auditory') {
        _speakWord(_currentWord);
        // Clear text input for auditory mode
        _textController.clear();
      } else if (widget.mode == 'visual') {
        _startVisualWordDisplay();
        // Visual mode now waits for user to press mic button
      }
    } else {
      // Practice session complete
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    // Calculate summary statistics
    int correctCount = _practiceResults
        .where((result) => result['isCorrect'] == true)
        .length;
    int incorrectCount = _practiceResults
        .where((result) => result['result'] == 'incorrect')
        .length;
    int missedCount = _practiceResults
        .where((result) => result['result'] == 'missed')
        .length;
    int totalWords = _practiceResults.length;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent tapping outside/behind the dialog
      builder: (context) => WillPopScope(
        // Block system back; only dialog buttons close it
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Text(
            'Practice Complete!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary stats
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Summary',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatChip('Correct', correctCount, Colors.green),
                          _buildStatChip('Wrong', incorrectCount, Colors.red),
                          _buildStatChip('Missed', missedCount, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Score: $correctCount/$totalWords (${((correctCount / totalWords) * 100).round()}%)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Gamification rewards summary
                if (_coinsEarned > 0 || _achievementsUnlocked.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Rewards Earned',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_coinsEarned > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.monetization_on,
                                color: Colors.amber.shade700,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+$_coinsEarned coins',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade800,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (_achievementsUnlocked.isNotEmpty) ...[
                          const Text(
                            'New Achievements:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.deepPurple,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...(_achievementsUnlocked
                              .map(
                                (name) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.emoji_events,
                                        color: Colors.amber.shade700,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.deepPurple,
                                            fontFamily: 'OpenDyslexic',
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList()),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Detailed results
                const Text(
                  'Details:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                const SizedBox(height: 8),

                // Results list
                SizedBox(
                  height: 200, // Fixed height for scrollable area
                  child: ListView.builder(
                    itemCount: _practiceResults.length,
                    itemBuilder: (context, index) {
                      final result = _practiceResults[index];
                      Color resultColor;
                      IconData resultIcon;

                      switch (result['result']) {
                        case 'correct':
                          resultColor = Colors.green;
                          resultIcon = Icons.check_circle;
                          break;
                        case 'incorrect':
                          resultColor = Colors.red;
                          resultIcon = Icons.cancel;
                          break;
                        case 'missed':
                          resultColor = Colors.orange;
                          resultIcon = Icons.access_time;
                          break;
                        default:
                          resultColor = Colors.grey;
                          resultIcon = Icons.help;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: resultColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: resultColor, width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(resultIcon, color: resultColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Word: ${result['word']}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                  Text(
                                    'You said: ${result['heard']}',
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontFamily: 'OpenDyslexic'),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentWordIndex = 0;
                  _practiceResults.clear(); // Clear previous results
                });
                _startPractice();
              },
              child: const Text(
                'Practice Again',
                style: TextStyle(fontSize: 16, fontFamily: 'OpenDyslexic'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _buildHeader(),
                  GamificationHeader(key: _gamificationHeaderKey),
                  _buildProgressIndicator(),
                  Expanded(child: _buildPracticeContent()),
                ],
              ),
              // Gamification notifications overlay
              if (_rewardNotifications.isNotEmpty)
                Positioned(
                  top: 100,
                  left: 0,
                  right: 0,
                  child: Center(child: _rewardNotifications.first),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${widget.wordList.listName} - ${widget.mode.toUpperCase()}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Text(
            'Word ${_currentWordIndex + 1} of ${widget.wordList.words.length}',
            style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentWordIndex + 1) / widget.wordList.words.length,
            backgroundColor: Colors.purple.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeContent() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.mode == 'visual')
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    // Full screen word display
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _scaleAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Text(
                                  _currentWord,
                                  style: const TextStyle(
                                    fontSize:
                                        64, // Reduced font size to prevent overflow
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    // User input display and microphone button
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          // Show what user said
                          if (_userInput.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                'You said: "$_userInput"',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  fontFamily: 'OpenDyslexic',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Microphone button
                          GestureDetector(
                            onTap: () {
                              if (_isListening) {
                                _stopListening();
                              } else {
                                _startListeningWithTimeout();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? Colors.red.withValues(alpha: 0.1)
                                    : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(
                                  color: _isListening
                                      ? Colors.red
                                      : Colors.green,
                                  width: 3,
                                ),
                              ),
                              child: Icon(
                                Icons.mic,
                                color: _isListening ? Colors.red : Colors.green,
                                size: 48,
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Status text
                          Text(
                            _isListening
                                ? 'Recording... Tap to stop'
                                : 'Tap mic to record',
                            style: TextStyle(
                              fontSize: 16,
                              color: _isListening ? Colors.red : Colors.green,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'OpenDyslexic',
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 16),

                          // Action buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Submit answer button (only show if user has spoken)
                              if (_userInput.isNotEmpty && !_isListening)
                                ElevatedButton.icon(
                                  onPressed: _checkAnswer,
                                  icon: const Icon(Icons.check, size: 20),
                                  label: const Text(
                                    'Submit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),

                              // Skip button
                              ElevatedButton.icon(
                                onPressed: _nextWord,
                                icon: const Icon(Icons.arrow_forward, size: 20),
                                label: const Text(
                                  'Skip',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontFamily: 'OpenDyslexic',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
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
              ),
            ),

          if (widget.mode == 'auditory')
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.headphones,
                    size: 120,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _speakWord(_currentWord),
                    icon: const Icon(Icons.volume_up, size: 28),
                    label: const Text(
                      'Play Word',
                      style: TextStyle(
                        fontSize: 18, // Reduced from 20
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28, // Reduced from 32
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Text input section for auditory mode
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Type what you heard:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                            fontFamily: 'OpenDyslexic',
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _textController,
                          style: const TextStyle(
                            fontSize: 24,
                            fontFamily: 'OpenDyslexic',
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Type here...',
                            hintStyle: TextStyle(
                              color: Colors.grey.withValues(alpha: 0.7),
                              fontFamily: 'OpenDyslexic',
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(color: Colors.blue),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onSubmitted: (value) {
                            if (value.trim().isNotEmpty) {
                              _checkAnswer();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit button for auditory mode
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_textController.text.trim().isNotEmpty) {
                        _checkAnswer();
                      }
                    },
                    icon: const Icon(Icons.check, size: 32),
                    label: const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          if (_showResult)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _resultColor, width: 2),
              ),
              child: Text(
                _resultMessage,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _resultColor,
                ),
              ),
            )
          else
            _buildInputSection(),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    // Both modes now use speech recognition, so return empty
    return const SizedBox.shrink();
  }

  // Fuzzy matching functions for better auditory recognition
  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;
    List<List<int>> d = List.generate(
      s.length + 1,
      (_) => List.filled(t.length + 1, 0),
    );
    for (int i = 0; i <= s.length; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= t.length; j++) {
      d[0][j] = j;
    }
    for (int i = 1; i <= s.length; i++) {
      for (int j = 1; j <= t.length; j++) {
        int cost = s[i - 1] == t[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }
    return d[s.length][t.length];
  }

  bool _fuzzyMatch(String expected, String actual) {
    expected = expected.trim().toLowerCase();
    actual = actual.trim().toLowerCase();

    // Exact match
    if (expected == actual) return true;

    // Check if actual contains expected word
    if (actual.contains(expected)) return true;

    // Allow one character difference (Levenshtein distance <= 1)
    if (_levenshtein(expected, actual) <= 1) return true;

    // Split recognized text by spaces and check each word for fuzzy match
    // This handles cases where speech recognition picks up multiple words
    final words = actual.split(RegExp(r'\s+'));
    for (final word in words) {
      if (word.trim().isNotEmpty) {
        if (_levenshtein(expected, word.trim()) <= 1) return true;
      }
    }

    // Check phonetic similarity for common misheard words
    if (_isPhoneticMatch(expected, actual)) return true;

    return false;
  }

  bool _isPhoneticMatch(String expected, String actual) {
    // Common phonetic substitutions for speech recognition
    final phoneticPairs = {
      'b': ['p', 'd'],
      'p': ['b'],
      'd': ['t', 'b'],
      't': ['d'],
      'c': ['k', 's'],
      'k': ['c'],
      's': ['z', 'c'],
      'z': ['s'],
      'f': ['v'],
      'v': ['f'],
      'th': ['f', 's'],
      'sh': ['s'],
      'ch': ['sh'],
    };

    // Check if words differ only by phonetic substitutions
    if (expected.length == actual.length) {
      int differences = 0;
      for (int i = 0; i < expected.length; i++) {
        if (expected[i] != actual[i]) {
          differences++;
          String expectedChar = expected[i];
          String actualChar = actual[i];

          // Check if this is a valid phonetic substitution
          bool isPhoneticSub =
              phoneticPairs[expectedChar]?.contains(actualChar) ?? false;
          if (!isPhoneticSub && differences > 1) {
            return false;
          }
        }
      }
      return differences <= 2; // Allow up to 2 phonetic substitutions
    }

    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visualWordTimer?.cancel();
    _autoRecordTimer?.cancel();
    _countdownTimer?.cancel();
    _textController.dispose();
    _animationController.dispose();
    _ttsService.stop();
    _speechToText.stop();
    // Save tracked time before stopping
    _practiceTimeTracker?.stop();
    super.dispose();
  }
}
