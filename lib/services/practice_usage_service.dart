import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

class PracticeUsageService {
  static final PracticeUsageService _instance =
      PracticeUsageService._internal();
  factory PracticeUsageService() => _instance;
  PracticeUsageService._internal();

  Future<void> addOrUpdatePracticeTime(
    String date,
    String userLocalId,
    int seconds,
  ) async {
    final db = await DatabaseHelper().database;
    // Try update first
    int count = await db.update(
      'practice_usage_daily',
      {'practice_time_sec': seconds},
      where: 'date = ? AND user_local_id = ?',
      whereArgs: [date, userLocalId],
    );
    if (count == 0) {
      // Insert if not exists
      await db.insert('practice_usage_daily', {
        'date': date,
        'user_local_id': userLocalId,
        'practice_time_sec': seconds,
        'synced': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<int> getPracticeTime(String date, String userLocalId) async {
    final db = await DatabaseHelper().database;
    final result = await db.query(
      'practice_usage_daily',
      columns: ['practice_time_sec'],
      where: 'date = ? AND user_local_id = ?',
      whereArgs: [date, userLocalId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['practice_time_sec'] as int;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getAllPracticeUsage([
    String? userLocalId,
  ]) async {
    final db = await DatabaseHelper().database;
    if (userLocalId != null) {
      return await db.query(
        'practice_usage_daily',
        where: 'user_local_id = ?',
        whereArgs: [userLocalId],
      );
    }
    return await db.query('practice_usage_daily');
  }
}
