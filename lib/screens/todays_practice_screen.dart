import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/spaced_repetition_service.dart';
import '../services/word_attempt_service.dart';
import '../services/word_list_service.dart';
import '../models/word_list.dart';
import '../models/word_schedule.dart';
import '../navigation/app_routes.dart';
import '../widgets/gamification_widgets.dart';
import '../utils/logger.dart';

class TodaysPracticeScreen extends StatefulWidget {
  const TodaysPracticeScreen({super.key});

  @override
  State<TodaysPracticeScreen> createState() => _TodaysPracticeScreenState();
}

class _TodaysPracticeScreenState extends State<TodaysPracticeScreen> {
  List<String> _todaysWords = [];
  List<String> _availableSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodaysWords();
    _loadAvailableSubjects();
  }

  Future<void> _loadTodaysWords() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = DateTime.now().toIso8601String().split('T')[0];
      final schedules = await SpacedRepetitionService.getWordsForReview(
        user.uid,
        today,
      );

      setState(() {
        _todaysWords = schedules.map((schedule) => schedule.word).toList();
        _isLoading = false;
      });
    } catch (e) {
      logDebug('Error loading today\'s words: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAvailableSubjects() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final subjects = await WordListService.getAvailableSubjects(user.uid);
      setState(() {
        _availableSubjects = subjects;
      });
    } catch (e) {
      logDebug('Error loading subjects: $e');
    }
  }

  void _startPractice(String mode) {
    if (_todaysWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No words scheduled for today! Check back tomorrow.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Create a temporary word list with today's words
    final user = FirebaseAuth.instance.currentUser;
    final todaysWordList = WordList(
      id: 'todays_practice_${DateTime.now().millisecondsSinceEpoch}',
      userId: user?.uid ?? '',
      subject: 'Today\'s Review',
      listName: 'Scheduled Words',
      words: _todaysWords,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Navigate to practice screen
    NavigationHelper.navigateToPractice(context, todaysWordList, mode);
  }

  void _showSubjectSelection(String mode) {
    if (_availableSubjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects available for practice!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    mode == 'visual' ? Icons.visibility : Icons.hearing,
                    size: 28,
                    color: mode == 'visual' ? Colors.green : Colors.purple,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select Subject for ${mode == 'visual' ? 'Visual' : 'Auditory'} Practice',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Subject list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _availableSubjects.length,
                itemBuilder: (context, index) {
                  final subject = _availableSubjects[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton(
                      onPressed: () => _startSubjectPractice(subject, mode),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getSubjectColor(subject),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(_getSubjectIcon(subject), size: 24),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              subject,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startSubjectPractice(String subject, String mode) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    navigator.pop(); // Close bottom sheet

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('User not logged in'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get all word lists for the selected subject
      final wordLists = await WordListService.getWordListsBySubject(
        user.uid,
        subject,
      );

      if (wordLists.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('No word lists found for $subject'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Combine all words from all word lists of this subject
      final allWords = <String>[];
      for (final wordList in wordLists) {
        allWords.addAll(wordList.words);
      }

      if (allWords.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('No words found for $subject'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create a combined word list for practice
      final practiceWordList = WordList(
        id: '${subject.toLowerCase()}_practice_${DateTime.now().millisecondsSinceEpoch}',
        userId: user.uid,
        subject: subject,
        listName: '$subject Practice',
        words: allWords,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Navigate to practice screen
      if (mounted) {
        NavigationHelper.navigateToPractice(context, practiceWordList, mode);
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error loading $subject words: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'english':
        return Colors.blue;
      case 'math':
        return Colors.green;
      case 'science':
        return Colors.purple;
      case 'social':
      case 'geography':
        return Colors.teal;
      case 'history':
        return Colors.orange;
      case 'art':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'english':
        return Icons.library_books;
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'social':
      case 'geography':
        return Icons.public;
      case 'history':
        return Icons.history_edu;
      case 'art':
        return Icons.palette;
      default:
        return Icons.subject;
    }
  }

  Future<void> _showCalendarView() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildCalendarBottomSheet(),
    );
  }

  Widget _buildCalendarBottomSheet() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_month, size: 28, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Review Calendar',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Calendar widget
          Expanded(child: _buildCalendarWidget()),
        ],
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return FutureBuilder<Map<String, List<WordSchedule>>>(
      future: _loadCalendarData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Error loading calendar data',
                  style: TextStyle(fontSize: 16, color: Colors.red.shade600),
                ),
              ],
            ),
          );
        }

        final calendarData = snapshot.data ?? {};
        return _buildCalendarGrid(calendarData);
      },
    );
  }

  Widget _buildCalendarGrid(Map<String, List<WordSchedule>> calendarData) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDayOfMonth = DateTime(today.year, today.month, 1);
    final startDate = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    return Column(
      children: [
        // Month/Year header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_getMonthName(today.month)} ${today.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
            ],
          ),
        ),
        // Weekday headers
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        // Calendar grid
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: 42, // 6 weeks × 7 days
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final dateKey = date.toIso8601String().split('T')[0];
                final hasReviews =
                    calendarData.containsKey(dateKey) &&
                    calendarData[dateKey]!.isNotEmpty;
                final isToday =
                    date.day == today.day &&
                    date.month == today.month &&
                    date.year == today.year;
                final isCurrentMonth = date.month == today.month;

                return GestureDetector(
                  onTap: hasReviews
                      ? () => _showDateDetails(date, calendarData[dateKey]!)
                      : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _getDateColor(isToday, hasReviews, isCurrentMonth),
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: Colors.deepPurple, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _getDateTextColor(
                              isToday,
                              hasReviews,
                              isCurrentMonth,
                            ),
                          ),
                        ),
                        if (hasReviews) ...[
                          const SizedBox(height: 2),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.deepPurple,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Legend
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.deepPurple.shade50, 'Review days'),
              const SizedBox(width: 20),
              _buildLegendItem(Colors.deepPurple, 'Today', isToday: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isToday = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: isToday
                ? Border.all(color: Colors.deepPurple, width: 2)
                : null,
          ),
          child: isToday
              ? Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Colors.deepPurple,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Color _getDateColor(bool isToday, bool hasReviews, bool isCurrentMonth) {
    if (!isCurrentMonth) return Colors.transparent;
    if (isToday) return Colors.deepPurple.shade100;
    if (hasReviews) return Colors.deepPurple.shade50;
    return Colors.transparent;
  }

  Color _getDateTextColor(bool isToday, bool hasReviews, bool isCurrentMonth) {
    if (!isCurrentMonth) return Colors.grey.shade300;
    if (isToday) return Colors.deepPurple.shade800;
    if (hasReviews) return Colors.deepPurple.shade600;
    return Colors.black87;
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  Future<Map<String, List<WordSchedule>>> _loadCalendarData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};

      final allSchedules = await SpacedRepetitionService.getAllSchedules(
        user.uid,
      );
      final Map<String, List<WordSchedule>> calendarData = {};

      for (final schedule in allSchedules) {
        final dateKey = schedule.nextReviewDate;
        if (!calendarData.containsKey(dateKey)) {
          calendarData[dateKey] = [];
        }
        calendarData[dateKey]!.add(schedule);
      }

      return calendarData;
    } catch (e) {
      logDebug('Error loading calendar data: $e');
      return {};
    }
  }

  Future<Map<String, List<WordSchedule>>> _showDateDetails(
    DateTime date,
    List<WordSchedule> schedules,
  ) async {
    // Group schedules by subject
    final Map<String, List<WordSchedule>> subjectSchedules = {};

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return subjectSchedules;

    for (final schedule in schedules) {
      // Get the subject for this word by finding it in word lists
      final wordLists = await WordListService.getAllWordLists(user.uid);
      String? wordSubject;

      for (final wordList in wordLists) {
        if (wordList.words.contains(schedule.word)) {
          wordSubject = wordList.subject;
          break;
        }
      }

      if (wordSubject != null) {
        if (!subjectSchedules.containsKey(wordSubject)) {
          subjectSchedules[wordSubject] = [];
        }
        subjectSchedules[wordSubject]!.add(schedule);
      }
    }

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            _buildDateDetailsBottomSheet(date, subjectSchedules),
      );
    }

    return subjectSchedules;
  }

  Widget _buildDateDetailsBottomSheet(
    DateTime date,
    Map<String, List<WordSchedule>> subjectSchedules,
  ) {
    final dateStr = '${date.day} ${_getMonthName(date.month)} ${date.year}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 50,
            height: 5,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 28, color: Colors.deepPurple),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reviews for',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          // Subject list
          Expanded(
            child: subjectSchedules.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No reviews scheduled',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: subjectSchedules.length,
                    itemBuilder: (context, index) {
                      final subject = subjectSchedules.keys.elementAt(index);
                      final schedules = subjectSchedules[subject]!;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _getSubjectColor(subject),
                            child: Icon(
                              _getSubjectIcon(subject),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            subject,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${schedules.length} word${schedules.length == 1 ? '' : 's'}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: schedules
                                    .map(
                                      (schedule) => Chip(
                                        label: Text(
                                          schedule.word,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        backgroundColor: _getSubjectColor(
                                          subject,
                                        ).withValues(alpha: 0.2),
                                        side: BorderSide(
                                          color: _getSubjectColor(subject),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                            // Practice button for this subject
                            Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _startSubjectPracticeFromCalendar(
                                            subject,
                                            schedules,
                                            'visual',
                                          ),
                                      icon: const Icon(
                                        Icons.visibility,
                                        size: 18,
                                      ),
                                      label: const Text('Visual Practice'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () =>
                                          _startSubjectPracticeFromCalendar(
                                            subject,
                                            schedules,
                                            'auditory',
                                          ),
                                      icon: const Icon(Icons.hearing, size: 18),
                                      label: const Text('Auditory Practice'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
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
    );
  }

  Future<void> _startSubjectPracticeFromCalendar(
    String subject,
    List<WordSchedule> schedules,
    String mode,
  ) async {
    Navigator.pop(context); // Close date details
    Navigator.pop(context); // Close calendar

    try {
      // Create a word list from the scheduled words
      final words = schedules.map((schedule) => schedule.word).toList();

      if (words.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No words found for practice'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create a temporary word list for practice
      final user = FirebaseAuth.instance.currentUser;
      final practiceWordList = WordList(
        id: '${subject.toLowerCase()}_calendar_practice_${DateTime.now().millisecondsSinceEpoch}',
        userId: user?.uid ?? '',
        subject: subject,
        listName: '$subject Calendar Review',
        words: words,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Navigate to practice screen
      if (mounted) {
        NavigationHelper.navigateToPractice(context, practiceWordList, mode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting practice: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
        ),
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.today, size: 32, color: Colors.deepPurple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Today\'s Practice',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _showCalendarView,
                          icon: Icon(
                            Icons.calendar_month,
                            size: 28,
                            color: Colors.deepPurple,
                          ),
                          tooltip: 'Review Calendar',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.7,
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Gamification Header
                    const GamificationHeader(),

                    const SizedBox(height: 24),

                    // Words summary
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blue, width: 2),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.assignment, size: 48, color: Colors.blue),
                          const SizedBox(height: 12),
                          Text(
                            '${_todaysWords.length}',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                          Text(
                            _todaysWords.length == 1
                                ? 'Word to Review'
                                : 'Words to Review',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.blue,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Practice mode selection
                    if (_todaysWords.isNotEmpty) ...[
                      Text(
                        'Today\'s Scheduled Review:',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Visual Practice Button for Today's Words
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton(
                          onPressed: () => _startPractice('visual'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.visibility, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Visual Review',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Review today\'s scheduled words',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),

                      // Auditory Practice Button for Today's Words
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 24),
                        child: ElevatedButton(
                          onPressed: () => _startPractice('auditory'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 5,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.hearing, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Auditory Review',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Review today\'s scheduled words',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'OpenDyslexic',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ],

                    if (_todaysWords.isEmpty) ...[
                      // No words message
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'All Caught Up!',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No words are scheduled for review today. Great job staying on top of your studies!',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.orange,
                                fontFamily: 'OpenDyslexic',
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'You can practice more by going to the Home tab and selecting a subject.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                                fontFamily: 'OpenDyslexic',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Today's words preview (if any)
                    if (_todaysWords.isNotEmpty) ...[
                      Text(
                        'Words to Review Today:',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey, width: 1),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _todaysWords.map((word) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.deepPurple,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                word,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.deepPurple,
                                  fontFamily: 'OpenDyslexic',
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
