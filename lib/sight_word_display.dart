import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'word_list.dart';
import 'utils/logger.dart';

/// Widget for displaying sight words fullscreen, one at a time, for 5 seconds each.
/// SightWordDisplay now supports audio recording, assessment, and feedback per new instructions.
class SightWordDisplay extends StatefulWidget {
  /// List of words to display
  final List<String> words;
  final String studentId;
  final void Function(String word, bool correct, String audioPath)? onResult;
  const SightWordDisplay({
    super.key,
    required this.words,
    required this.studentId,
    this.onResult,
  });

  @override
  State<SightWordDisplay> createState() => _SightWordDisplayState();
}

class _SightWordDisplayState extends State<SightWordDisplay> {
  int _currentIndex = 0;
  bool _isRecording = false;
  bool _finished = false;
  late final SpeechToText _speechToText;
  bool _speechAvailable = false;
  String? _transcription;
  final List<Map<String, dynamic>> _results = [];
  String? _error;
  bool _waitingForUserAction = false;
  bool _skipRequested = false;
  bool _retryRequested = false;

  @override
  void initState() {
    super.initState();
    _speechToText = SpeechToText();
    _initPermissionsAndSpeech();
    if (widget.words.isNotEmpty) {
      _showAndAssess();
    }
  }

  Future<void> _initPermissionsAndSpeech() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() {
        _error = 'Microphone permission denied.';
      });
      return;
    }
    try {
      _speechAvailable = await _speechToText.initialize(
        onError: (e) {
          setState(() {
            _error = 'Speech init error: \\${e.errorMsg}';
          });
        },
      );
      if (!_speechAvailable) {
        setState(() {
          _error = 'Speech recognition not available on this device.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Speech init exception: \\${e.toString()}';
      });
    }
    setState(() {});
  }

  Future<void> _showAndAssess() async {
    _results.clear();
    for (int i = 0; i < widget.words.length; i++) {
      setState(() {
        _currentIndex = i;
        _transcription = null;
        _waitingForUserAction = false;
        _skipRequested = false;
        _retryRequested = false;
      });
      await Future.delayed(const Duration(milliseconds: 500));
      String? recognized = await _listenAndTranscribe();
      bool handled = false;
      while ((recognized == null || recognized.isEmpty) &&
          mounted &&
          !handled) {
        setState(() {
          _waitingForUserAction = true;
        });
        // Wait for user action or timeout
        int waited = 0;
        while (!_skipRequested && !_retryRequested && waited < 3 && mounted) {
          await Future.delayed(const Duration(seconds: 1));
          waited++;
        }
        setState(() {
          _waitingForUserAction = false;
        });
        if (_retryRequested) {
          _retryRequested = false;
          recognized = await _listenAndTranscribe();
        } else {
          handled = true;
        }
      }
      setState(() {
        _transcription = recognized ?? '';
      });
      _results.add({
        'word': widget.words[i],
        'result': _fuzzyMatch(widget.words[i], recognized ?? '')
            ? 'Correct'
            : 'Wrong',
        'transcription': recognized ?? '',
      });
      widget.onResult?.call(
        widget.words[i],
        _fuzzyMatch(widget.words[i], recognized ?? ''),
        recognized ?? '',
      );
      await Future.delayed(const Duration(seconds: 1));
    }
    setState(() {
      _finished = true;
    });
  }

  // Levenshtein distance for fuzzy matching
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
    if (expected == actual) return true;
    if (actual.contains(expected)) return true;
    if (_levenshtein(expected, actual) <= 1) return true;
    // Try splitting recognized text and check each word
    for (final word in actual.split(RegExp(r'\s+'))) {
      if (_levenshtein(expected, word) <= 1) return true;
    }
    return false;
  }

  Future<String?> _listenAndTranscribe() async {
    if (!_speechAvailable) return null;
    String? resultText;
    setState(() {
      _isRecording = true;
    });
    try {
      await _speechToText.listen(
        onResult: (SpeechRecognitionResult result) {
          resultText = result.recognizedWords;
        },
        listenFor: const Duration(seconds: 3), // Reduced from 5 to 3 seconds
        localeId: null, // Use default locale for best compatibility
        listenOptions: SpeechListenOptions(
          cancelOnError: true,
          partialResults: false,
        ),
      );
      await Future.delayed(
        const Duration(seconds: 3),
      ); // Reduced from 5 to 3 seconds
      await _speechToText.stop();
    } catch (e) {
      setState(() {
        _error = 'Speech recognition error: \\${e.toString()}';
      });
    }
    setState(() {
      _isRecording = false;
    });
    logDebug(
      'Recognized: \${resultText ?? '
      '}',
    );
    return resultText;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Text(
          'Error: \\$_error',
          style: const TextStyle(color: Colors.red, fontSize: 18),
        ),
      );
    }
    if (widget.words.isEmpty) {
      return const Center(child: Text('No words to display'));
    }
    if (_finished) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Session Complete!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Results:',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DataTable(
                columns: const [
                  DataColumn(label: Text('Word')),
                  DataColumn(label: Text('Result')),
                  DataColumn(label: Text('Heard')),
                ],
                rows: _results
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text(r['word'])),
                          DataCell(Text(r['result'])),
                          DataCell(Text(r['transcription'])),
                        ],
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.home),
                label: const Text('Back to Home'),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }
    final word = widget.words[_currentIndex];
    // Removed unused borderColor variable.
    return Container(
      color: Colors.blue[50],
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: Container(
            key: ValueKey(word + (_transcription ?? '')),
            width: 400, // Fixed width for consistency
            height: 200, // Fixed height for consistency
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blue, width: 8), // Always blue
              borderRadius: BorderRadius.circular(32),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  word,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple, // Always same color
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Remove the decorative line bar and replace with subtle spacing or a Divider
                const SizedBox(height: 16),
                // Optionally, add a subtle Divider for separation
                // Divider(thickness: 1, color: Colors.grey[300]),
                if (_isRecording)
                  const Text(
                    'Listening... 🎤',
                    style: TextStyle(fontSize: 24, color: Colors.blue),
                  ),
                if (_transcription != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Heard: $_transcription',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                if (_waitingForUserAction)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _retryRequested = true;
                          });
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _skipRequested = true;
                          });
                        },
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying sight words with option to choose word list
class SightWordDisplayWithListPicker extends StatefulWidget {
  final List<WordList> wordLists;
  final String studentId;
  final void Function(String word, bool correct, String heard)? onResult;
  final VoidCallback? onSetHeaderTitle;
  const SightWordDisplayWithListPicker({
    super.key,
    required this.wordLists,
    required this.studentId,
    this.onResult,
    this.onSetHeaderTitle,
  });

  @override
  State<SightWordDisplayWithListPicker> createState() =>
      _SightWordDisplayWithListPickerState();
}

class _SightWordDisplayWithListPickerState
    extends State<SightWordDisplayWithListPicker> {
  String? _selectedSubject;
  String? _selectedListName;
  List<String> _currentWords = [];
  bool _startAssessment = false;

  @override
  Widget build(BuildContext context) {
    final subjects = widget.wordLists.map((wl) => wl.subject).toSet().toList();
    final listNames = _selectedSubject == null
        ? []
        : widget.wordLists
              .where((wl) => wl.subject == _selectedSubject)
              .map((wl) => wl.listName)
              .toList();
    return !_startAssessment
        ? Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose Subject and List to Assess',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    hint: const Text('Select Subject'),
                    value: _selectedSubject,
                    isExpanded: true,
                    items: subjects
                        .map(
                          (subject) => DropdownMenuItem<String>(
                            value: subject,
                            child: Text(subject),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubject = value;
                        _selectedListName = null;
                        _currentWords = [];
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    hint: const Text('Select List Name'),
                    value: _selectedListName,
                    isExpanded: true,
                    items: listNames
                        .map(
                          (listName) => DropdownMenuItem<String>(
                            value: listName,
                            child: Text(listName),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedListName = value;
                        _currentWords = widget.wordLists
                            .firstWhere(
                              (wl) =>
                                  wl.subject == _selectedSubject &&
                                  wl.listName == value,
                              orElse: () => WordList(
                                subject: '',
                                listName: '',
                                words: [],
                              ),
                            )
                            .words;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _currentWords.isNotEmpty
                        ? () => setState(() => _startAssessment = true)
                        : null,
                    child: const Text('Start Assessment'),
                  ),
                ],
              ),
            ),
          )
        : SightWordDisplay(
            words: _currentWords,
            studentId: widget.studentId,
            onResult: widget.onResult,
          );
  }
}
