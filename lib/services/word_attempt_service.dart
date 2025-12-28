import '../models/word_attempt.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WordAttemptService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // In-memory storage for web platform
  static final List<WordAttempt> _webAttempts = [];

  static Future<void> init() async {
    if (kIsWeb) {
      return; // Web doesn't support SQLite
    }
    // Initialize database - no need for adapters with SQLite
    await _databaseHelper.database;
  }

  static Future<void> saveAttempt(WordAttempt attempt) async {
    if (kIsWeb) {
      _webAttempts.add(attempt);
      return;
    }
    await _databaseHelper.insertWordAttempt(attempt);
  }

  static Future<List<WordAttempt>> getAllAttempts() async {
    if (kIsWeb) return List.from(_webAttempts);
    return await _databaseHelper.getAllWordAttempts();
  }

  static Future<List<WordAttempt>> getAttemptsBySubject(String subject) async {
    if (kIsWeb) {
      return _webAttempts.where((a) => a.subject == subject).toList();
    }
    return await _databaseHelper.getWordAttemptsBySubject(subject);
  }

  static Future<List<WordAttempt>> getAttemptsByWordList(
    String subject,
    String listName,
  ) async {
    final allAttempts = await getAllAttempts();
    return allAttempts
        .where(
          (attempt) =>
              attempt.subject == subject && attempt.listName == listName,
        )
        .toList();
  }

  static Future<List<WordAttempt>> getAttemptsByDate(String date) async {
    final allAttempts = await getAllAttempts();
    return allAttempts.where((attempt) => attempt.date == date).toList();
  }

  static Future<List<WordAttempt>> getAttemptsByWordAndDate(
    String word,
    String date,
  ) async {
    if (kIsWeb) {
      return _webAttempts
          .where((a) => a.word == word && a.date == date)
          .toList();
    }
    return await _databaseHelper.getWordAttemptsByWordAndDate(word, date);
  }

  static Future<WordAttempt?> getLastAttemptByWordAndDate(
    String word,
    String date,
  ) async {
    final attempts = await getAttemptsByWordAndDate(word, date);
    if (attempts.isEmpty) return null;

    // Sort by timestamp (newest first)
    attempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return attempts.first;
  }

  static Future<Map<String, dynamic>> getProgressStats(String subject) async {
    final attempts = await getAttemptsBySubject(subject);

    int totalAttempts = attempts.length;
    int correctAttempts = attempts.where((a) => a.result == 'correct').length;
    int incorrectAttempts = attempts
        .where((a) => a.result == 'incorrect')
        .length;
    int missedAttempts = attempts.where((a) => a.result == 'missed').length;

    double accuracy = totalAttempts > 0
        ? (correctAttempts / totalAttempts) * 100
        : 0;

    return {
      'totalAttempts': totalAttempts,
      'correctAttempts': correctAttempts,
      'incorrectAttempts': incorrectAttempts,
      'missedAttempts': missedAttempts,
      'accuracy': accuracy,
    };
  }

  static Future<void> clearAllAttempts() async {
    await _databaseHelper.clearAllData();
  }

  // Helper method to generate sample data for testing
  static Future<void> generateSampleData() async {
    final sampleAttempts = [
      // English V1 attempts
      WordAttempt(
        word: 'find',
        date: '2025-01-10',
        result: 'correct',
        type: 'auditory',
        repetitionStep: 0,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: 'find',
      ),
      WordAttempt(
        word: 'find',
        date: '2025-01-11',
        result: 'correct',
        type: 'visual',
        repetitionStep: 1,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: 'find',
      ),
      WordAttempt(
        word: 'find',
        date: '2025-01-13',
        result: 'incorrect',
        type: 'auditory',
        repetitionStep: 2,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: 'fond',
      ),
      WordAttempt(
        word: 'put',
        date: '2025-01-10',
        result: 'correct',
        type: 'auditory',
        repetitionStep: 0,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: 'put',
      ),
      WordAttempt(
        word: 'put',
        date: '2025-01-11',
        result: 'missed',
        type: 'visual',
        repetitionStep: 1,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: '',
      ),
      WordAttempt(
        word: 'what',
        date: '2025-01-10',
        result: 'correct',
        type: 'visual',
        repetitionStep: 0,
        subject: 'English',
        listName: 'V1 - Basic Words',
        heardOrTyped: 'what',
      ),
      // Math attempts
      WordAttempt(
        word: 'one',
        date: '2025-01-09',
        result: 'correct',
        type: 'auditory',
        repetitionStep: 0,
        subject: 'Math',
        listName: 'Numbers',
        heardOrTyped: 'one',
      ),
      WordAttempt(
        word: 'one',
        date: '2025-01-10',
        result: 'correct',
        type: 'visual',
        repetitionStep: 1,
        subject: 'Math',
        listName: 'Numbers',
        heardOrTyped: 'one',
      ),
      WordAttempt(
        word: 'two',
        date: '2025-01-09',
        result: 'incorrect',
        type: 'auditory',
        repetitionStep: 0,
        subject: 'Math',
        listName: 'Numbers',
        heardOrTyped: 'too',
      ),
      // Science attempts
      WordAttempt(
        word: 'atom',
        date: '2025-01-08',
        result: 'correct',
        type: 'visual',
        repetitionStep: 0,
        subject: 'Science',
        listName: 'Lesson 1 - Basic Science',
        heardOrTyped: 'atom',
      ),
      WordAttempt(
        word: 'atom',
        date: '2025-01-09',
        result: 'correct',
        type: 'auditory',
        repetitionStep: 1,
        subject: 'Science',
        listName: 'Lesson 1 - Basic Science',
        heardOrTyped: 'atom',
      ),
      WordAttempt(
        word: 'cell',
        date: '2025-01-08',
        result: 'missed',
        type: 'visual',
        repetitionStep: 0,
        subject: 'Science',
        listName: 'Lesson 1 - Basic Science',
        heardOrTyped: '',
      ),
    ];

    for (final attempt in sampleAttempts) {
      await saveAttempt(attempt);
    }
  }
}
