import 'package:flutter/material.dart';
import '../models/word_schedule.dart';
import '../services/spaced_repetition_service.dart';

class SpacedRepetitionDemoScreen extends StatefulWidget {
  const SpacedRepetitionDemoScreen({super.key});

  @override
  State<SpacedRepetitionDemoScreen> createState() =>
      _SpacedRepetitionDemoScreenState();
}

class _SpacedRepetitionDemoScreenState
    extends State<SpacedRepetitionDemoScreen> {
  List<WordSchedule> _allSchedules = [];
  List<WordSchedule> _todaysWords = [];
  List<WordSchedule> _hardWords = [];
  Map<String, dynamic> _stats = {};
  String _today = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpacedRepetitionData();
  }

  Future<void> _loadSpacedRepetitionData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _today = DateTime.now().toIso8601String().split('T')[0];

      // Get all data
      _allSchedules = await SpacedRepetitionService.getAllSchedules();
      _todaysWords = await SpacedRepetitionService.getWordsForReviewCompat(
        _today,
      );
      _hardWords = await SpacedRepetitionService.getHardWords();
      _stats = _calculateStats();

      debugPrint('DEBUG: Today: $_today');
      debugPrint('DEBUG: Total schedules: ${_allSchedules.length}');
      debugPrint('DEBUG: Words for today: ${_todaysWords.length}');
      debugPrint('DEBUG: Hard words: ${_hardWords.length}');
    } catch (e) {
      debugPrint('Error loading spaced repetition data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _calculateStats() {
    final totalWords = _allSchedules.length;
    final hardWordsCount = _hardWords.length;
    final todaysWordsCount = _todaysWords.length;

    return {
      'totalWords': totalWords,
      'hardWords': hardWordsCount,
      'todaysWords': todaysWordsCount,
      'averageStep': totalWords > 0
          ? _allSchedules.map((s) => s.repetitionStep).reduce((a, b) => a + b) /
                totalWords
          : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spaced Repetition Demo',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadSpacedRepetitionData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoCard(),
                      const SizedBox(height: 16),
                      _buildStatsCard(),
                      const SizedBox(height: 16),
                      _buildTodaysWordsCard(),
                      const SizedBox(height: 16),
                      _buildAllSchedulesCard(),
                      const SizedBox(height: 16),
                      _buildHardWordsCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How Spaced Repetition Works',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Schedule: [1, 2, 4, 8, 16, 30, 60, 150] days',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Today: $_today',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Decision Logic:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '1. Check all word schedules in database\n'
                    '2. Find words where nextReviewDate == today\n'
                    '3. Return those words for practice\n'
                    '4. After practice, calculate next review date',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue,
                      fontFamily: 'OpenDyslexic',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatChip(
                  'Total Words',
                  _stats['totalWords'] ?? 0,
                  Colors.blue,
                ),
                _buildStatChip(
                  'Hard Words',
                  _stats['hardWords'] ?? 0,
                  Colors.red,
                ),
                _buildStatChip(
                  'Completed',
                  _stats['completedWords'] ?? 0,
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Step Distribution:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 8),
            if (_stats['stepDistribution'] != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < 8; i++)
                    _buildStepChip(i, _stats['stepDistribution'][i] ?? 0),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysWordsCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Words for Today (${_todaysWords.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            if (_todaysWords.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: const Text(
                  'No words scheduled for today!\nPractice some words to see them appear here.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.orange,
                    fontFamily: 'OpenDyslexic',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Column(
                children: _todaysWords
                    .map(
                      (schedule) => _buildScheduleItem(schedule, Colors.green),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSchedulesCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'All Word Schedules (${_allSchedules.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            if (_allSchedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: const Text(
                  'No word schedules found.\nStart practicing to create schedules!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue,
                    fontFamily: 'OpenDyslexic',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _allSchedules.length,
                  itemBuilder: (context, index) {
                    final schedule = _allSchedules[index];
                    final isToday = schedule.nextReviewDate == _today;
                    return _buildScheduleItem(
                      schedule,
                      isToday ? Colors.green : Colors.blue,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHardWordsCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hard Words (${_hardWords.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red,
                fontFamily: 'OpenDyslexic',
              ),
            ),
            const SizedBox(height: 12),
            if (_hardWords.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green, width: 1),
                ),
                child: const Text(
                  'No hard words yet!\nWords become "hard" after 3 incorrect attempts.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green,
                    fontFamily: 'OpenDyslexic',
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Column(
                children: _hardWords
                    .map((schedule) => _buildScheduleItem(schedule, Colors.red))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(WordSchedule schedule, Color color) {
    final scheduleDays = [1, 2, 4, 8, 16, 30, 60, 150];
    final currentDays = schedule.repetitionStep < scheduleDays.length
        ? scheduleDays[schedule.repetitionStep]
        : 150;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              schedule.word,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'Step ${schedule.repetitionStep}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'D$currentDays',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              schedule.nextReviewDate,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ),
          if (schedule.isHard) Icon(Icons.warning, color: Colors.red, size: 16),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              fontSize: 10,
              color: color,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepChip(int step, int count) {
    final scheduleDays = [1, 2, 4, 8, 16, 30, 60, 150];
    final days = step < scheduleDays.length ? scheduleDays[step] : 150;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purple, width: 1),
      ),
      child: Text(
        'D$days: $count',
        style: const TextStyle(
          fontSize: 10,
          color: Colors.purple,
          fontFamily: 'OpenDyslexic',
        ),
      ),
    );
  }
}
