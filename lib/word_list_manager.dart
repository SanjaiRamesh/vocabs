import 'package:flutter/material.dart';
import 'word_list.dart';

/// Combined widget that includes both the WordListManager UI and the SightWordDisplay.
class WordListAndSightWordDisplay extends StatefulWidget {
  const WordListAndSightWordDisplay({super.key});

  @override
  State<WordListAndSightWordDisplay> createState() =>
      _WordListAndSightWordDisplayState();
}

class _WordListAndSightWordDisplayState
    extends State<WordListAndSightWordDisplay> {
  final List<WordList> _wordLists = [
    WordList(
      subject: 'English',
      listName: 'V1',
      words: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how'],
    ),
    WordList(
      subject: 'Science',
      listName: 'Lesson1_Fillups',
      words: ['atom', 'cell', 'energy'],
    ),
  ];

  String? _selectedSubject;
  String? _selectedListName;
  List<String> _currentWords = [];

  @override
  Widget build(BuildContext context) {
    final subjects = _wordLists.map((wl) => wl.subject).toSet().toList();
    final listNames = _selectedSubject == null
        ? []
        : _wordLists
              .where((wl) => wl.subject == _selectedSubject)
              .map((wl) => wl.listName)
              .toList();

    return Column(
      children: [
        Card(
          color: Colors.yellow[50],
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Word List Manager',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),

                /// Subject dropdown
                DropdownButton<String>(
                  hint: const Text('Select Subject'),
                  value: _selectedSubject,
                  isExpanded: true,
                  items: subjects.isNotEmpty
                      ? subjects
                            .map(
                              (subject) => DropdownMenuItem<String>(
                                value: subject,
                                child: Text(subject),
                              ),
                            )
                            .toList()
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No subjects available'),
                          ),
                        ],
                  onChanged: subjects.isNotEmpty
                      ? (value) {
                          setState(() {
                            _selectedSubject = value;
                            _selectedListName = null;
                            _currentWords = [];
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 12),

                /// List Name dropdown
                DropdownButton<String>(
                  hint: const Text('Select List Name'),
                  value: _selectedListName,
                  isExpanded: true,
                  items: listNames.isNotEmpty
                      ? listNames
                            .map(
                              (listName) => DropdownMenuItem<String>(
                                value: listName,
                                child: Text(listName),
                              ),
                            )
                            .toList()
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No lists available'),
                          ),
                        ],
                  onChanged: listNames.isNotEmpty
                      ? (value) {
                          setState(() {
                            _selectedListName = value;
                            _currentWords = _wordLists
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
                        }
                      : null,
                ),
                const SizedBox(height: 16),

                /// Display current words
                if (_selectedListName != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Words in this list:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _currentWords
                            .map((word) => Chip(label: Text(word)))
                            .toList(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_selectedListName != null && _currentWords.isNotEmpty)
          Expanded(
            child: SightWordDisplay(
              words: _currentWords,
              studentId: 'student1',
            ),
          ),
      ],
    );
  }
}

/// Widget to display sight words for a student, advancing automatically.
class SightWordDisplay extends StatefulWidget {
  final List<String> words;
  final String studentId;

  const SightWordDisplay({
    super.key,
    required this.words,
    required this.studentId,
  });

  @override
  State<SightWordDisplay> createState() => _SightWordDisplayState();
}

class _SightWordDisplayState extends State<SightWordDisplay> {
  int _currentIndex = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    if (widget.words.isNotEmpty) {
      Future.delayed(const Duration(seconds: 2), _advance);
    }
  }

  void _advance() {
    if (!mounted) return;
    if (_currentIndex < widget.words.length - 1) {
      setState(() => _currentIndex++);
      Future.delayed(const Duration(seconds: 2), _advance);
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return const Center(
        child: Text(
          'Session Complete!',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      );
    }
    final word = widget.words[_currentIndex];
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue, width: 8),
          borderRadius: BorderRadius.circular(32),
          color: Colors.white,
        ),
        child: Text(
          word,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class WordListManager extends StatefulWidget {
  final void Function(List<WordList>)? onWordListsChanged;
  final VoidCallback? onSetHeaderTitle;
  const WordListManager({
    super.key,
    this.onWordListsChanged,
    this.onSetHeaderTitle,
  });
  @override
  State<WordListManager> createState() => _WordListManagerState();
}

class _WordListManagerState extends State<WordListManager> {
  final List<WordList> _wordLists = [
    WordList(
      subject: 'English',
      listName: 'V1',
      words: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how'],
    ),
    WordList(
      subject: 'Science',
      listName: 'Lesson1_Fillups',
      words: ['atom', 'cell', 'energy'],
    ),
  ];

  String? _selectedSubject;
  String? _selectedListName;
  List<String> _currentWords = [];
  final TextEditingController _wordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final subjects = _wordLists.map((wl) => wl.subject).toSet().toList();
    final listNames = _selectedSubject == null
        ? []
        : _wordLists
              .where((wl) => wl.subject == _selectedSubject)
              .map((wl) => wl.listName)
              .toList();

    return Column(
      children: [
        Card(
          color: Colors.yellow[50],
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.red, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Word List Manager',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 12),

                /// Subject dropdown
                DropdownButton<String>(
                  hint: const Text('Select Subject'),
                  value: _selectedSubject,
                  isExpanded: true,
                  items: subjects.isNotEmpty
                      ? subjects
                            .map(
                              (subject) => DropdownMenuItem<String>(
                                value: subject,
                                child: Text(subject),
                              ),
                            )
                            .toList()
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No subjects available'),
                          ),
                        ],
                  onChanged: subjects.isNotEmpty
                      ? (value) {
                          setState(() {
                            _selectedSubject = value;
                            _selectedListName = null;
                            _currentWords = [];
                          });
                        }
                      : null,
                ),
                const SizedBox(height: 12),

                /// List Name dropdown
                DropdownButton<String>(
                  hint: const Text('Select List Name'),
                  value: _selectedListName,
                  isExpanded: true,
                  items: listNames.isNotEmpty
                      ? listNames
                            .map(
                              (listName) => DropdownMenuItem<String>(
                                value: listName,
                                child: Text(listName),
                              ),
                            )
                            .toList()
                      : [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No lists available'),
                          ),
                        ],
                  onChanged: listNames.isNotEmpty
                      ? (value) {
                          setState(() {
                            _selectedListName = value;
                            _currentWords = _wordLists
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
                        }
                      : null,
                ),
                const SizedBox(height: 16),

                /// Display current words
                if (_selectedListName != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Words in this list:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _currentWords
                            .map((word) => Chip(label: Text(word)))
                            .toList(),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        if (_selectedListName != null && _currentWords.isNotEmpty)
          Expanded(
            child: SightWordDisplay(
              words: _currentWords,
              studentId: 'student1',
            ),
          ),
        // Add Word section
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _wordController,
                  decoration: const InputDecoration(
                    labelText: 'New Word',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final word = _wordController.text.trim();
                  if (word.isNotEmpty) {
                    setState(() {
                      final idx = _wordLists.indexWhere(
                        (wl) =>
                            wl.subject == _selectedSubject &&
                            wl.listName == _selectedListName,
                      );
                      if (idx != -1) {
                        _wordLists[idx].words.add(word);
                        _currentWords = List.from(_wordLists[idx].words);
                      }
                      _wordController.clear();
                      if (widget.onWordListsChanged != null) {
                        widget.onWordListsChanged!(_wordLists);
                      }
                    });
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
