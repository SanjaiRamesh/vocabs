import '../models/word_list.dart';
import 'database_helper.dart';

class WordListService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> init() async {
    // Initialize database - no need for adapters with SQLite
    await _databaseHelper.database;
  }

  static Future<List<WordList>> getAllWordLists() async {
    return await _databaseHelper.getAllWordLists();
  }

  static Future<List<WordList>> getWordListsBySubject(String subject) async {
    return await _databaseHelper.getWordListsBySubject(subject);
  }

  static Future<WordList?> getWordListById(String id) async {
    return await _databaseHelper.getWordListById(id);
  }

  static Future<void> saveWordList(WordList wordList) async {
    wordList.updatedAt = DateTime.now();
    final existingWordList = await _databaseHelper.getWordListById(wordList.id);

    if (existingWordList != null) {
      await _databaseHelper.updateWordList(wordList);
    } else {
      await _databaseHelper.insertWordList(wordList);
    }
  }

  static Future<void> deleteWordList(String id) async {
    await _databaseHelper.deleteWordList(id);
  }

  static Future<void> deleteSubject(String subject) async {
    // Delete all word lists for this subject
    await _databaseHelper.deleteWordListsBySubject(subject);

    // Delete all word attempts for this subject
    await _databaseHelper.deleteWordAttemptsBySubject(subject);

    // Delete all assessment results for this subject
    await _databaseHelper.deleteAssessmentResultsBySubject(subject);

    // Delete all word schedules for words in this subject
    await _databaseHelper.deleteWordSchedulesBySubject(subject);
  }

  static Future<void> renameSubject(String oldName, String newName) async {
    await _databaseHelper.renameSubject(oldName, newName);
  }

  static Future<void> createDefaultWordLists() async {
    // Create some default word lists if none exist
    final existingLists = await getAllWordLists();

    if (existingLists.isEmpty) {
      final defaultLists = [
        WordList(
          id: 'english_v1',
          subject: 'English',
          listName: 'V1 - Basic Words',
          words: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how'],
        ),
        WordList(
          id: 'english_v2',
          subject: 'English',
          listName: 'V2 - Common Words',
          words: ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all'],
        ),
        WordList(
          id: 'science_lesson1',
          subject: 'Science',
          listName: 'Lesson 1 - Basic Science',
          words: ['atom', 'cell', 'energy', 'matter', 'force', 'light'],
        ),
        WordList(
          id: 'math_numbers',
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

  static Future<List<String>> getAvailableSubjects() async {
    return await _databaseHelper.getAvailableSubjects();
  }
}
