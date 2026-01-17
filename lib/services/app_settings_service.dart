import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Database;
import 'database_helper.dart';

/// Simple app settings service backed by SQLite (sqflite).
/// Stores runtime-configurable values like the TTS base URL.
class AppSettingsService {
  static const String _tableName = 'app_settings';
  static const String _colKey = 'key';
  static const String _colValue = 'value';

  static bool _initialized = false;

  /// Initialize the settings table.
  static Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      // Web not supported with sqflite in this project
      debugPrint('AppSettingsService: Web platform not supported');
      _initialized = true;
      return;
    }
    try {
      final db = await DatabaseHelper().database;
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $_colKey TEXT PRIMARY KEY,
          $_colValue TEXT NOT NULL
        )
      ''');
      _initialized = true;
      debugPrint('AppSettingsService (SQLite) initialized');
    } catch (e) {
      debugPrint('Failed to initialize AppSettingsService (SQLite): $e');
      rethrow;
    }
  }

  /// Get the configured base URL (or null if not set).
  static Future<String?> getBaseUrl() async {
    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        _tableName,
        columns: [_colValue],
        where: '$_colKey = ?',
        whereArgs: ['base_url'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final value = rows.first[_colValue];
        return value is String ? value : value?.toString();
      }
      return null;
    } catch (e) {
      debugPrint('Error reading base URL from settings (SQLite): $e');
      return null;
    }
  }

  /// Set (and persist) the base URL.
  static Future<void> setBaseUrl(String url) async {
    try {
      final db = await DatabaseHelper().database;
      await db.insert(_tableName, {
        _colKey: 'base_url',
        _colValue: url.trim(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      debugPrint('Base URL saved (SQLite): $url');
    } catch (e) {
      debugPrint('Error saving base URL to settings (SQLite): $e');
      rethrow;
    }
  }

  /// Clear the base URL setting.
  static Future<void> clearBaseUrl() async {
    try {
      final db = await DatabaseHelper().database;
      await db.delete(
        _tableName,
        where: '$_colKey = ?',
        whereArgs: ['base_url'],
      );
      debugPrint('Base URL cleared (SQLite)');
    } catch (e) {
      debugPrint('Error clearing base URL (SQLite): $e');
    }
  }
}
