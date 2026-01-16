import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/word_attempt.dart';

/// Service for logging word attempts to Cloud Firestore.
///
/// This service DOES NOT replace SQLite storage - it works alongside it
/// to provide cloud sync capabilities for word attempts.
///
/// Uses explicit document IDs (attempt.id) to prevent duplicates and
/// ensure idempotent writes that are safe for offline/retry scenarios.
class FirestoreWordAttemptService {
  final FirebaseFirestore _firestore;

  /// Creates a FirestoreWordAttemptService.
  ///
  /// Optionally accepts a [FirebaseFirestore] instance for testing.
  /// Defaults to [FirebaseFirestore.instance].
  FirestoreWordAttemptService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Logs a word attempt to Firestore for a specific student.
  ///
  /// Firestore path: `users/{studentId}/attempts/{attempt.id}`
  ///
  /// Uses the attempt's ID (word_date_timestamp) as the document ID
  /// to ensure idempotent writes. Multiple calls with the same attempt
  /// will update the same document, making this safe for retries.
  ///
  /// Adds two timestamp fields:
  /// - `ts`: Firestore Timestamp from device (attempt.timestamp)
  /// - `server_ts`: Server-generated timestamp (useful if device time is wrong)
  ///
  /// Parameters:
  /// - [studentId]: The unique identifier for the student
  /// - [attempt]: The WordAttempt to log
  ///
  /// Throws:
  /// - FirebaseException if Firestore operation fails
  /// - Any parsing errors from DateTime.parse
  ///
  /// Example:
  /// ```dart
  /// final service = FirestoreWordAttemptService();
  /// await service.logAttempt('student123', attempt);
  /// ```
  Future<void> logAttempt(String studentId, WordAttempt attempt) async {
    // Convert attempt to map
    final data = attempt.toMap();

    // Add Firestore Timestamp field from device's ISO8601 timestamp string
    final timestamp = DateTime.parse(attempt.timestamp);
    data['ts'] = Timestamp.fromDate(timestamp);

    // Add server-generated timestamp (useful if device time is wrong)
    data['server_ts'] = FieldValue.serverTimestamp();

    // Write to Firestore using explicit document ID
    // Path: users/{studentId}/attempts/{attempt.id}
    await _firestore
        .collection('users')
        .doc(studentId)
        .collection('attempts')
        .doc(attempt.id) // ✅ Uses attempt.id, NOT auto-generated ID
        .set(data, SetOptions(merge: true));
  }
}
