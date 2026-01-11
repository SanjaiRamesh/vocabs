import '../models/word_review_plan.dart';
import '../models/word_review_date.dart';
import '../models/word_attempt_log.dart';
import '../models/word_schedule.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SpacedRepetitionService {
  // Fixed schedule offsets in days
  static const List<int> _scheduleOffsets = [
    1, // Day 1:  Review tomorrow
    2, // Day 2:  Review in 2 days
    3, // Day 3:  Review in 3 days
    4, // Day 4:  Review in 4 days
    5, // Day 5:  Review in 5 days
    6, // Day 6:  Review in 6 days
    8, // Day 8:  Review in 8 days
    9, // Day 9:  Review in 9 days
    10, // Day 10: Review in 10 days
    11, // Day 11: Review in 11 days
    15, // Day 15: Review in 15 days
    16, // Day 16: Review in 16 days
    31, // Day 31: Review in 31 days (~1 month)
    32, // Day 32: Review in 32 days
    60, // Day 60: Review in 60 days (~2 months)
    120, // Day 120: Review in 120 days (~4 months)
    210, // Day 210: Review in 210 days (~7 months)
    390, // Day 390: Review in 390 days (~13 months)
  ];

  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> init() async {
    if (kIsWeb) return; // Web doesn't support SQLite
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
  /// Calculate which repetition step today corresponds to for a word
  /// Returns the stepIndex (0-17) based on the precomputed review dates
  static Future<int> getRepetitionStepForDate(String word, String date) async {
    // Get the review plan to check if this is the anchor date
    final plan = await getWordReviewPlan(word);

    // If this is the anchor date (first practice), return -1
    if (plan != null && plan.anchorDate == date) {
      return -1; // ✅ Not a review, it's initial learning
    }

    final reviewDates = await getWordReviewDates(word);

    // Find exact match in precomputed review dates
    for (final reviewDate in reviewDates) {
      if (reviewDate.reviewDate == date) {
        return reviewDate.stepIndex; // ✅ Return the correct step (0-17)
      }
    }

    // No exact match - return 0 (treating as new/first practice)
    return -1; // ✅ Changed from 0 to -1
  }

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
