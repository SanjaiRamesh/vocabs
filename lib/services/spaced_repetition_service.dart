import '../models/word_review_plan.dart';
import '../models/word_review_date.dart';
import '../models/word_attempt_log.dart';
import '../models/word_schedule.dart';
import 'database_helper.dart';

class SpacedRepetitionService {
  // Fixed schedule offsets in days
  static const List<int> _scheduleOffsets = [
    1,
    2,
    3,
    4,
    5,
    6,
    8,
    9,
    10,
    11,
    15,
    16,
    31,
    32,
    60,
    120,
    210,
    390,
  ];

  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> init() async {
    await _databaseHelper.database;
  }

  /// Initialize a word's review plan on first attempt
  /// Precomputes all 18 review dates from the anchor date
  static Future<void> initializeWordReviewPlan(
    String word,
    String anchorDate,
  ) async {
    // Check if plan already exists
    final existing = await _databaseHelper.getWordReviewPlan(word);
    if (existing != null) {
      return; // Already initialized
    }

    // Create review plan
    final plan = WordReviewPlan(word: word, anchorDate: anchorDate);
    await _databaseHelper.insertWordReviewPlan(plan);

    // Precompute all review dates
    final reviewDates = <WordReviewDate>[];
    for (int i = 0; i < _scheduleOffsets.length; i++) {
      final reviewDate = _addDaysToDate(anchorDate, _scheduleOffsets[i]);
      reviewDates.add(
        WordReviewDate(word: word, reviewDate: reviewDate, stepIndex: i),
      );
    }

    // Insert all precomputed dates at once
    await _databaseHelper.insertWordReviewDates(word, reviewDates);
  }

  /// Log an attempt for a word on a specific review date
  /// Only the FIRST attempt on a review date is recorded
  /// Subsequent attempts on the same date are ignored
  static Future<void> logWordAttempt(
    String word,
    String reviewDate,
    String result,
    String heardOrTyped,
  ) async {
    // Check if an attempt already exists for this word on this review date
    final existing = await _databaseHelper.getAttemptForReviewDate(
      word,
      reviewDate,
    );

    if (existing != null) {
      // Already attempted on this review date - IGNORE
      return;
    }

    // First attempt on this review date - record it
    final attempt = WordAttemptLog(
      word: word,
      reviewDate: reviewDate,
      result: result,
      heardOrTyped: heardOrTyped,
    );

    await _databaseHelper.insertWordAttemptLog(attempt);
  }

  /// Get all words that have a review scheduled for the given date
  /// Includes their attempt result if one exists for that date
  static Future<List<WordReviewDate>> getWordsForReview(String date) async {
    return await _databaseHelper.getWordsWithReviewDue(date);
  }

  /// Get the review plan for a word (anchor date)
  static Future<WordReviewPlan?> getWordReviewPlan(String word) async {
    return await _databaseHelper.getWordReviewPlan(word);
  }

  /// Get all precomputed review dates for a word
  static Future<List<WordReviewDate>> getWordReviewDates(String word) async {
    return await _databaseHelper.getWordReviewDates(word);
  }

  /// Get attempt log for a specific word and review date
  static Future<WordAttemptLog?> getAttemptForReviewDate(
    String word,
    String reviewDate,
  ) async {
    return await _databaseHelper.getAttemptForReviewDate(word, reviewDate);
  }

  /// Get all attempt logs for a word
  static Future<List<WordAttemptLog>> getWordAttemptLogs(String word) async {
    return await _databaseHelper.getWordAttemptLogs(word);
  }

  /// Get all words with initialized review plans
  static Future<List<WordReviewPlan>> getAllWordReviewPlans() async {
    return await _databaseHelper.getAllWordReviewPlans();
  }

  /// Helper: Add days to a date string
  static String _addDaysToDate(String dateString, int days) {
    final date = DateTime.parse(dateString);
    final newDate = date.add(Duration(days: days));
    return newDate.toIso8601String().split('T')[0];
  }

  // ============ Backward Compatibility Methods ============
  // These methods maintain compatibility with code that uses the old WordSchedule API

  /// Get word schedule for backward compatibility
  /// Returns a constructed WordSchedule from the review plan
  static Future<WordSchedule?> getWordSchedule(String word) async {
    final plan = await getWordReviewPlan(word);
    if (plan == null) return null;

    // Get all attempts for this word
    final attempts = await _databaseHelper.getWordAttemptLogs(word);

    // Find the last attempt
    WordAttemptLog? lastAttempt;
    if (attempts.isNotEmpty) {
      lastAttempt = attempts.last;
    }

    // Create a synthetic WordSchedule from the plan and attempts
    return WordSchedule(
      word: word,
      repetitionStep: 0,
      lastReviewDate: lastAttempt?.reviewDate ?? plan.anchorDate,
      nextReviewDate: plan.anchorDate, // Fixed, no rescheduling
      incorrectCount: attempts.where((a) => a.result == 'incorrect').length,
      isHard: false,
    );
  }

  /// Get all schedules for backward compatibility
  static Future<List<WordSchedule>> getAllSchedules() async {
    final plans = await getAllWordReviewPlans();
    final schedules = <WordSchedule>[];

    for (final plan in plans) {
      final schedule = await getWordSchedule(plan.word);
      if (schedule != null) {
        schedules.add(schedule);
      }
    }

    return schedules;
  }

  /// Get words for review (returns WordSchedule for compatibility)
  static Future<List<WordSchedule>> getWordsForReviewCompat(String date) async {
    final reviewDates = await getWordsForReview(date);
    final schedules = <WordSchedule>[];

    for (final reviewDate in reviewDates) {
      final schedule = await getWordSchedule(reviewDate.word);
      if (schedule != null) {
        schedules.add(schedule);
      }
    }

    return schedules;
  }

  /// Get hard words for backward compatibility
  static Future<List<WordSchedule>> getHardWords() async {
    final allSchedules = await getAllSchedules();
    return allSchedules.where((s) => s.isHard).toList();
  }
}
