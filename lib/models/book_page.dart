import 'dart:convert';

class BookPage {
  String id;
  String title;
  String subject;
  List<String> lines;
  String difficulty; // 'level1', 'high'
  String pageType; // 'text', 'questions', 'mixed'
  String? imagePath;
  DateTime createdAt;
  DateTime updatedAt;
  List<QuestionBlock>? questions;
  String? rawText; // Original OCR text
  String? structuredContent; // Enhanced structured text
  List<String>? sections; // Detected sections
  double? confidence; // OCR confidence score

  BookPage({
    required this.id,
    required this.title,
    required this.subject,
    required this.lines,
    required this.difficulty,
    required this.pageType,
    this.imagePath,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.questions,
    this.rawText,
    this.structuredContent,
    this.sections,
    this.confidence,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'lines': json.encode(lines),
      'difficulty': difficulty,
      'page_type': pageType,
      'image_path': imagePath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'questions': questions != null
          ? json.encode(questions!.map((q) => q.toMap()).toList())
          : null,
      'raw_text': rawText,
      'structured_content': structuredContent,
      'sections': sections != null ? json.encode(sections!) : null,
      'confidence': confidence,
    };
  }

  static BookPage fromMap(Map<String, dynamic> map) {
    List<String> linesList = List<String>.from(
      json.decode(map['lines'] ?? '[]'),
    );
    List<QuestionBlock>? questionsList;
    List<String>? sectionsList;

    if (map['questions'] != null && map['questions'].isNotEmpty) {
      List<dynamic> questionsData = json.decode(map['questions']);
      questionsList = questionsData
          .map((q) => QuestionBlock.fromMap(q))
          .toList();
    }

    if (map['sections'] != null && map['sections'].isNotEmpty) {
      sectionsList = List<String>.from(json.decode(map['sections']));
    }

    return BookPage(
      id: map['id'].toString(),
      title: map['title'],
      subject: map['subject'],
      lines: linesList,
      difficulty: map['difficulty'],
      pageType: map['page_type'],
      imagePath: map['image_path'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      questions: questionsList,
      rawText: map['raw_text'],
      structuredContent: map['structured_content'],
      sections: sectionsList,
      confidence: map['confidence']?.toDouble(),
    );
  }

  @override
  String toString() {
    return 'BookPage{id: $id, title: $title, subject: $subject, lines: ${lines.length}, difficulty: $difficulty, confidence: $confidence}';
  }

  /// Get reading units based on difficulty level
  List<String> getReadingUnits() {
    if (difficulty == 'level1') {
      // Level 1: One section or question at a time
      List<String> readingUnits = [];

      if (questions != null && questions!.isNotEmpty) {
        for (var question in questions!) {
          readingUnits.add(question.combinedText);
        }
      } else {
        // If no structured questions, use lines
        readingUnits.addAll(lines);
      }

      return readingUnits;
    } else {
      // High level: Show structured content or all lines
      if (structuredContent != null && structuredContent!.isNotEmpty) {
        return [structuredContent!];
      } else {
        return [lines.join('\n')];
      }
    }
  }

  /// Get sections for navigation
  List<String> getSectionTitles() {
    return sections ?? [];
  }

  /// Check if page has good OCR quality
  bool hasGoodQuality() {
    return confidence != null && confidence! > 0.7;
  }
}

class QuestionBlock {
  String question;
  List<String> options;
  int correctAnswer; // Index of correct option
  String combinedText; // Question + options as one reading unit

  QuestionBlock({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.combinedText,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': json.encode(options),
      'correct_answer': correctAnswer,
      'combined_text': combinedText,
    };
  }

  static QuestionBlock fromMap(Map<String, dynamic> map) {
    return QuestionBlock(
      question: map['question'],
      options: List<String>.from(json.decode(map['options'])),
      correctAnswer: map['correct_answer'],
      combinedText: map['combined_text'],
    );
  }

  @override
  String toString() {
    return 'QuestionBlock{question: $question, options: ${options.length}}';
  }
}
