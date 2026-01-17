class WordAttemptLog {
  String userId;
  String word;
  String reviewDate; // YYYY-MM-DD, the review date this attempt is for
  String result; // "correct" or "incorrect"
  String timestamp; // ISO8601 timestamp for uniqueness
  String heardOrTyped; // What the child actually heard or typed

  WordAttemptLog({
    required this.userId,
    required this.word,
    required this.reviewDate,
    required this.result,
    required this.heardOrTyped,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'word': word,
      'review_date': reviewDate,
      'result': result,
      'timestamp': timestamp,
      'heard_or_typed': heardOrTyped,
    };
  }

  factory WordAttemptLog.fromMap(Map<String, dynamic> map) {
    return WordAttemptLog(
      userId: map['user_id'],
      word: map['word'],
      reviewDate: map['review_date'],
      result: map['result'],
      heardOrTyped: map['heard_or_typed'],
      timestamp: map['timestamp'],
    );
  }

  @override
  String toString() {
    return 'WordAttemptLog(userId: $userId, word: $word, reviewDate: $reviewDate, result: $result)';
  }
}
