class WordSchedule {
  String userId;
  String word;
  int repetitionStep; // 0-7 index into schedule array
  String lastReviewDate; // YYYY-MM-DD
  String nextReviewDate; // YYYY-MM-DD
  int incorrectCount; // Counter for failed attempts
  bool isHard; // Marked after 3 failures

  WordSchedule({
    required this.userId,
    required this.word,
    required this.repetitionStep,
    required this.lastReviewDate,
    required this.nextReviewDate,
    required this.incorrectCount,
    required this.isHard,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'word': word,
      'repetition_step': repetitionStep,
      'last_review_date': lastReviewDate,
      'next_review_date': nextReviewDate,
      'incorrect_count': incorrectCount,
      'is_hard': isHard ? 1 : 0,
    };
  }

  factory WordSchedule.fromMap(Map<String, dynamic> map) {
    return WordSchedule(
      userId: map['user_id'],
      word: map['word'],
      repetitionStep: map['repetition_step'],
      lastReviewDate: map['last_review_date'],
      nextReviewDate: map['next_review_date'],
      incorrectCount: map['incorrect_count'],
      isHard: map['is_hard'] == 1,
    );
  }

  @override
  String toString() {
    return 'WordSchedule(userId: $userId, word: $word, repetitionStep: $repetitionStep, lastReviewDate: $lastReviewDate, nextReviewDate: $nextReviewDate, incorrectCount: $incorrectCount, isHard: $isHard)';
  }
}
