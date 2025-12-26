class WordReviewPlan {
  String word;
  String anchorDate; // YYYY-MM-DD, the first practice date
  String createdAt; // ISO8601 timestamp

  WordReviewPlan({
    required this.word,
    required this.anchorDate,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'anchor_date': anchorDate,
      'created_at': createdAt,
    };
  }

  factory WordReviewPlan.fromMap(Map<String, dynamic> map) {
    return WordReviewPlan(
      word: map['word'],
      anchorDate: map['anchor_date'],
      createdAt: map['created_at'],
    );
  }

  @override
  String toString() {
    return 'WordReviewPlan(word: $word, anchorDate: $anchorDate)';
  }
}
