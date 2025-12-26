class WordReviewDate {
  String word;
  String reviewDate; // YYYY-MM-DD, the date this review is scheduled
  int stepIndex; // 0-17, position in the fixed schedule

  WordReviewDate({
    required this.word,
    required this.reviewDate,
    required this.stepIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'review_date': reviewDate,
      'step_index': stepIndex,
    };
  }

  factory WordReviewDate.fromMap(Map<String, dynamic> map) {
    return WordReviewDate(
      word: map['word'],
      reviewDate: map['review_date'],
      stepIndex: map['step_index'],
    );
  }

  @override
  String toString() {
    return 'WordReviewDate(word: $word, reviewDate: $reviewDate, step: $stepIndex)';
  }
}
