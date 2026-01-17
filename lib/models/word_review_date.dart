class WordReviewDate {
  String userId;
  String word;
  String reviewDate; // YYYY-MM-DD, the date this review is scheduled
  int stepIndex; // 0-17, position in the fixed schedule

  WordReviewDate({
    required this.userId,
    required this.word,
    required this.reviewDate,
    required this.stepIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'word': word,
      'review_date': reviewDate,
      'step_index': stepIndex,
    };
  }

  factory WordReviewDate.fromMap(Map<String, dynamic> map) {
    return WordReviewDate(
      userId: map['user_id'],
      word: map['word'],
      reviewDate: map['review_date'],
      stepIndex: map['step_index'],
    );
  }

  @override
  String toString() {
    return 'WordReviewDate(userId: $userId, word: $word, reviewDate: $reviewDate, step: $stepIndex)';
  }
}
