import 'package:flutter/material.dart';
import '../models/word_attempt.dart';
import '../services/word_attempt_service.dart';
import '../services/word_list_service.dart';
import '../services/spaced_repetition_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen>
    with TickerProviderStateMixin {
  late TabController _subjectTabController;
  List<String> subjects = [];
  Map<String, List<String>> subjectWordLists = {};
  Map<String, List<WordAttempt>> allAttempts = {};
  bool isLoading = true;

  // Spaced repetition schedule
  final List<int> repetitionDays = [1, 2, 4, 8, 16, 30, 60, 150];

  @override
  void initState() {
    super.initState();
    _loadProgressData();
  }

  @override
  void dispose() {
    if (subjects.isNotEmpty) {
      _subjectTabController.dispose();
    }
    super.dispose();
  }

  Future<void> _loadProgressData() async {
    try {
      setState(() => isLoading = true);

      // Get all subjects
      final availableSubjects = await WordListService.getAvailableSubjects();

      // Get word lists for each subject
      final Map<String, List<String>> wordListsMap = {};
      for (String subject in availableSubjects) {
        final wordLists = await WordListService.getWordListsBySubject(subject);
        wordListsMap[subject] = wordLists
            .map((wl) => wl.listName)
            .toSet()
            .toList();
      }

      // Get all attempts
      final attempts = await WordAttemptService.getAllAttempts();
      final Map<String, List<WordAttempt>> attemptsMap = {};

      for (String subject in availableSubjects) {
        attemptsMap[subject] = attempts
            .where((attempt) => attempt.subject == subject)
            .toList();
      }

      if (mounted) {
        setState(() {
          subjects = availableSubjects;
          subjectWordLists = wordListsMap;
          allAttempts = attemptsMap;
          isLoading = false;
        });

        // Initialize tab controller after subjects are loaded
        if (subjects.isNotEmpty) {
          _subjectTabController = TabController(
            length: subjects.length,
            vsync: this,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading progress data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text(
          'Progress Tracker',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF6B73FF),
        elevation: 0,
        actions: [],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B73FF)),
              ),
            )
          : subjects.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assessment_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No progress data available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Start practicing to see your progress!',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Subject tabs
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _subjectTabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF6B73FF),
                    labelColor: const Color(0xFF6B73FF),
                    unselectedLabelColor: Colors.grey,
                    labelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    tabs: subjects
                        .map((subject) => Tab(text: subject))
                        .toList(),
                  ),
                ),
                // Subject content
                Expanded(
                  child: TabBarView(
                    controller: _subjectTabController,
                    children: subjects
                        .map((subject) => _buildSubjectView(subject))
                        .toList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSubjectView(String subject) {
    final wordLists = subjectWordLists[subject] ?? [];
    final attempts = allAttempts[subject] ?? [];

    if (wordLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No word lists found for $subject',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: wordLists.length,
      itemBuilder: (context, index) {
        final listName = wordLists[index];
        return _buildWordListSection(subject, listName, attempts);
      },
    );
  }

  Widget _buildWordListSection(
    String subject,
    String listName,
    List<WordAttempt> subjectAttempts,
  ) {
    final listAttempts = subjectAttempts
        .where((attempt) => attempt.listName == listName)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          listName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D3748),
          ),
        ),
        subtitle: Text(
          '${listAttempts.length} attempts recorded',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildProgressTable(listAttempts),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTable(List<WordAttempt> attempts) {
    if (attempts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.timeline_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No attempts recorded yet',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Group attempts by word
    final Map<String, List<WordAttempt>> wordAttempts = {};
    for (var attempt in attempts) {
      wordAttempts.putIfAbsent(attempt.word, () => []).add(attempt);
    }

    return FutureBuilder<Map<String, String>>(
      future: _getWordFirstPracticeDates(wordAttempts.keys.toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final wordFirstDates = snapshot.data ?? {};

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with repetition steps
                _buildTableHeader(),
                // Word rows
                ...wordAttempts.entries.map(
                  (entry) => _buildWordRow(
                    entry.key,
                    entry.value,
                    wordFirstDates[entry.key],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get first practice dates for words
  Future<Map<String, String>> _getWordFirstPracticeDates(
    List<String> words,
  ) async {
    final Map<String, String> firstDates = {};

    for (String word in words) {
      final schedule = await SpacedRepetitionService.getWordSchedule(word);
      if (schedule != null) {
        // Use lastReviewDate as the first practice date for SQLite version
        firstDates[word] = schedule.lastReviewDate;
      }
    }

    return firstDates;
  }

  Widget _buildTableHeader() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6B73FF),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(7),
          topRight: Radius.circular(7),
        ),
      ),
      child: Row(
        children: [
          // Word column header
          Container(
            width: 120,
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.white, width: 1)),
            ),
            child: const Text(
              'Word',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          // Repetition step headers
          ...repetitionDays.map(
            (day) => Container(
              width: 80,
              padding: const EdgeInsets.all(8), // Reduced padding from 12 to 8
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white, width: 1),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, // Prevent overflow
                children: [
                  Text(
                    'D$day',
                    style: const TextStyle(
                      fontSize: 11, // Reduced from 12
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1), // Reduced from 2
                  Text(
                    'Step ${repetitionDays.indexOf(day) + 1}',
                    style: const TextStyle(
                      fontSize: 9, // Reduced from 10
                      color: Colors.white70,
                    ),
                  ),
                  // Show explanation for what the date means
                  Text(
                    'from start',
                    style: const TextStyle(fontSize: 7, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordRow(
    String word,
    List<WordAttempt> wordAttempts,
    String? firstPracticeDate,
  ) {
    // Sort attempts by repetition step
    wordAttempts.sort((a, b) => a.repetitionStep.compareTo(b.repetitionStep));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          // Word column
          Container(
            width: 120,
            padding: const EdgeInsets.all(8), // Reduced padding from 12 to 8
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text(
              word,
              style: const TextStyle(
                fontSize: 13, // Reduced from 14
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
              ),
              maxLines: 2, // Allow wrapping to 2 lines
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Result cells for each repetition step
          ...repetitionDays.asMap().entries.map((entry) {
            final stepIndex = entry.key;
            final stepDay = entry.value;

            // Calculate expected date for this step
            String expectedDate = '';
            if (firstPracticeDate != null && firstPracticeDate.isNotEmpty) {
              // Calculate cumulative days from D1
              int cumulativeDays = _calculateCumulativeDays(stepIndex);
              expectedDate = _addDaysToDate(firstPracticeDate, cumulativeDays);
            }

            // Get all attempts for this step
            final stepAttempts = wordAttempts
                .where((a) => a.repetitionStep == stepIndex)
                .toList();

            // Show last attempt result or empty if none
            if (stepAttempts.isEmpty) {
              return _buildEmptyCell(stepDay, expectedDate);
            }

            // Sort by date and get the last attempt for this step
            stepAttempts.sort((a, b) => b.date.compareTo(a.date));
            final lastAttempt = stepAttempts.first;

            return _buildResultCell(
              lastAttempt,
              stepDay,
              stepAttempts,
              expectedDate,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyCell(int stepDay, String expectedDate) {
    return Container(
      width: 80,
      height: 56, // Reduced from 60 to 56 for more space
      decoration: BoxDecoration(
        color: Colors.grey[200]!,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Container(
        padding: const EdgeInsets.all(2), // Reduced padding from 4 to 2
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min, // Prevent overflow
          children: [
            Text(
              '-',
              style: TextStyle(
                fontSize: 12, // Reduced from 14
                fontWeight: FontWeight.bold,
                color: Colors.grey[600]!,
              ),
            ),
            // Show expected date if available
            if (expectedDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatShortDate(expectedDate),
                  style: TextStyle(fontSize: 8, color: Colors.grey[500]!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCell(
    WordAttempt lastAttempt,
    int stepDay,
    List<WordAttempt> allStepAttempts,
    String expectedDate,
  ) {
    // Group attempts by mode
    final auditoryAttempts = allStepAttempts
        .where((a) => a.type == 'auditory')
        .toList();
    final visualAttempts = allStepAttempts
        .where((a) => a.type == 'visual')
        .toList();

    // Determine background color based on latest attempt result
    Color backgroundColor = Colors.grey[200]!;
    Color textColor = Colors.grey[600]!;

    if (allStepAttempts.isNotEmpty) {
      // Sort by most recent and get overall result
      allStepAttempts.sort((a, b) => b.date.compareTo(a.date));
      final latestAttempt = allStepAttempts.first;

      switch (latestAttempt.result) {
        case 'correct':
          backgroundColor = Colors.green;
          textColor = Colors.white;
          break;
        case 'incorrect':
          backgroundColor = Colors.red;
          textColor = Colors.white;
          break;
        case 'missed':
          backgroundColor = Colors.orange;
          textColor = Colors.white;
          break;
      }
    }

    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showModeAttemptDetails(
            lastAttempt.word,
            stepDay,
            auditoryAttempts,
            visualAttempts,
          ),
          child: Container(
            padding: const EdgeInsets.all(2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show auditory attempts if any
                if (auditoryAttempts.isNotEmpty)
                  Text(
                    'A(${auditoryAttempts.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                // Show visual attempts if any
                if (visualAttempts.isNotEmpty)
                  Text(
                    'V(${visualAttempts.length})',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                // Show expected date if available
                if (expectedDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      _formatShortDate(expectedDate),
                      style: TextStyle(
                        fontSize: 6,
                        color: textColor.withValues(alpha: 0.8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showModeAttemptDetails(
    String word,
    int stepDay,
    List<WordAttempt> auditoryAttempts,
    List<WordAttempt> visualAttempts,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Attempts for "$word" - Day $stepDay',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2D3748),
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auditory attempts section
              if (auditoryAttempts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.headphones, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Auditory Mode (${auditoryAttempts.length} attempt${auditoryAttempts.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...auditoryAttempts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attempt = entry.value;
                  return _buildAttemptTile(
                    attempt,
                    index + 1,
                    auditoryAttempts.length,
                  );
                }),
                if (visualAttempts.isNotEmpty) const SizedBox(height: 16),
              ],

              // Visual attempts section
              if (visualAttempts.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.visibility, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Visual Mode (${visualAttempts.length} attempt${visualAttempts.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...visualAttempts.asMap().entries.map((entry) {
                  final index = entry.key;
                  final attempt = entry.value;
                  return _buildAttemptTile(
                    attempt,
                    index + 1,
                    visualAttempts.length,
                  );
                }),
              ],

              // Show if no attempts
              if (auditoryAttempts.isEmpty && visualAttempts.isEmpty)
                const Text(
                  'No attempts found for this day.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptTile(
    WordAttempt attempt,
    int attemptNumber,
    int totalAttempts,
  ) {
    Color backgroundColor;
    IconData icon;
    Color iconColor;
    String resultText;

    switch (attempt.result) {
      case 'correct':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        icon = Icons.check_circle;
        iconColor = Colors.green;
        resultText = 'Correct';
        break;
      case 'incorrect':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        icon = Icons.error;
        iconColor = Colors.red;
        resultText = 'Incorrect';
        break;
      case 'missed':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        icon = Icons.warning;
        iconColor = Colors.orange;
        resultText = 'Missed';
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        icon = Icons.help_outline;
        iconColor = Colors.grey;
        resultText = 'Unknown';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: iconColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Attempt $attemptNumber/$totalAttempts',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      resultText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (attempt.heardOrTyped.isNotEmpty)
                  Text(
                    'Response: "${attempt.heardOrTyped}"',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF4A5568),
                    ),
                  ),
                if (attempt.date.isNotEmpty)
                  Text(
                    'Date: ${_formatFullDate(attempt.date)}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to calculate cumulative days from D1 for each step
  int _calculateCumulativeDays(int stepIndex) {
    // D1 = 0 days (start), D2 = 1 day, D4 = 3 days, D8 = 7 days, etc.
    switch (stepIndex) {
      case 0:
        return 0; // D1
      case 1:
        return 1; // D2 = D1 + 1
      case 2:
        return 3; // D4 = D1 + 3
      case 3:
        return 7; // D8 = D1 + 7
      case 4:
        return 15; // D16 = D1 + 15
      case 5:
        return 29; // D30 = D1 + 29
      case 6:
        return 59; // D60 = D1 + 59
      case 7:
        return 149; // D150 = D1 + 149
      default:
        return 0;
    }
  }

  // Helper method to add days to a date string
  String _addDaysToDate(String dateString, int days) {
    try {
      final date = DateTime.parse(dateString);
      final newDate = date.add(Duration(days: days));
      return newDate.toIso8601String().split('T')[0];
    } catch (e) {
      return dateString;
    }
  }

  String _formatShortDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[1]}/${parts[2]}';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return date.length > 5 ? date.substring(5) : date;
  }

  String _formatFullDate(String date) {
    if (date.isEmpty) return '';
    try {
      final parts = date.split('-');
      if (parts.length == 3) {
        return '${parts[1]}/${parts[2]}/${parts[0]}';
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return date;
  }
}
