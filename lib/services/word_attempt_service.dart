import '../models/word_attempt.dart';
import 'database_helper.dart';
import 'firestore_word_attempt_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger.dart';

class WordAttemptService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();
  static final FirestoreWordAttemptService _firestoreService =
      FirestoreWordAttemptService();

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

    // Ensure userId is set from current user if not already set
    if (attempt.userId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        attempt.userId = user.uid;
      }
    }

    // SQLite insert (source of truth)
    await _databaseHelper.insertWordAttempt(attempt);

    // Firestore sync (best effort, non-blocking)
    try {
      final studentId = await _getStudentId();
      await _firestoreService.logAttempt(studentId, attempt);
    } catch (e) {
      // Log Firestore failures but don't break the app
      logDebug('Firestore sync failed for attempt ${attempt.id}: $e');
    }
  }

  /// Gets the current student ID for Firestore storage.
  /// Uses Firebase Auth user UID if available, otherwise falls back to placeholder.
  static Future<String> _getStudentId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return user.uid;
    }

    // TODO: Implement fallback logic for unauthenticated users
    // For now, return a placeholder that can be replaced later
    return 'local_student';
  }

  static Future<List<WordAttempt>> getAllAttempts(String userId) async {
    if (kIsWeb) {
      return _webAttempts.where((a) => a.userId == userId).toList();
    }
    return await _databaseHelper.getAllWordAttempts(userId);
  }

  static Future<List<WordAttempt>> getAttemptsBySubject(
    String userId,
    String subject,
  ) async {
    if (kIsWeb) {
      return _webAttempts
          .where((a) => a.userId == userId && a.subject == subject)
          .toList();
    }
    return await _databaseHelper.getWordAttemptsBySubject(userId, subject);
  }

  static Future<List<WordAttempt>> getAttemptsByWordList(
    String userId,
    String subject,
    String listName,
  ) async {
    final allAttempts = await getAllAttempts(userId);
    return allAttempts
        .where(
          (attempt) =>
              attempt.subject == subject && attempt.listName == listName,
        )
        .toList();
  }

  static Future<List<WordAttempt>> getAttemptsByDate(
    String userId,
    String date,
  ) async {
    final allAttempts = await getAllAttempts(userId);
    return allAttempts.where((attempt) => attempt.date == date).toList();
  }

  static Future<List<WordAttempt>> getAttemptsByWordAndDate(
    String userId,
    String word,
    String date,
  ) async {
    if (kIsWeb) {
      return _webAttempts
          .where((a) => a.userId == userId && a.word == word && a.date == date)
          .toList();
    }
    return await _databaseHelper.getWordAttemptsByWordAndDate(
      userId,
      word,
      date,
    );
  }

  static Future<WordAttempt?> getLastAttemptByWordAndDate(
    String userId,
    String word,
    String date,
  ) async {
    final attempts = await getAttemptsByWordAndDate(userId, word, date);
    if (attempts.isEmpty) return null;

    // Sort by timestamp (newest first)
    attempts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return attempts.first;
  }

  static Future<Map<String, dynamic>> getProgressStats(
    String userId,
    String subject,
  ) async {
    final attempts = await getAttemptsBySubject(userId, subject);

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
  static Future<void> generateSampleData(String userId) async {
    final sampleAttempts = [
      // English V1 attempts
      WordAttempt(
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
        userId: userId,
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
