import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/reading_assessment_result.dart';

/// Service for managing reading assessment results using SQLite
class AssessmentResultService {
  static Database? _database;
  static const String tableName = 'assessment_results';

  /// Initialize the database
  static Future<void> init() async {
    if (_database != null) return;

    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'assessment_results.db');

      _database = await openDatabase(path, version: 1, onCreate: _createTable);
    } catch (e) {
      print('Error initializing assessment database: $e');
      rethrow;
    }
  }

  /// Create the assessment results table
  static Future<void> _createTable(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        book_title TEXT NOT NULL,
        target_sentence TEXT NOT NULL,
        spoken_transcript TEXT NOT NULL,
        assessment_time TEXT NOT NULL,
        total_reading_time_ms INTEGER NOT NULL,
        total_words INTEGER NOT NULL,
        correct_words INTEGER NOT NULL,
        accuracy_percentage REAL NOT NULL,
        words_per_minute REAL NOT NULL,
        word_assessments TEXT NOT NULL,
        overall_passed INTEGER NOT NULL,
        feedback TEXT NOT NULL,
        level TEXT NOT NULL,
        fluency_score REAL NOT NULL,
        comprehension_score REAL NOT NULL,
        areas_for_improvement TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute('''
      CREATE INDEX idx_book_id ON $tableName (book_id)
    ''');
    await db.execute('''
      CREATE INDEX idx_assessment_time ON $tableName (assessment_time)
    ''');
  }

  /// Get the database instance
  static Future<Database> get database async {
    if (_database == null) {
      await init();
    }
    return _database!;
  }

  /// Save an assessment result
  static Future<void> saveResult(
    ReadingAssessmentResult result, {
    required String bookId,
    required String bookTitle,
  }) async {
    try {
      final db = await database;
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      await db.insert(tableName, {
        'id': id,
        'book_id': bookId,
        'book_title': bookTitle,
        'target_sentence': result.targetSentence,
        'spoken_transcript': result.spokenTranscript,
        'assessment_time': result.assessmentTime.toIso8601String(),
        'total_reading_time_ms': result.totalReadingTime.inMilliseconds,
        'total_words': result.totalWords,
        'correct_words': result.correctWords,
        'accuracy_percentage': result.accuracyPercentage,
        'words_per_minute': result.wordsPerMinute,
        'word_assessments': jsonEncode(
          result.wordAssessments.map((w) => w.toJson()).toList(),
        ),
        'overall_passed': result.overallPassed ? 1 : 0,
        'feedback': result.feedback,
        'level': result.level.toString(),
        'fluency_score': result.fluencyScore,
        'comprehension_score': result.comprehensionScore,
        'areas_for_improvement': jsonEncode(result.areasForImprovement),
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error saving assessment result: $e');
      rethrow;
    }
  }

  /// Get all assessment results
  static Future<List<Map<String, dynamic>>> getAllResults() async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        orderBy: 'assessment_time DESC',
      );
      return results;
    } catch (e) {
      print('Error getting all assessment results: $e');
      return [];
    }
  }

  /// Get assessment results for a specific book
  static Future<List<Map<String, dynamic>>> getResultsByBook(
    String bookId,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        tableName,
        where: 'book_id = ?',
        whereArgs: [bookId],
        orderBy: 'assessment_time DESC',
      );
      return results;
    } catch (e) {
      print('Error getting assessment results for book: $e');
      return [];
    }
  }

  /// Get recent assessment results (last 30 days)
  static Future<List<Map<String, dynamic>>> getRecentResults() async {
    try {
      final db = await database;
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      final results = await db.query(
        tableName,
        where: 'assessment_time >= ?',
        whereArgs: [thirtyDaysAgo.toIso8601String()],
        orderBy: 'assessment_time DESC',
      );
      return results;
    } catch (e) {
      print('Error getting recent assessment results: $e');
      return [];
    }
  }

  /// Get assessment statistics for a book
  static Future<Map<String, dynamic>> getBookStatistics(String bookId) async {
    try {
      final db = await database;
      final results = await db.rawQuery(
        '''
        SELECT 
          COUNT(*) as total_sessions,
          AVG(accuracy_percentage) as avg_accuracy,
          AVG(words_per_minute) as avg_wpm,
          AVG(fluency_score) as avg_fluency,
          AVG(comprehension_score) as avg_comprehension,
          SUM(CASE WHEN overall_passed = 1 THEN 1 ELSE 0 END) as passed_sessions
        FROM $tableName 
        WHERE book_id = ?
      ''',
        [bookId],
      );

      if (results.isNotEmpty) {
        return results.first;
      }
      return {};
    } catch (e) {
      print('Error getting book statistics: $e');
      return {};
    }
  }

  /// Get overall reading progress statistics
  static Future<Map<String, dynamic>> getOverallStatistics() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_sessions,
          COUNT(DISTINCT book_id) as books_read,
          AVG(accuracy_percentage) as avg_accuracy,
          AVG(words_per_minute) as avg_wpm,
          AVG(fluency_score) as avg_fluency,
          AVG(comprehension_score) as avg_comprehension,
          SUM(CASE WHEN overall_passed = 1 THEN 1 ELSE 0 END) as passed_sessions,
          MIN(assessment_time) as first_session,
          MAX(assessment_time) as last_session
        FROM $tableName
      ''');

      if (results.isNotEmpty) {
        return results.first;
      }
      return {};
    } catch (e) {
      print('Error getting overall statistics: $e');
      return {};
    }
  }

  /// Delete assessment result by ID
  static Future<void> deleteResult(String id) async {
    try {
      final db = await database;
      await db.delete(tableName, where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('Error deleting assessment result: $e');
      rethrow;
    }
  }

  /// Delete all assessment results for a book
  static Future<void> deleteResultsByBook(String bookId) async {
    try {
      final db = await database;
      await db.delete(tableName, where: 'book_id = ?', whereArgs: [bookId]);
    } catch (e) {
      print('Error deleting assessment results for book: $e');
      rethrow;
    }
  }

  /// Clear all assessment results
  static Future<void> clearAllResults() async {
    try {
      final db = await database;
      await db.delete(tableName);
    } catch (e) {
      print('Error clearing all assessment results: $e');
      rethrow;
    }
  }

  /// Convert database row to ReadingAssessmentResult
  static ReadingAssessmentResult fromDatabaseRow(Map<String, dynamic> row) {
    return ReadingAssessmentResult(
      targetSentence: row['target_sentence'] ?? '',
      spokenTranscript: row['spoken_transcript'] ?? '',
      assessmentTime: DateTime.parse(row['assessment_time']),
      totalReadingTime: Duration(
        milliseconds: row['total_reading_time_ms'] ?? 0,
      ),
      totalWords: row['total_words'] ?? 0,
      correctWords: row['correct_words'] ?? 0,
      accuracyPercentage: (row['accuracy_percentage'] ?? 0.0).toDouble(),
      wordsPerMinute: (row['words_per_minute'] ?? 0.0).toDouble(),
      wordAssessments: (jsonDecode(row['word_assessments'] ?? '[]') as List)
          .map((w) => WordAssessment.fromJson(w))
          .toList(),
      overallPassed: (row['overall_passed'] ?? 0) == 1,
      feedback: row['feedback'] ?? '',
      level: AssessmentLevel.values.firstWhere(
        (l) => l.toString() == row['level'],
        orElse: () => AssessmentLevel.beginner,
      ),
      fluencyScore: (row['fluency_score'] ?? 0.0).toDouble(),
      comprehensionScore: (row['comprehension_score'] ?? 0.0).toDouble(),
      areasForImprovement: List<String>.from(
        jsonDecode(row['areas_for_improvement'] ?? '[]'),
      ),
    );
  }

  /// Generate sample assessment data for testing
  static Future<void> generateSampleData() async {
    final sampleResults = [
      ReadingAssessmentResult.fromBasicAssessment(
        targetSentence: "The quick brown fox jumps over the lazy dog",
        spokenTranscript: "The quick brown fox jumps over the lazy dog",
        speechStartTime: DateTime.now().subtract(const Duration(minutes: 5)),
        speechEndTime: DateTime.now().subtract(const Duration(minutes: 4)),
      ),
      ReadingAssessmentResult.fromBasicAssessment(
        targetSentence: "Mary had a little lamb whose fleece was white as snow",
        spokenTranscript:
            "Mary had a little lamb whose fleece was white as snow",
        speechStartTime: DateTime.now().subtract(const Duration(hours: 2)),
        speechEndTime: DateTime.now().subtract(
          const Duration(hours: 2, minutes: -1),
        ),
      ),
      ReadingAssessmentResult.fromBasicAssessment(
        targetSentence: "Once upon a time in a land far away",
        spokenTranscript: "Once upon a time in a land far away",
        speechStartTime: DateTime.now().subtract(const Duration(days: 1)),
        speechEndTime: DateTime.now().subtract(
          const Duration(days: 1, minutes: -2),
        ),
      ),
    ];

    for (int i = 0; i < sampleResults.length; i++) {
      await saveResult(
        sampleResults[i],
        bookId: 'sample_book_${i + 1}',
        bookTitle: 'Sample Book ${i + 1}',
      );
    }
  }
}
