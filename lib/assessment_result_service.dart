import 'assessment_result.dart';
import '../services/database_helper.dart';
import 'package:flutter/material.dart';

class AssessmentResultService {
  static const String tableName = 'assessment_results';

  // Add a header widget for use in screens
  static PreferredSizeWidget buildHeader(
    BuildContext context, {
    String title = 'Assessment Results',
    VoidCallback? onHome,
  }) {
    return AppBar(
      backgroundColor: Colors.lightBlue[100],
      elevation: 0,
      title: Text(title, style: const TextStyle(color: Colors.black)),
      actions: [
        IconButton(
          icon: const Icon(Icons.home, color: Colors.black),
          tooltip: 'Back to Home',
          onPressed:
              onHome ??
              () {
                Navigator.of(context).maybePop();
              },
        ),
      ],
      iconTheme: const IconThemeData(color: Colors.black),
    );
  }

  static Future<void> init() async {
    // Database initialization is handled by DatabaseHelper
    await DatabaseHelper().database;
  }

  static Future<void> addResult(AssessmentResult result) async {
    final db = await DatabaseHelper().database;
    await db.insert(tableName, result.toMap());
  }

  static Future<List<AssessmentResult>> getAllResults() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(tableName);
    return maps.map((map) => AssessmentResult.fromMap(map)).toList();
  }

  static Future<void> clearAll() async {
    final db = await DatabaseHelper().database;
    await db.delete(tableName);
  }
}
