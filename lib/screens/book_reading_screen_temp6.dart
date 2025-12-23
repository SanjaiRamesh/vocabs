import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../models/reading_assessment_result.dart';
import '../services/book_service.dart';
import '../services/assessment_result_service.dart';
import '../services/local_tts_service.dart';

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
  int _currentPageIndex = 0;
  int _currentSentenceIndex = 0;

  List<String> _pages = [];
  List<List<String>> _pagesSentences = []; // Store sentences per page

  bool _isLoading = true;
  bool _isAssessing = false;

  DateTime? _speechStartTime;
  DateTime? _speechEndTime;

  String _currentSpokenTranscript = '';

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

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

    _loadBookContent();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _slideController.dispose();
    super.dispose();
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
          final sentences = page
              .split(RegExp(r'[.!?]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          _pagesSentences.add(sentences); // Add sentences for this page
        }
      }

      if (_pages.isEmpty) {
        _pages = ['This book appears to be empty. Please add some content.'];
        _pagesSentences = [['This book appears to be empty']];
      }

      // Set starting position
      _currentPageIndex = widget.startingChapter.clamp(0, _pages.length - 1);
      _currentSentenceIndex = 0;

      setState(() {
        _isLoading = false;
      });

      // Start slide animation
      _slideController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _pages = ['Error loading book content: $e'];
        _pagesSentences = [['Error loading book']];
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
    final currentPageSentences = (_pagesSentences.isNotEmpty && _currentPageIndex < _pagesSentences.length) ? _pagesSentences[_currentPageIndex] : <String>[]; if (currentPageSentences.isNotEmpty && _currentSentenceIndex < currentPageSentences.length) {
      final sentence = currentPageSentences[_currentSentenceIndex];
      try {
        await LocalTtsService.instance.speak(sentence);
      } catch (e) {
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
    final currentPageSentences = (_pagesSentences.isNotEmpty && _currentPageIndex < _pagesSentences.length) ? _pagesSentences[_currentPageIndex] : <String>[]; if (currentPageSentences.isNotEmpty && _currentSentenceIndex < currentPageSentences.length) {
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
      final currentSentence = _sentences[_currentSentenceIndex];
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

  @override
  Widget build(BuildContext context) {
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
    final progress = _pages.isNotEmpty
        ? (_currentPageIndex + 1) / _pages.length
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
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
                  margin: const EdgeInsets.all(16),
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
                          Expanded(
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
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            color: Colors.blue.withAlpha(25),
                                          )
                                        : null,
                                    padding: _isAssessing
                                        ? const EdgeInsets.all(8)
                                        : null,
                                    child: Text(
                                      currentPage,
                                      style: TextStyle(
                                        fontSize: 20,
                                        height: 1.6,
                                        color: Colors.black87,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                      textAlign: TextAlign.left,
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _currentPageIndex > 0 ? _previousPage : null,
                      icon: const Icon(Icons.arrow_back),
                      label: Text(
                        'Previous (${_currentPageIndex + 1}/${_pages.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPageIndex > 0
                            ? Colors.deepPurple.withAlpha(230)
                            : Colors.grey.withAlpha(230),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: _speakCurrentSentence,
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Listen'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),

                    ElevatedButton.icon(
                      onPressed: _currentPageIndex < _pages.length - 1
                          ? _nextPage
                          : null,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        'Next (${_currentPageIndex + 1}/${_pages.length})',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPageIndex < _pages.length - 1
                            ? Colors.deepPurple.withAlpha(230)
                            : Colors.grey.withAlpha(230),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
