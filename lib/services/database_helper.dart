// For mobile
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // For desktop
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import '../models/word_list.dart';
import '../models/word_attempt.dart';
import '../models/word_schedule.dart';
import '../models/word_review_plan.dart';
import '../models/word_review_date.dart';
import '../models/word_attempt_log.dart';

// Conditional import for Platform
import 'platform_helper.dart'
    if (dart.library.io) 'platform_helper_io.dart'
    if (dart.library.html) 'platform_helper_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // Initialize database factory for different platforms
  static Future<void> init() async {
    if (kIsWeb) {
      // Web doesn't use SQLite - use Hive or IndexedDB instead
      // For now, skip initialization on web
      return;
    }

    if (isDesktopPlatform()) {
      // Initialize FFI for desktop platforms
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS use default sqflite package automatically
  }

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Database not supported on web platform');
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('Database not supported on web platform');
    }
    String path = join(await getDatabasesPath(), 'reading_assistant.db');
    return await openDatabase(
      path,
      version: 5, // Increased version for multi-user schema changes
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Version 5: Multi-user schema - drop all tables and recreate
    if (oldVersion < 5) {
      // Drop all existing tables to recreate with user_id columns
      await db.execute('DROP TABLE IF EXISTS word_lists');
      await db.execute('DROP TABLE IF EXISTS word_attempts');
      await db.execute('DROP TABLE IF EXISTS word_schedules');
      await db.execute('DROP TABLE IF EXISTS word_review_plans');
      await db.execute('DROP TABLE IF EXISTS word_review_dates');
      await db.execute('DROP TABLE IF EXISTS word_attempt_logs');
      await db.execute('DROP TABLE IF EXISTS assessment_results');
      await db.execute('DROP TABLE IF EXISTS practice_usage_daily');

      // Recreate all tables with new schema
      await _createDatabase(db, newVersion);
      return;
    }

    if (oldVersion < 2) {
      // Add assessment_results table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS assessment_results (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          word TEXT NOT NULL,
          date TEXT NOT NULL,
          result TEXT NOT NULL,
          heard TEXT NOT NULL,
          listName TEXT NOT NULL,
          subject TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Drop and recreate word_attempts table without is_hard column
      await db.execute('DROP TABLE IF EXISTS word_attempts');
      await db.execute('''
      CREATE TABLE word_attempts (
        id TEXT PRIMARY KEY,
        word TEXT NOT NULL,
        date TEXT NOT NULL,
        result TEXT NOT NULL,
        type TEXT NOT NULL,
        repetition_step INTEGER NOT NULL,
        subject TEXT NOT NULL,
        list_name TEXT NOT NULL,
        heard_or_typed TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        UNIQUE(word, date, timestamp)
      )
    ''');

      // Recreate indexes
      await db.execute('''
      CREATE INDEX idx_word_attempts_word_date ON word_attempts(word, date)
    ''');
      await db.execute('''
      CREATE INDEX idx_word_attempts_subject ON word_attempts(subject)
    ''');
    }
    if (oldVersion < 4) {
      // Add practice_usage_daily table for daily practice time tracking
      await db.execute('''
        CREATE TABLE IF NOT EXISTS practice_usage_daily (
          date TEXT NOT NULL,
          user_local_id TEXT NOT NULL,
          practice_time_sec INTEGER NOT NULL DEFAULT 0,
          synced INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (date, user_local_id)
        )
      ''');
    }
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create word_lists table
    await db.execute('''
      CREATE TABLE word_lists (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        subject TEXT NOT NULL,
        list_name TEXT NOT NULL,
        words TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create index for user_id filtering
    await db.execute('''
      CREATE INDEX idx_word_lists_user ON word_lists(user_id)
    ''');

    // Create word_attempts table
    await db.execute('''
      CREATE TABLE word_attempts (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        word TEXT NOT NULL,
        date TEXT NOT NULL,
        result TEXT NOT NULL,
        type TEXT NOT NULL,
        repetition_step INTEGER NOT NULL,
        subject TEXT NOT NULL,
        list_name TEXT NOT NULL,
        heard_or_typed TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        UNIQUE(user_id, word, date, timestamp)
      )
    ''');

    // Create index for user_id filtering
    await db.execute('''
      CREATE INDEX idx_word_attempts_user ON word_attempts(user_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_word_attempts_user_date ON word_attempts(user_id, date)
    ''');

    // Create word_schedules table
    await db.execute('''
      CREATE TABLE word_schedules (
        user_id TEXT NOT NULL,
        word TEXT NOT NULL,
        repetition_step INTEGER NOT NULL,
        last_review_date TEXT NOT NULL,
        next_review_date TEXT NOT NULL,
        incorrect_count INTEGER NOT NULL,
        is_hard INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, word)
      )
    ''');

    // Index for word_schedules by user
    await db.execute('''
      CREATE INDEX idx_word_schedules_user ON word_schedules(user_id)
    ''');

    // Index for word_schedules by user and next_review_date
    await db.execute('''
      CREATE INDEX idx_word_schedules_user_date ON word_schedules(user_id, next_review_date)
    ''');

    // Create assessment_results table
    await db.execute('''
      CREATE TABLE assessment_results (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        date TEXT NOT NULL,
        result TEXT NOT NULL,
        heard TEXT NOT NULL,
        listName TEXT NOT NULL,
        subject TEXT NOT NULL
      )
    ''');

    // Create word_review_plans table (fixed precomputed schedules)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_review_plans (
        user_id TEXT NOT NULL,
        word TEXT NOT NULL,
        anchor_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        PRIMARY KEY (user_id, word)
      )
    ''');

    // Index for word_review_plans by user
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_review_plans_user ON word_review_plans(user_id)
    ''');

    // Create word_review_dates table (all precomputed review dates)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_review_dates (
        user_id TEXT NOT NULL,
        word TEXT NOT NULL,
        review_date TEXT NOT NULL,
        step_index INTEGER NOT NULL,
        PRIMARY KEY (user_id, word, review_date),
        FOREIGN KEY (user_id, word) REFERENCES word_review_plans(user_id, word)
      )
    ''');

    // Index for word_review_dates by user and review_date
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_review_dates_user_date ON word_review_dates(user_id, review_date)
    ''');

    // Index for word_review_dates by user and word
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_review_dates_user_word ON word_review_dates(user_id, word)
    ''');

    // Create word_attempt_logs table (simplified attempt logging)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_attempt_logs (
        user_id TEXT NOT NULL,
        word TEXT NOT NULL,
        review_date TEXT NOT NULL,
        result TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        heard_or_typed TEXT NOT NULL,
        PRIMARY KEY (user_id, word, review_date),
        FOREIGN KEY (user_id, word) REFERENCES word_review_plans(user_id, word)
      )
    ''');

    // Index for word_attempt_logs by user
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_attempt_logs_user ON word_attempt_logs(user_id)
    ''');

    // Index for word_attempt_logs by user and review_date
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_attempt_logs_user_date ON word_attempt_logs(user_id, review_date)
    ''');
    // Create practice_usage_daily table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS practice_usage_daily (
        date TEXT NOT NULL,
        user_local_id TEXT NOT NULL,
        practice_time_sec INTEGER NOT NULL DEFAULT 0,
        synced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (date, user_local_id)
      )
    ''');
    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_word_attempts_word_date ON word_attempts(word, date)
    ''');

    await db.execute('''
      CREATE INDEX idx_word_attempts_subject ON word_attempts(subject)
    ''');

    await db.execute('''
      CREATE INDEX idx_word_lists_subject ON word_lists(subject)
    ''');

    await db.execute('''
      CREATE INDEX idx_assessment_results_subject ON assessment_results(subject)
    ''');

    await db.execute('''
      CREATE INDEX idx_assessment_results_date ON assessment_results(date)
    ''');

    // Create indexes for word review tables
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_review_dates_review_date ON word_review_dates(review_date)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_word_attempt_logs_review_date ON word_attempt_logs(review_date)
    ''');
  }

  // Word Lists operations
  Future<void> insertWordList(WordList wordList) async {
    final db = await database;
    await db.insert(
      'word_lists',
      wordList.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WordList>> getAllWordLists(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => WordList.fromMap(maps[i]));
  }

  Future<List<WordList>> getWordListsBySubject(
    String userId,
    String subject,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      where: 'user_id = ? AND subject = ?',
      whereArgs: [userId, subject],
    );
    return List.generate(maps.length, (i) => WordList.fromMap(maps[i]));
  }

  Future<WordList?> getWordListById(String userId, String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
    if (maps.isNotEmpty) {
      return WordList.fromMap(maps.first);
    }
    return null;
  }

  Future<void> updateWordList(WordList wordList) async {
    final db = await database;
    await db.update(
      'word_lists',
      wordList.toMap(),
      where: 'user_id = ? AND id = ?',
      whereArgs: [wordList.userId, wordList.id],
    );
  }

  Future<void> deleteWordList(String userId, String id) async {
    final db = await database;
    await db.delete(
      'word_lists',
      where: 'user_id = ? AND id = ?',
      whereArgs: [userId, id],
    );
  }

  Future<void> deleteWordListsBySubject(String userId, String subject) async {
    final db = await database;
    await db.delete(
      'word_lists',
      where: 'user_id = ? AND subject = ?',
      whereArgs: [userId, subject],
    );
  }

  Future<void> deleteWordAttemptsBySubject(
    String userId,
    String subject,
  ) async {
    final db = await database;
    await db.delete(
      'word_attempts',
      where: 'user_id = ? AND subject = ?',
      whereArgs: [userId, subject],
    );
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }

  Future<void> deleteAssessmentResultsBySubject(String subject) async {
    final db = await database;

    // Check if table exists first
    final tableExists = await _tableExists(db, 'assessment_results');
    if (tableExists) {
      await db.delete(
        'assessment_results',
        where: 'subject = ?',
        whereArgs: [subject],
      );
    }
  }

  Future<void> deleteWordSchedulesBySubject(String subject) async {
    final db = await database;

    // Get all words that belong to the subject being deleted
    final List<Map<String, dynamic>> wordMaps = await db.query(
      'word_lists',
      columns: ['words'],
      where: 'subject = ?',
      whereArgs: [subject],
    );

    // Extract all words from all word lists for this subject
    final Set<String> wordsToDelete = <String>{};
    for (final wordMap in wordMaps) {
      final wordsJson = wordMap['words'] as String;
      final List<String> words = List<String>.from(jsonDecode(wordsJson));
      wordsToDelete.addAll(words);
    }

    // Delete word schedules for these words
    for (final word in wordsToDelete) {
      await db.delete('word_schedules', where: 'word = ?', whereArgs: [word]);
    }
  }

  // Word Attempts operations
  Future<void> insertWordAttempt(WordAttempt attempt) async {
    final db = await database;
    await db.insert(
      'word_attempts',
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WordAttempt>> getAllWordAttempts(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempts',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  Future<List<WordAttempt>> getWordAttemptsBySubject(
    String userId,
    String subject,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempts',
      where: 'user_id = ? AND subject = ?',
      whereArgs: [userId, subject],
    );
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  Future<List<WordAttempt>> getWordAttemptsByWordAndDate(
    String userId,
    String word,
    String date,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempts',
      where: 'user_id = ? AND word = ? AND date = ?',
      whereArgs: [userId, word, date],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  // Word Schedules operations
  Future<void> insertWordSchedule(String userId, WordSchedule schedule) async {
    final db = await database;
    await db.insert(
      'word_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WordSchedule?> getWordSchedule(String userId, String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_schedules',
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, word],
    );
    if (maps.isNotEmpty) {
      return WordSchedule.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordSchedule>> getWordSchedulesForReview(
    String userId,
    String date,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_schedules',
      where: 'user_id = ? AND next_review_date <= ?',
      whereArgs: [userId, date],
    );
    return List.generate(maps.length, (i) => WordSchedule.fromMap(maps[i]));
  }

  Future<List<WordSchedule>> getAllWordSchedules(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_schedules',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => WordSchedule.fromMap(maps[i]));
  }

  Future<void> updateWordSchedule(String userId, WordSchedule schedule) async {
    final db = await database;
    await db.update(
      'word_schedules',
      schedule.toMap(),
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, schedule.word],
    );
  }

  Future<void> deleteWordSchedule(String userId, String word) async {
    final db = await database;
    await db.delete(
      'word_schedules',
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, word],
    );
  }

  // Subject operations
  Future<void> renameSubject(String oldName, String newName) async {
    final db = await database;

    // Update subject name in word_lists
    await db.update(
      'word_lists',
      {'subject': newName},
      where: 'subject = ?',
      whereArgs: [oldName],
    );

    // Update subject name in word_attempts
    await db.update(
      'word_attempts',
      {'subject': newName},
      where: 'subject = ?',
      whereArgs: [oldName],
    );

    // Update subject name in assessment_results
    if (await _tableExists(db, 'assessment_results')) {
      await db.update(
        'assessment_results',
        {'subject': newName},
        where: 'subject = ?',
        whereArgs: [oldName],
      );
    }

    // Note: word_schedules table doesn't have subject column
  }

  // Get available subjects for a user
  Future<List<String>> getAvailableSubjects(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      columns: ['subject'],
      where: 'user_id = ?',
      whereArgs: [userId],
      distinct: true,
    );
    return List.generate(maps.length, (i) => maps[i]['subject'] as String);
  }

  // Utility methods
  Future<void> closeDatabase() async {
    final db = await database;
    await db.close();
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('word_lists');
    await db.delete('word_attempts');
    await db.delete('word_schedules');
  }

  /// Clear all review schedules (plans and dates)
  /// Use this when changing the schedule configuration
  Future<void> clearAllReviewSchedules() async {
    final db = await database;
    await db.delete('word_review_dates');
    await db.delete('word_review_plans');
    await db.delete('word_attempt_logs');
    debugPrint('✅ Cleared all review schedules, plans, and attempt logs');
  }

  // ============ Word Review Plan Operations ============

  Future<void> insertWordReviewPlan(String userId, WordReviewPlan plan) async {
    final db = await database;
    await db.insert(
      'word_review_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WordReviewPlan?> getWordReviewPlan(String userId, String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_plans',
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, word],
    );
    if (maps.isNotEmpty) {
      return WordReviewPlan.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordReviewPlan>> getAllWordReviewPlans(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_plans',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return List.generate(maps.length, (i) => WordReviewPlan.fromMap(maps[i]));
  }

  // ============ Word Review Date Operations ============

  Future<void> insertWordReviewDates(
    String userId,
    String word,
    List<WordReviewDate> dates,
  ) async {
    final db = await database;
    final batch = db.batch();

    for (final date in dates) {
      batch.insert(
        'word_review_dates',
        date.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit();
  }

  Future<List<WordReviewDate>> getWordReviewDates(
    String userId,
    String word,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, word],
      orderBy: 'step_index ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  Future<List<WordReviewDate>> getWordsWithReviewDue(
    String userId,
    String date,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      where: 'user_id = ? AND review_date = ?',
      whereArgs: [userId, date],
      orderBy: 'step_index ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  Future<List<WordReviewDate>> getAllReviewDates(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'review_date ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  // ============ Word Attempt Log Operations ============

  Future<void> insertWordAttemptLog(
    String userId,
    WordAttemptLog attempt,
  ) async {
    final db = await database;
    await db.insert(
      'word_attempt_logs',
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicate attempts
    );
  }

  Future<WordAttemptLog?> getAttemptForReviewDate(
    String userId,
    String word,
    String reviewDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'user_id = ? AND word = ? AND review_date = ?',
      whereArgs: [userId, word, reviewDate],
    );
    if (maps.isNotEmpty) {
      return WordAttemptLog.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordAttemptLog>> getWordAttemptLogs(
    String userId,
    String word,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'user_id = ? AND word = ?',
      whereArgs: [userId, word],
      orderBy: 'review_date ASC',
    );
    return List.generate(maps.length, (i) => WordAttemptLog.fromMap(maps[i]));
  }

  Future<List<WordAttemptLog>> getAttemptLogsByDate(
    String userId,
    String date,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'user_id = ? AND review_date = ?',
      whereArgs: [userId, date],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => WordAttemptLog.fromMap(maps[i]));
  }

  Future<List<WordAttemptLog>> getAllAttemptLogs(String userId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'review_date DESC',
    );
    return List.generate(maps.length, (i) => WordAttemptLog.fromMap(maps[i]));
  }

  // ============ Cleanup Operations ============

  Future<void> deleteWordReviewPlan(String word) async {
    final db = await database;
    // Delete associated review dates and attempts
    await db.delete('word_review_dates', where: 'word = ?', whereArgs: [word]);
    await db.delete('word_attempt_logs', where: 'word = ?', whereArgs: [word]);
    // Delete the plan itself
    await db.delete('word_review_plans', where: 'word = ?', whereArgs: [word]);
  }

  Future<void> deleteAllReviewData() async {
    final db = await database;
    await db.delete('word_attempt_logs');
    await db.delete('word_review_dates');
    await db.delete('word_review_plans');
  }
}
