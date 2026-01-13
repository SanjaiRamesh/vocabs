// For mobile
import 'package:sqflite_common_ffi/sqflite_ffi.dart'; // For desktop
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      version: 4, // Increased version to trigger upgrade
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
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
        subject TEXT NOT NULL,
        list_name TEXT NOT NULL,
        words TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create word_attempts table
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

    // Create word_schedules table
    await db.execute('''
      CREATE TABLE word_schedules (
        word TEXT PRIMARY KEY,
        repetition_step INTEGER NOT NULL,
        last_review_date TEXT NOT NULL,
        next_review_date TEXT NOT NULL,
        incorrect_count INTEGER NOT NULL
      )
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
        word TEXT PRIMARY KEY,
        anchor_date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create word_review_dates table (all precomputed review dates)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_review_dates (
        word TEXT NOT NULL,
        review_date TEXT NOT NULL,
        step_index INTEGER NOT NULL,
        PRIMARY KEY (word, review_date),
        FOREIGN KEY (word) REFERENCES word_review_plans(word)
      )
    ''');

    // Create word_attempt_logs table (simplified attempt logging)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS word_attempt_logs (
        word TEXT NOT NULL,
        review_date TEXT NOT NULL,
        result TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        heard_or_typed TEXT NOT NULL,
        PRIMARY KEY (word, review_date),
        FOREIGN KEY (word) REFERENCES word_review_plans(word)
      )
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

  Future<List<WordList>> getAllWordLists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('word_lists');
    return List.generate(maps.length, (i) => WordList.fromMap(maps[i]));
  }

  Future<List<WordList>> getWordListsBySubject(String subject) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      where: 'subject = ?',
      whereArgs: [subject],
    );
    return List.generate(maps.length, (i) => WordList.fromMap(maps[i]));
  }

  Future<WordList?> getWordListById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      where: 'id = ?',
      whereArgs: [id],
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
      where: 'id = ?',
      whereArgs: [wordList.id],
    );
  }

  Future<void> deleteWordList(String id) async {
    final db = await database;
    await db.delete('word_lists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWordListsBySubject(String subject) async {
    final db = await database;
    await db.delete('word_lists', where: 'subject = ?', whereArgs: [subject]);
  }

  Future<void> deleteWordAttemptsBySubject(String subject) async {
    final db = await database;
    await db.delete(
      'word_attempts',
      where: 'subject = ?',
      whereArgs: [subject],
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

  Future<List<String>> getAvailableSubjects() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_lists',
      columns: ['subject'],
      distinct: true,
    );
    return maps.map((map) => map['subject'] as String).toList();
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

  Future<List<WordAttempt>> getAllWordAttempts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('word_attempts');
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  Future<List<WordAttempt>> getWordAttemptsBySubject(String subject) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempts',
      where: 'subject = ?',
      whereArgs: [subject],
    );
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  Future<List<WordAttempt>> getWordAttemptsByWordAndDate(
    String word,
    String date,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempts',
      where: 'word = ? AND date = ?',
      whereArgs: [word, date],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => WordAttempt.fromMap(maps[i]));
  }

  // Word Schedules operations
  Future<void> insertWordSchedule(WordSchedule schedule) async {
    final db = await database;
    await db.insert(
      'word_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WordSchedule?> getWordSchedule(String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_schedules',
      where: 'word = ?',
      whereArgs: [word],
    );
    if (maps.isNotEmpty) {
      return WordSchedule.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordSchedule>> getWordsForReview(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_schedules',
      where: 'next_review_date <= ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => WordSchedule.fromMap(maps[i]));
  }

  Future<List<WordSchedule>> getAllWordSchedules() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('word_schedules');
    return List.generate(maps.length, (i) => WordSchedule.fromMap(maps[i]));
  }

  Future<void> updateWordSchedule(WordSchedule schedule) async {
    final db = await database;
    await db.update(
      'word_schedules',
      schedule.toMap(),
      where: 'word = ?',
      whereArgs: [schedule.word],
    );
  }

  Future<void> deleteWordSchedule(String word) async {
    final db = await database;
    await db.delete('word_schedules', where: 'word = ?', whereArgs: [word]);
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

  // ============ Word Review Plan Operations ============

  Future<void> insertWordReviewPlan(WordReviewPlan plan) async {
    final db = await database;
    await db.insert(
      'word_review_plans',
      plan.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<WordReviewPlan?> getWordReviewPlan(String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_plans',
      where: 'word = ?',
      whereArgs: [word],
    );
    if (maps.isNotEmpty) {
      return WordReviewPlan.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordReviewPlan>> getAllWordReviewPlans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('word_review_plans');
    return List.generate(maps.length, (i) => WordReviewPlan.fromMap(maps[i]));
  }

  // ============ Word Review Date Operations ============

  Future<void> insertWordReviewDates(
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

  Future<List<WordReviewDate>> getWordReviewDates(String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      where: 'word = ?',
      whereArgs: [word],
      orderBy: 'step_index ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  Future<List<WordReviewDate>> getWordsWithReviewDue(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      where: 'review_date = ?',
      whereArgs: [date],
      orderBy: 'step_index ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  Future<List<WordReviewDate>> getAllReviewDates() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_review_dates',
      orderBy: 'review_date ASC',
    );
    return List.generate(maps.length, (i) => WordReviewDate.fromMap(maps[i]));
  }

  // ============ Word Attempt Log Operations ============

  Future<void> insertWordAttemptLog(WordAttemptLog attempt) async {
    final db = await database;
    await db.insert(
      'word_attempt_logs',
      attempt.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore duplicate attempts
    );
  }

  Future<WordAttemptLog?> getAttemptForReviewDate(
    String word,
    String reviewDate,
  ) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'word = ? AND review_date = ?',
      whereArgs: [word, reviewDate],
    );
    if (maps.isNotEmpty) {
      return WordAttemptLog.fromMap(maps.first);
    }
    return null;
  }

  Future<List<WordAttemptLog>> getWordAttemptLogs(String word) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'word = ?',
      whereArgs: [word],
      orderBy: 'review_date ASC',
    );
    return List.generate(maps.length, (i) => WordAttemptLog.fromMap(maps[i]));
  }

  Future<List<WordAttemptLog>> getAttemptLogsByDate(String date) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
      where: 'review_date = ?',
      whereArgs: [date],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => WordAttemptLog.fromMap(maps[i]));
  }

  Future<List<WordAttemptLog>> getAllAttemptLogs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'word_attempt_logs',
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
