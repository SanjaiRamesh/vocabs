import '../models/word_schedule.dart';
import '../services/word_attempt_service.dart';
import 'database_helper.dart';

class SpacedRepetitionService {
  // Fixed schedule: [1, 2, 4, 8, 16, 30, 60, 150] days
  static const List<int> _schedule = [1, 2, 4, 8, 16, 30, 60, 150];
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  static Future<void> init() async {
    // Initialize database - no need for adapters with SQLite
    await _databaseHelper.database;
  }

  static Future<void> updateWordSchedule(String word, bool isCorrect) async {
    final today = DateTime.now().toIso8601String().split('T')[0];

    // Get existing schedule or create new one
    WordSchedule schedule =
        await getWordSchedule(word) ??
        WordSchedule(
          word: word,
          repetitionStep: 0,
          lastReviewDate: today,
          nextReviewDate: _calculateNextReviewDate(today, 0),
          incorrectCount: 0,
          isHard: false,
        );

    if (isCorrect) {
      // After correct response: advance to next repetition step
      if (schedule.repetitionStep < _schedule.length - 1) {
        schedule.repetitionStep++;
      }
    } else {
      // After incorrect: reset to next day, increment incorrect count
      schedule.repetitionStep = 0;
      schedule.incorrectCount++;

      // After 3 incorrect attempts: mark as hard word
      if (schedule.incorrectCount >= 3) {
        schedule.isHard = true;
        await WordAttemptService.markWordAsHard(word, '');
      }
    }

    schedule.lastReviewDate = today;
    schedule.nextReviewDate = _calculateNextReviewDate(
      today,
      schedule.repetitionStep,
    );

    await _databaseHelper.insertWordSchedule(schedule);
  }

  static Future<WordSchedule?> getWordSchedule(String word) async {
    return await _databaseHelper.getWordSchedule(word);
  }

  static Future<List<WordSchedule>> getWordsForReview(String date) async {
    return await _databaseHelper.getWordsForReview(date);
  }

  static Future<List<WordSchedule>> getHardWords() async {
    return await _databaseHelper.getHardWordsSchedules();
  }

  static Future<List<WordSchedule>> getAllSchedules() async {
    return await _databaseHelper.getAllWordSchedules();
  }

  static String _calculateNextReviewDate(
    String currentDate,
    int repetitionStep,
  ) {
    if (repetitionStep >= _schedule.length) {
      repetitionStep = _schedule.length - 1;
    }

    final days = _schedule[repetitionStep];
    return _addDaysToDate(currentDate, days);
  }

  static String _addDaysToDate(String dateString, int days) {
    final date = DateTime.parse(dateString);
    final newDate = date.add(Duration(days: days));
    return newDate.toIso8601String().split('T')[0];
  }
}
