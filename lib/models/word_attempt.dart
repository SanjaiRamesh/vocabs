class WordAttempt {
  String userId; // Firebase Auth UID - owner of this attempt
  String word;
  String date; // YYYY-MM-DD format
  String result; // "correct", "incorrect", "missed"
  String type; // "auditory", "visual"
  int repetitionStep; // 0-7 for spaced repetition
  String subject;
  String listName;
  String heardOrTyped; // What the child actually heard or typed
  String timestamp; // ISO8601 timestamp for uniqueness

  WordAttempt({
    required this.userId,
    required this.word,
    required this.date,
    required this.result,
    required this.type,
    required this.repetitionStep,
    required this.subject,
    required this.listName,
    required this.heardOrTyped,
    String? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  String get compoundKey => '${word}_$date';
  String get id => '${word}_${date}_$timestamp';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'word': word,
      'date': date,
      'result': result,
      'type': type,
      'repetition_step': repetitionStep,
      'subject': subject,
      'list_name': listName,
      'heard_or_typed': heardOrTyped,
      'timestamp': timestamp,
    };
  }

  factory WordAttempt.fromMap(Map<String, dynamic> map) {
    return WordAttempt(
      userId: map['user_id'] ?? '',
      word: map['word'],
      date: map['date'],
      result: map['result'],
      type: map['type'],
      repetitionStep: map['repetition_step'],
      subject: map['subject'],
      listName: map['list_name'],
      heardOrTyped: map['heard_or_typed'],
      timestamp: map['timestamp'],
    );
  }

  @override
  String toString() {
    return 'WordAttempt(word: $word, date: $date, result: $result, type: $type, repetitionStep: $repetitionStep)';
  }
}

enum AttemptResult { correct, incorrect, missed }

enum PracticeType { auditory, visual }
