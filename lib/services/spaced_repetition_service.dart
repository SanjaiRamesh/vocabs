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
    4, // Day 3:  Review in 3 days
    7, // Day 4:  Review in 4 days
  ];

  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> init() async {
    if (kIsWeb) return; // Web doesn't support SQLite
    await _databaseHelper.database;
  }

  /// Initialize a word's review plan on first attempt
  /// Precomputes all 18 review dates from the anchor date
  static Future<void> initializeWordReviewPlan(
    String userId,
    String word,
    String anchorDate,
  ) async {
    // Check if plan already exists
    final existing = await _databaseHelper.getWordReviewPlan(userId, word);
    if (existing != null) {
      return; // Already initialized
    }

    // Create review plan
    final plan = WordReviewPlan(
      userId: userId,
      word: word,
      anchorDate: anchorDate,
    );
    await _databaseHelper.insertWordReviewPlan(userId, plan);

    // Precompute all review dates
    final reviewDates = <WordReviewDate>[];
    for (int i = 0; i < _scheduleOffsets.length; i++) {
      final reviewDate = _addDaysToDate(anchorDate, _scheduleOffsets[i]);
      reviewDates.add(
        WordReviewDate(
          userId: userId,
          word: word,
          reviewDate: reviewDate,
          stepIndex: i,
        ),
      );
    }

    // Insert all precomputed dates at once
    await _databaseHelper.insertWordReviewDates(userId, word, reviewDates);
  }

  /// Log an attempt for a word on a specific review date
  /// Only the FIRST attempt on a review date is recorded
  /// Subsequent attempts on the same date are ignored
  static Future<void> logWordAttempt(
    String userId,
    String word,
    String reviewDate,
    String result,
    String heardOrTyped,
  ) async {
    // Check if an attempt already exists for this word on this review date
    final existing = await _databaseHelper.getAttemptForReviewDate(
      userId,
      word,
      reviewDate,
    );

    if (existing != null) {
      // Already attempted on this review date - IGNORE
      return;
    }

    // First attempt on this review date - record it
    final attempt = WordAttemptLog(
      userId: userId,
      word: word,
      reviewDate: reviewDate,
      result: result,
      heardOrTyped: heardOrTyped,
    );

    await _databaseHelper.insertWordAttemptLog(userId, attempt);
  }

  /// Get all words that have a review scheduled for the given date
  /// Includes their attempt result if one exists for that date
  static Future<List<WordReviewDate>> getWordsForReview(
    String userId,
    String date,
  ) async {
    return await _databaseHelper.getWordsWithReviewDue(userId, date);
  }

  /// Get the review plan for a word (anchor date)
  static Future<WordReviewPlan?> getWordReviewPlan(
    String userId,
    String word,
  ) async {
    return await _databaseHelper.getWordReviewPlan(userId, word);
  }

  /// Get all precomputed review dates for a word
  static Future<List<WordReviewDate>> getWordReviewDates(
    String userId,
    String word,
  ) async {
    return await _databaseHelper.getWordReviewDates(userId, word);
  }

  /// Get attempt log for a specific word and review date
  static Future<WordAttemptLog?> getAttemptForReviewDate(
    String userId,
    String word,
    String reviewDate,
  ) async {
    return await _databaseHelper.getAttemptForReviewDate(
      userId,
      word,
      reviewDate,
    );
  }

  /// Get all attempt logs for a word
  static Future<List<WordAttemptLog>> getWordAttemptLogs(
    String userId,
    String word,
  ) async {
    return await _databaseHelper.getWordAttemptLogs(userId, word);
  }

  /// Get all words with initialized review plans
  static Future<List<WordReviewPlan>> getAllWordReviewPlans(
    String userId,
  ) async {
    return await _databaseHelper.getAllWordReviewPlans(userId);
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
  static Future<int> getRepetitionStepForDate(
    String userId,
    String word,
    String date,
  ) async {
    // Get the review plan to check if this is the anchor date
    final plan = await getWordReviewPlan(userId, word);

    // If this is the anchor date (first practice), return -1
    if (plan != null && plan.anchorDate == date) {
      return -1; // ✅ Not a review, it's initial learning
    }

    final reviewDates = await getWordReviewDates(userId, word);

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
  static Future<WordSchedule?> getWordSchedule(
    String userId,
    String word,
  ) async {
    final plan = await getWordReviewPlan(userId, word);
    if (plan == null) return null;

    // Get all attempts for this word
    final attempts = await _databaseHelper.getWordAttemptLogs(userId, word);

    // Find the last attempt
    WordAttemptLog? lastAttempt;
    if (attempts.isNotEmpty) {
      lastAttempt = attempts.last;
    }

    // Create a synthetic WordSchedule from the plan and attempts
    return WordSchedule(
      userId: userId,
      word: word,
      repetitionStep: 0,
      lastReviewDate: lastAttempt?.reviewDate ?? plan.anchorDate,
      nextReviewDate: plan.anchorDate, // Fixed, no rescheduling
      incorrectCount: attempts.where((a) => a.result == 'incorrect').length,
      isHard: false,
    );
  }

  /// Get all schedules for backward compatibility
  static Future<List<WordSchedule>> getAllSchedules(String userId) async {
    final plans = await getAllWordReviewPlans(userId);
    final schedules = <WordSchedule>[];

    for (final plan in plans) {
      final schedule = await getWordSchedule(userId, plan.word);
      if (schedule != null) {
        schedules.add(schedule);
      }
    }

    return schedules;
  }

  /// Get words for review (returns WordSchedule for compatibility)
  static Future<List<WordSchedule>> getWordsForReviewCompat(
    String userId,
    String date,
  ) async {
    final reviewDates = await getWordsForReview(userId, date);
    final schedules = <WordSchedule>[];

    for (final reviewDate in reviewDates) {
      final schedule = await getWordSchedule(userId, reviewDate.word);
      if (schedule != null) {
        schedules.add(schedule);
      }
    }

    return schedules;
  }

  /// Get hard words for backward compatibility
  static Future<List<WordSchedule>> getHardWords(String userId) async {
    final allSchedules = await getAllSchedules(userId);
    return allSchedules.where((s) => s.isHard).toList();
  }
}
