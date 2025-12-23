/// Book model for storing book data with SQLite compatibility
class Book {
  final String id;
  final String title;
  final String author;
  final String description;
  final String coverImagePath;
  final List<String> pages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? language;
  final String? difficulty;
  final List<String>? tags;
  final int? readingTime; // estimated reading time in minutes
  final bool? isFavorite;
  final double? userRating;
  final int? timesRead;

  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.coverImagePath,
    required this.pages,
    required this.createdAt,
    required this.updatedAt,
    this.language,
    this.difficulty,
    this.tags,
    this.readingTime,
    this.isFavorite = false,
    this.userRating,
    this.timesRead = 0,
  });

  // Factory constructor for creating a new book
  factory Book.create({
    required String title,
    required String author,
    required String description,
    required String coverImagePath,
    required List<String> pages,
    String? language,
    String? difficulty,
    List<String>? tags,
  }) {
    final now = DateTime.now();
    return Book(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      author: author,
      description: description,
      coverImagePath: coverImagePath,
      pages: pages,
      createdAt: now,
      updatedAt: now,
      language: language ?? 'English',
      difficulty: difficulty ?? 'Beginner',
      tags: tags ?? [],
      readingTime: _estimateReadingTime(pages),
      isFavorite: false,
      userRating: null,
      timesRead: 0,
    );
  }

  // Create a copy with updated fields
  Book copyWith({
    String? title,
    String? author,
    String? description,
    String? coverImagePath,
    List<String>? pages,
    String? language,
    String? difficulty,
    List<String>? tags,
    bool? isFavorite,
    double? userRating,
    int? timesRead,
  }) {
    return Book(
      id: id,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      pages: pages ?? this.pages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      language: language ?? this.language,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      readingTime: pages != null ? _estimateReadingTime(pages) : readingTime,
      isFavorite: isFavorite ?? this.isFavorite,
      userRating: userRating ?? this.userRating,
      timesRead: timesRead ?? this.timesRead,
    );
  }

  // Mark as read
  Book markAsRead() {
    return copyWith(timesRead: (timesRead ?? 0) + 1);
  }

  // Toggle favorite status
  Book toggleFavorite() {
    return copyWith(isFavorite: !(isFavorite ?? false));
  }

  // Set user rating
  Book setRating(double rating) {
    return copyWith(userRating: rating.clamp(0.0, 5.0));
  }

  // Get word count for all pages
  int get totalWords {
    return pages.fold(0, (sum, page) => sum + page.split(' ').length);
  }

  // Get estimated reading time in minutes
  static int _estimateReadingTime(List<String> pages) {
    final totalWords = pages.fold(
      0,
      (sum, page) => sum + page.split(' ').length,
    );
    // Average reading speed for children: 150-200 words per minute
    return (totalWords / 175).ceil(); // Using 175 WPM as average
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'description': description,
      'coverImagePath': coverImagePath,
      'pages': pages.join(
        '|PAGE_SEPARATOR|',
      ), // Store as delimited string for SQLite
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'language': language,
      'difficulty': difficulty,
      'tags': tags?.join(','), // Store as comma-separated string
      'readingTime': readingTime,
      'isFavorite': isFavorite == true ? 1 : 0, // SQLite boolean compatibility
      'userRating': userRating,
      'timesRead': timesRead,
    };
  }

  // Create from JSON
  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      author: json['author'] ?? '',
      description: json['description'] ?? '',
      coverImagePath: json['coverImagePath'] ?? '',
      pages: (json['pages'] as String?)?.split('|PAGE_SEPARATOR|') ?? [],
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      language: json['language'],
      difficulty: json['difficulty'],
      tags: (json['tags'] as String?)
          ?.split(',')
          .where((tag) => tag.isNotEmpty)
          .toList(),
      readingTime: json['readingTime'],
      isFavorite: json['isFavorite'] == 1,
      userRating: json['userRating']?.toDouble(),
      timesRead: json['timesRead'],
    );
  }

  @override
  String toString() {
    return 'Book(id: $id, title: $title, author: $author, pages: ${pages.length})';
  }

  // Equality operator
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Book && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

// Difficulty levels enum
enum BookDifficulty {
  beginner('Beginner'),
  elementary('Elementary'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const BookDifficulty(this.displayName);
  final String displayName;
}

// Reading progress tracking
class ReadingProgress {
  final String id;
  final String bookId;
  final int currentPage;
  final DateTime lastReadAt;
  final int totalReadingTimeMinutes;
  final List<String>? completedPages;
  final double? comprehensionScore;
  final Map<String, dynamic>? readingStats;

  const ReadingProgress({
    required this.id,
    required this.bookId,
    required this.currentPage,
    required this.lastReadAt,
    required this.totalReadingTimeMinutes,
    this.completedPages,
    this.comprehensionScore,
    this.readingStats,
  });

  // Create new reading progress
  factory ReadingProgress.create({
    required String bookId,
    int currentPage = 0,
  }) {
    return ReadingProgress(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      bookId: bookId,
      currentPage: currentPage,
      lastReadAt: DateTime.now(),
      totalReadingTimeMinutes: 0,
      completedPages: [],
      comprehensionScore: null,
      readingStats: {},
    );
  }

  // Update reading progress
  ReadingProgress copyWith({
    int? currentPage,
    int? additionalReadingTime,
    List<String>? newCompletedPages,
    double? comprehensionScore,
    Map<String, dynamic>? readingStats,
  }) {
    final List<String>? updatedCompletedPages = newCompletedPages != null
        ? [...(completedPages ?? <String>[]), ...newCompletedPages]
        : completedPages;

    final updatedReadingTime = additionalReadingTime != null
        ? totalReadingTimeMinutes + additionalReadingTime
        : totalReadingTimeMinutes;

    return ReadingProgress(
      id: id,
      bookId: bookId,
      currentPage: currentPage ?? this.currentPage,
      lastReadAt: DateTime.now(),
      totalReadingTimeMinutes: updatedReadingTime,
      completedPages: updatedCompletedPages,
      comprehensionScore: comprehensionScore ?? this.comprehensionScore,
      readingStats: readingStats ?? this.readingStats,
    );
  }

  // Calculate reading completion percentage
  double getCompletionPercentage(int totalPages) {
    if (totalPages == 0) return 0.0;
    return (currentPage / totalPages * 100).clamp(0.0, 100.0);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bookId': bookId,
      'currentPage': currentPage,
      'lastReadAt': lastReadAt.toIso8601String(),
      'totalReadingTimeMinutes': totalReadingTimeMinutes,
      'completedPages': completedPages?.join(
        ',',
      ), // Store as comma-separated string
      'comprehensionScore': comprehensionScore,
      'readingStats': readingStats != null ? readingStats.toString() : null,
    };
  }

  factory ReadingProgress.fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      id: json['id'] ?? '',
      bookId: json['bookId'] ?? '',
      currentPage: json['currentPage'] ?? 0,
      lastReadAt: DateTime.parse(
        json['lastReadAt'] ?? DateTime.now().toIso8601String(),
      ),
      totalReadingTimeMinutes: json['totalReadingTimeMinutes'] ?? 0,
      completedPages: (json['completedPages'] as String?)
          ?.split(',')
          .where((page) => page.isNotEmpty)
          .map((page) => page.toString())
          .toList(),
      comprehensionScore: json['comprehensionScore']?.toDouble(),
      readingStats: json['readingStats'] != null
          ? Map<String, dynamic>.from(json['readingStats'])
          : null,
    );
  }

  @override
  String toString() {
    return 'ReadingProgress(bookId: $bookId, currentPage: $currentPage, completion: ${getCompletionPercentage(100).toStringAsFixed(1)}%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ReadingProgress && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
