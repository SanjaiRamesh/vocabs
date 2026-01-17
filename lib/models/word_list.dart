import 'dart:convert';

class WordList {
  String id;
  String userId; // Firebase Auth UID - owner of this word list
  String subject;
  String listName;
  List<String> words;
  DateTime createdAt;
  DateTime updatedAt;

  WordList({
    required this.id,
    required this.userId,
    required this.subject,
    required this.listName,
    required this.words,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'subject': subject,
      'list_name': listName,
      'words': json.encode(words),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WordList.fromMap(Map<String, dynamic> map) {
    return WordList(
      id: map['id'],
      userId: map['user_id'] ?? '',
      subject: map['subject'],
      listName: map['list_name'],
      words: List<String>.from(json.decode(map['words'])),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  @override
  String toString() {
    return 'WordList(id: $id, subject: $subject, listName: $listName, words: $words)';
  }
}

class WordItem {
  String word;
  String? imagePath;
  String? exampleSentence;
  String? audioPath;
  String? ttsOverride;

  WordItem({
    required this.word,
    this.imagePath,
    this.exampleSentence,
    this.audioPath,
    this.ttsOverride,
  });

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'image_path': imagePath,
      'example_sentence': exampleSentence,
      'audio_path': audioPath,
      'tts_override': ttsOverride,
    };
  }

  factory WordItem.fromMap(Map<String, dynamic> map) {
    return WordItem(
      word: map['word'],
      imagePath: map['image_path'],
      exampleSentence: map['example_sentence'],
      audioPath: map['audio_path'],
      ttsOverride: map['tts_override'],
    );
  }

  @override
  String toString() {
    return 'WordItem(word: $word, imagePath: $imagePath, exampleSentence: $exampleSentence)';
  }
}
