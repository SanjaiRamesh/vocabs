import '../models/word_list.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class WordListService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  // In-memory storage for web platform
  static final List<WordList> _webWordLists = [];
  static bool _webInitialized = false;

  static Future<void> init() async {
    if (kIsWeb) {
      // Initialize with default data for web when first user logs in
      // _initWebStorage will be called from createDefaultWordLists
      return;
    }
    // Initialize database - no need for adapters with SQLite
    await _databaseHelper.database;
  }

  static Future<void> _initWebStorage(String userId) async {
    // Add default word lists for web
    _webWordLists.clear();
    _webWordLists.addAll([
      WordList(
        id: 'english_v1',
        userId: userId,
        subject: 'English',
        listName: 'V1 - Basic Words',
        words: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how'],
      ),
      WordList(
        id: 'english_v2',
        userId: userId,
        subject: 'English',
        listName: 'V2 - Common Words',
        words: ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all'],
      ),
      WordList(
        id: 'science_lesson1',
        userId: userId,
        subject: 'Science',
        listName: 'Lesson 1 - Basic Science',
        words: ['atom', 'cell', 'energy', 'matter', 'force', 'light'],
      ),
      WordList(
        id: 'math_numbers',
        userId: userId,
        subject: 'Math',
        listName: 'Numbers',
        words: ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight'],
      ),
    ]);
  }

  static Future<List<WordList>> getAllWordLists(String userId) async {
    if (kIsWeb) {
      return _webWordLists.where((list) => list.userId == userId).toList();
    }
    return await _databaseHelper.getAllWordLists(userId);
  }

  static Future<List<WordList>> getWordListsBySubject(
    String userId,
    String subject,
  ) async {
    if (kIsWeb) {
      return _webWordLists
          .where((list) => list.userId == userId && list.subject == subject)
          .toList();
    }
    return await _databaseHelper.getWordListsBySubject(userId, subject);
  }

  static Future<WordList?> getWordListById(String userId, String id) async {
    if (kIsWeb) {
      try {
        return _webWordLists.firstWhere(
          (list) => list.userId == userId && list.id == id,
        );
      } catch (e) {
        return null;
      }
    }
    return await _databaseHelper.getWordListById(userId, id);
  }

  static Future<void> saveWordList(WordList wordList) async {
    if (kIsWeb) {
      wordList.updatedAt = DateTime.now();
      final index = _webWordLists.indexWhere(
        (list) => list.userId == wordList.userId && list.id == wordList.id,
      );
      if (index != -1) {
        _webWordLists[index] = wordList;
      } else {
        _webWordLists.add(wordList);
      }
      return;
    }
    wordList.updatedAt = DateTime.now();
    final existingWordList = await _databaseHelper.getWordListById(
      wordList.userId,
      wordList.id,
    );

    if (existingWordList != null) {
      await _databaseHelper.updateWordList(wordList);
    } else {
      await _databaseHelper.insertWordList(wordList);
    }
  }

  static Future<void> deleteWordList(String userId, String id) async {
    if (kIsWeb) {
      _webWordLists.removeWhere(
        (list) => list.userId == userId && list.id == id,
      );
      return;
    }
    await _databaseHelper.deleteWordList(userId, id);
  }

  static Future<void> deleteSubject(String userId, String subject) async {
    if (kIsWeb) {
      _webWordLists.removeWhere(
        (list) => list.userId == userId && list.subject == subject,
      );
      return;
    }
    // Delete all word lists for this subject
    await _databaseHelper.deleteWordListsBySubject(userId, subject);

    // Delete all word attempts for this subject
    await _databaseHelper.deleteWordAttemptsBySubject(userId, subject);

    // Delete all assessment results for this subject
    await _databaseHelper.deleteAssessmentResultsBySubject(subject);

    // Delete all word schedules for words in this subject
    await _databaseHelper.deleteWordSchedulesBySubject(subject);
  }

  static Future<void> renameSubject(
    String userId,
    String oldName,
    String newName,
  ) async {
    if (kIsWeb) {
      for (var list in _webWordLists) {
        if (list.userId == userId && list.subject == oldName) {
          list.subject = newName;
          list.updatedAt = DateTime.now();
        }
      }
      return;
    }
    await _databaseHelper.renameSubject(oldName, newName);
  }

  static Future<void> createDefaultWordLists(String userId) async {
    if (kIsWeb) {
      // Initialize web storage if not already done
      if (!_webInitialized) {
        await _initWebStorage(userId);
        _webInitialized = true;
      }
      return;
    }
    // Create some default word lists if none exist for this user
    final existingLists = await getAllWordLists(userId);

    if (existingLists.isEmpty) {
      final defaultLists = [
        WordList(
          id: 'english_v1_${userId}',
          userId: userId,
          subject: 'English',
          listName: 'V1 - Basic Words',
          words: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how'],
        ),
        WordList(
          id: 'english_v2_${userId}',
          userId: userId,
          subject: 'English',
          listName: 'V2 - Common Words',
          words: ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all'],
        ),
        WordList(
          id: 'science_lesson1_${userId}',
          userId: userId,
          subject: 'Science',
          listName: 'Lesson 1 - Basic Science',
          words: ['atom', 'cell', 'energy', 'matter', 'force', 'light'],
        ),
        WordList(
          id: 'math_numbers_${userId}',
          userId: userId,
          subject: 'Math',
          listName: 'Numbers',
          words: [
            'one',
            'two',
            'three',
            'four',
            'five',
            'six',
            'seven',
            'eight',
          ],
        ),
      ];

      for (final wordList in defaultLists) {
        await saveWordList(wordList);
      }
    }
  }

  static Future<List<String>> getAvailableSubjects(String userId) async {
    if (kIsWeb) {
      final subjects = <String>{};
      for (var list in _webWordLists) {
        if (list.userId == userId) {
          subjects.add(list.subject);
        }
      }
      return subjects.toList()..sort();
    }
    return await _databaseHelper.getAvailableSubjects(userId);
  }
}
