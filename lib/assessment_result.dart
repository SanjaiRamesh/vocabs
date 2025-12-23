class AssessmentResult {
  int? id;
  String word;
  String date;
  String result; // 'correct', 'incorrect', 'unclear'
  String heard;
  String listName;
  String subject;

  AssessmentResult({
    this.id,
    required this.word,
    required this.date,
    required this.result,
    required this.heard,
    required this.listName,
    required this.subject,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'word': word,
      'date': date,
      'result': result,
      'heard': heard,
      'listName': listName,
      'subject': subject,
    };
  }

  factory AssessmentResult.fromMap(Map<String, dynamic> map) {
    return AssessmentResult(
      id: map['id'],
      word: map['word'],
      date: map['date'],
      result: map['result'],
      heard: map['heard'],
      listName: map['listName'],
      subject: map['subject'],
    );
  }
}
