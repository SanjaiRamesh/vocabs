import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_attempt.dart';
import '../services/word_attempt_service.dart';
import '../services/word_list_service.dart';
import '../services/spaced_repetition_service.dart';
import '../services/database_helper.dart';
import '../utils/logger.dart';

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
  bool isAdmin = false;

  // Show 30 consecutive days in the progress table
  final List<int> displayDays = List.generate(30, (index) => index + 1);

  // Scheduled review days from spaced repetition (within 30 days)
  final List<int> scheduledDays = [1, 2, 4, 7];

  @override
  void initState() {
    super.initState();
    _checkAdminRole();
    _loadProgressData();
  }

  @override
  void dispose() {
    if (subjects.isNotEmpty) {
      _subjectTabController.dispose();
    }
    super.dispose();
  }

  Future<void> _checkAdminRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isAdmin = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final role = userDoc.data()?['role'] as String?;
        setState(() => isAdmin = role == 'admin');
      } else {
        setState(() => isAdmin = false);
      }
    } catch (e) {
      logDebug('Error checking admin role: $e');
      setState(() => isAdmin = false);
    }
  }

  Future<void> _loadProgressData() async {
    try {
      setState(() => isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      // Get all subjects
      final availableSubjects = await WordListService.getAvailableSubjects(
        user.uid,
      );

      // Get word lists for each subject
      final Map<String, List<String>> wordListsMap = {};
      for (String subject in availableSubjects) {
        final wordLists = await WordListService.getWordListsBySubject(
          user.uid,
          subject,
        );
        wordListsMap[subject] = wordLists
            .map((wl) => wl.listName)
            .toSet()
            .toList();
      }

      // Get all attempts
      final attempts = await WordAttemptService.getAllAttempts(user.uid);
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
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Clear Review Schedules',
              onPressed: _clearReviewSchedules,
            ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Database',
            onPressed: _showDatabaseDebug,
          ),
        ],
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return firstDates;

    for (String word in words) {
      // ✅ Get the anchor date from the review plan
      final plan = await SpacedRepetitionService.getWordReviewPlan(
        user.uid,
        word,
      );
      if (plan != null) {
        firstDates[word] = plan.anchorDate; // ✅ Use anchor date
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
          // Day headers (D1-D30)
          ...displayDays.map(
            (day) => Container(
              width: 80,
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.white, width: 1),
                ),
              ),
              child: Text(
                'D$day',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
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
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Text(
              word,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Result cells for each day (D1-D30)
          ...displayDays.map((dayNumber) {
            // Calculate the actual date for this day
            String dayDate = '';
            if (firstPracticeDate != null && firstPracticeDate.isNotEmpty) {
              // Day 1 = anchor date + 0 days, Day 2 = anchor date + 1 day, etc.
              dayDate = _addDaysToDate(firstPracticeDate, dayNumber - 1);
            }

            // Check if this is a scheduled review day
            final isScheduledDay = scheduledDays.contains(dayNumber);

            // Get all attempts that occurred on this date
            final dayAttempts = wordAttempts
                .where((a) => a.date == dayDate)
                .toList();

            // Show empty or filled cell
            if (dayAttempts.isEmpty) {
              return _buildEmptyCell(dayNumber, dayDate, isScheduledDay);
            }

            // Sort by timestamp and get latest attempt
            dayAttempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            final latestAttempt = dayAttempts.first;

            return _buildResultCell(
              latestAttempt,
              dayNumber,
              dayAttempts,
              dayDate,
              isScheduledDay,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyCell(int dayNumber, String dayDate, bool isScheduledDay) {
    // Scheduled days get a subtle indicator, non-scheduled days are plain grey
    final backgroundColor = isScheduledDay
        ? Colors.blue.withValues(alpha: 0.05)
        : Colors.grey[100]!;
    final borderColor = isScheduledDay
        ? Colors.blue.withValues(alpha: 0.2)
        : Colors.grey[300]!;

    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isScheduledDay)
              Icon(
                Icons.circle_outlined,
                size: 12,
                color: Colors.blue.withValues(alpha: 0.4),
              ),
            // Show date if available
            if (dayDate.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _formatShortDate(dayDate),
                  style: TextStyle(
                    fontSize: 7,
                    color: isScheduledDay ? Colors.blue[300] : Colors.grey[400],
                  ),
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
    int dayNumber,
    List<WordAttempt> allDayAttempts,
    String dayDate,
    bool isScheduledDay,
  ) {
    // Group attempts by mode
    final auditoryAttempts = allDayAttempts
        .where((a) => a.type == 'auditory')
        .toList();
    final visualAttempts = allDayAttempts
        .where((a) => a.type == 'visual')
        .toList();

    // Determine background color based on latest attempt result
    Color backgroundColor = Colors.grey[200]!;
    Color textColor = Colors.grey[600]!;
    Color borderColor = Colors.grey[300]!;

    if (allDayAttempts.isNotEmpty) {
      // Sort by most recent and get overall result
      allDayAttempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final latestAttempt = allDayAttempts.first;

      switch (latestAttempt.result) {
        case 'correct':
          backgroundColor = Colors.green;
          textColor = Colors.white;
          borderColor = Colors.green[700]!;
          break;
        case 'incorrect':
          backgroundColor = Colors.red;
          textColor = Colors.white;
          borderColor = Colors.red[700]!;
          break;
        case 'missed':
          backgroundColor = Colors.orange;
          textColor = Colors.white;
          borderColor = Colors.orange[700]!;
          break;
      }
    }

    // For scheduled days: normal border
    // For non-scheduled days: thicker border to indicate off-schedule practice
    final borderWidth = isScheduledDay ? 1.0 : 2.0;
    if (!isScheduledDay) {
      borderColor = Colors.purple.withValues(alpha: 0.6);
    }

    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showModeAttemptDetails(
            lastAttempt.word,
            dayNumber,
            dayDate,
            isScheduledDay,
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
                // Show date
                if (dayDate.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      _formatShortDate(dayDate),
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
    int dayNumber,
    String dayDate,
    bool isScheduledDay,
    List<WordAttempt> auditoryAttempts,
    List<WordAttempt> visualAttempts,
  ) {
    final scheduleStatus = isScheduledDay ? '(Scheduled)' : '(Off-Schedule)';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Attempts for "$word" - Day $dayNumber',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            if (dayDate.isNotEmpty)
              Text(
                '${_formatFullDate(dayDate)} $scheduleStatus',
                style: TextStyle(
                  fontSize: 12,
                  color: isScheduledDay ? Colors.blue : Colors.purple,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
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

  Future<void> _clearReviewSchedules() async {
    // Get current user ID
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'local_student';

    // Migration check disabled - SharedPreferences not available
    // TODO: Implement migration tracking via Firestore or database
    final alreadyMigrated = false;

    if (alreadyMigrated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Schedules already migrated for this user'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Migrate to New Schedule?'),
        content: const Text(
          'This will clear old review schedules for your account '
          'and use the new 6-step schedule (D1, D2, D4, D7, D21, D30).\n\n'
          'This is a ONE-TIME operation per user.\n\n'
          'Word lists and practice history will NOT be affected.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
            child: const Text('Migrate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.clearAllReviewSchedules();

      // Migration tracking disabled - SharedPreferences not available
      // TODO: Implement migration tracking via Firestore or database
      // await prefs.setBool(migrationKey, true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Schedules migrated successfully! New reviews will use the updated schedule.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Reload the screen
        _loadProgressData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during migration: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDatabaseDebug() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get all attempts
      final attempts = await WordAttemptService.getAllAttempts(user.uid);

      // Get review plans
      final plans = await SpacedRepetitionService.getAllWordReviewPlans(
        user.uid,
      );

      // Build debug info
      final buffer = StringBuffer();
      buffer.writeln('📊 DATABASE DEBUG INFO\n');
      buffer.writeln(
        'Current Date: ${DateTime.now().toIso8601String().split('T')[0]}\n',
      );

      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📋 WORD ATTEMPTS (${attempts.length} total)');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━\n');

      // Group by word
      final attemptsByWord = <String, List<WordAttempt>>{};
      for (final attempt in attempts) {
        attemptsByWord.putIfAbsent(attempt.word, () => []).add(attempt);
      }

      for (final word in attemptsByWord.keys.take(10)) {
        // Show first 10 words
        buffer.writeln('Word: "$word"');
        final wordAttempts = attemptsByWord[word]!;
        wordAttempts.sort((a, b) => a.date.compareTo(b.date));

        for (final attempt in wordAttempts) {
          buffer.writeln(
            '  ${attempt.date} | Step: ${attempt.repetitionStep} | Result: ${attempt.result} | Type: ${attempt.type}',
          );
        }
        buffer.writeln();
      }

      buffer.writeln('\n━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('📅 REVIEW PLANS (${plans.length} total)');
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━\n');

      for (final plan in plans.take(10)) {
        // Show first 10 plans
        buffer.writeln('Word: "${plan.word}"');
        buffer.writeln('  Anchor Date: ${plan.anchorDate}');

        // Get review dates for this word
        final reviewDates = await SpacedRepetitionService.getWordReviewDates(
          user.uid,
          plan.word,
        );
        buffer.writeln('  Review Dates (${reviewDates.length} total):');
        for (final rd in reviewDates.take(8)) {
          // Show first 8 review dates
          buffer.writeln('    Step ${rd.stepIndex}: ${rd.reviewDate}');
        }
        buffer.writeln();
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Database Debug Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: SingleChildScrollView(
                child: SelectableText(
                  buffer.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} // ⬅️ This is the final closing brace of _ProgressScreenState class
