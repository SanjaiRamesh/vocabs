/// Represents the result of a comprehensive reading assessment
class ReadingAssessmentResult {
  final String targetSentence;
  final String spokenTranscript;
  final DateTime assessmentTime;
  final Duration totalReadingTime;

  // Word-level analysis
  final int totalWords;
  final int correctWords;
  final double accuracyPercentage;
  final double wordsPerMinute;

  // Individual word assessments
  final List<WordAssessment> wordAssessments;

  // Overall assessment
  final bool overallPassed;
  final String feedback;
  final AssessmentLevel level;

  // Additional metrics
  final double fluencyScore;
  final double comprehensionScore;
  final List<String> areasForImprovement;

  const ReadingAssessmentResult({
    required this.targetSentence,
    required this.spokenTranscript,
    required this.assessmentTime,
    required this.totalReadingTime,
    required this.totalWords,
    required this.correctWords,
    required this.accuracyPercentage,
    required this.wordsPerMinute,
    required this.wordAssessments,
    required this.overallPassed,
    required this.feedback,
    required this.level,
    required this.fluencyScore,
    required this.comprehensionScore,
    required this.areasForImprovement,
  });

  /// Creates a comprehensive assessment result from basic parameters
  factory ReadingAssessmentResult.fromBasicAssessment({
    required String targetSentence,
    required String spokenTranscript,
    required DateTime speechStartTime,
    required DateTime speechEndTime,
    double accuracyThreshold = 0.8,
  }) {
    final totalReadingTime = speechEndTime.difference(speechStartTime);
    final targetWords = targetSentence.trim().split(RegExp(r'\s+'));
    final spokenWords = spokenTranscript.trim().split(RegExp(r'\s+'));

    final totalWords = targetWords.length;
    final wordAssessments = <WordAssessment>[];
    int correctWords = 0;

    // Perform word-by-word assessment
    for (int i = 0; i < totalWords; i++) {
      final targetWord = i < targetWords.length
          ? targetWords[i].toLowerCase()
          : '';
      final spokenWord = i < spokenWords.length
          ? spokenWords[i].toLowerCase()
          : '';

      final isCorrect = _isWordMatch(targetWord, spokenWord);
      if (isCorrect) correctWords++;

      wordAssessments.add(
        WordAssessment(
          targetWord: targetWord,
          spokenWord: spokenWord,
          isCorrect: isCorrect,
          similarity: _calculateSimilarity(targetWord, spokenWord),
          position: i,
        ),
      );
    }

    final accuracyPercentage = totalWords > 0
        ? (correctWords / totalWords) * 100
        : 0.0;
    final wordsPerMinute = totalReadingTime.inSeconds > 0
        ? (totalWords / totalReadingTime.inSeconds) * 60
        : 0.0;

    final overallPassed = accuracyPercentage >= (accuracyThreshold * 100);
    final level = _determineLevel(accuracyPercentage, wordsPerMinute);
    final fluencyScore = _calculateFluencyScore(
      wordsPerMinute,
      accuracyPercentage,
    );
    final comprehensionScore = _calculateComprehensionScore(accuracyPercentage);

    return ReadingAssessmentResult(
      targetSentence: targetSentence,
      spokenTranscript: spokenTranscript,
      assessmentTime: DateTime.now(),
      totalReadingTime: totalReadingTime,
      totalWords: totalWords,
      correctWords: correctWords,
      accuracyPercentage: accuracyPercentage,
      wordsPerMinute: wordsPerMinute,
      wordAssessments: wordAssessments,
      overallPassed: overallPassed,
      feedback: _generateFeedback(accuracyPercentage, wordsPerMinute, level),
      level: level,
      fluencyScore: fluencyScore,
      comprehensionScore: comprehensionScore,
      areasForImprovement: _identifyAreasForImprovement(
        wordAssessments,
        accuracyPercentage,
        wordsPerMinute,
      ),
    );
  }

  /// Converts the assessment result to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'targetSentence': targetSentence,
      'spokenTranscript': spokenTranscript,
      'assessmentTime': assessmentTime.toIso8601String(),
      'totalReadingTimeMs': totalReadingTime.inMilliseconds,
      'totalWords': totalWords,
      'correctWords': correctWords,
      'accuracyPercentage': accuracyPercentage,
      'wordsPerMinute': wordsPerMinute,
      'wordAssessments': wordAssessments.map((w) => w.toJson()).toList(),
      'overallPassed': overallPassed,
      'feedback': feedback,
      'level': level.toString(),
      'fluencyScore': fluencyScore,
      'comprehensionScore': comprehensionScore,
      'areasForImprovement': areasForImprovement,
    };
  }

  /// Creates an assessment result from a JSON map
  factory ReadingAssessmentResult.fromJson(Map<String, dynamic> json) {
    return ReadingAssessmentResult(
      targetSentence: json['targetSentence'] ?? '',
      spokenTranscript: json['spokenTranscript'] ?? '',
      assessmentTime: DateTime.parse(
        json['assessmentTime'] ?? DateTime.now().toIso8601String(),
      ),
      totalReadingTime: Duration(milliseconds: json['totalReadingTimeMs'] ?? 0),
      totalWords: json['totalWords'] ?? 0,
      correctWords: json['correctWords'] ?? 0,
      accuracyPercentage: (json['accuracyPercentage'] ?? 0.0).toDouble(),
      wordsPerMinute: (json['wordsPerMinute'] ?? 0.0).toDouble(),
      wordAssessments:
          (json['wordAssessments'] as List<dynamic>?)
              ?.map((w) => WordAssessment.fromJson(w))
              .toList() ??
          [],
      overallPassed: json['overallPassed'] ?? false,
      feedback: json['feedback'] ?? '',
      level: AssessmentLevel.values.firstWhere(
        (l) => l.toString() == json['level'],
        orElse: () => AssessmentLevel.beginner,
      ),
      fluencyScore: (json['fluencyScore'] ?? 0.0).toDouble(),
      comprehensionScore: (json['comprehensionScore'] ?? 0.0).toDouble(),
      areasForImprovement: List<String>.from(json['areasForImprovement'] ?? []),
    );
  }

  // Helper methods for assessment logic
  static bool _isWordMatch(String target, String spoken) {
    if (target.isEmpty || spoken.isEmpty) return false;

    // Exact match
    if (target == spoken) return true;

    // Fuzzy match with Levenshtein distance
    final distance = _levenshteinDistance(target, spoken);
    final maxLength = target.length > spoken.length
        ? target.length
        : spoken.length;
    final similarity = 1.0 - (distance / maxLength);

    return similarity >= 0.8; // 80% similarity threshold
  }

  static double _calculateSimilarity(String target, String spoken) {
    if (target.isEmpty && spoken.isEmpty) return 1.0;
    if (target.isEmpty || spoken.isEmpty) return 0.0;

    final distance = _levenshteinDistance(target, spoken);
    final maxLength = target.length > spoken.length
        ? target.length
        : spoken.length;
    return 1.0 - (distance / maxLength);
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  static AssessmentLevel _determineLevel(double accuracy, double wpm) {
    if (accuracy >= 95 && wpm >= 120) return AssessmentLevel.advanced;
    if (accuracy >= 85 && wpm >= 90) return AssessmentLevel.intermediate;
    if (accuracy >= 70 && wpm >= 60) return AssessmentLevel.beginner;
    return AssessmentLevel.developing;
  }

  static double _calculateFluencyScore(double wpm, double accuracy) {
    // Combine speed and accuracy for fluency score (0-100)
    final speedScore = (wpm / 150) * 50; // Max 50 points for speed
    final accuracyScore = (accuracy / 100) * 50; // Max 50 points for accuracy
    return (speedScore + accuracyScore).clamp(0, 100);
  }

  static double _calculateComprehensionScore(double accuracy) {
    // For now, comprehension score is based on accuracy
    // In the future, this could include additional comprehension questions
    return accuracy;
  }

  static String _generateFeedback(
    double accuracy,
    double wpm,
    AssessmentLevel level,
  ) {
    if (accuracy >= 95) {
      return "Excellent reading! Your pronunciation and accuracy are outstanding.";
    } else if (accuracy >= 85) {
      return "Great job! You're reading with good accuracy. Keep practicing!";
    } else if (accuracy >= 70) {
      return "Good effort! Focus on pronouncing each word clearly.";
    } else {
      return "Keep practicing! Try reading more slowly and focus on each word.";
    }
  }

  static List<String> _identifyAreasForImprovement(
    List<WordAssessment> wordAssessments,
    double accuracy,
    double wpm,
  ) {
    final areas = <String>[];

    if (accuracy < 80) {
      areas.add("Word pronunciation accuracy");
    }

    if (wpm < 60) {
      areas.add("Reading speed and fluency");
    }

    // Analyze common mistake patterns
    final commonMistakes = <String, int>{};
    for (final assessment in wordAssessments) {
      if (!assessment.isCorrect) {
        final pattern = '${assessment.targetWord} → ${assessment.spokenWord}';
        commonMistakes[pattern] = (commonMistakes[pattern] ?? 0) + 1;
      }
    }

    if (commonMistakes.isNotEmpty) {
      areas.add("Common word confusions");
    }

    return areas;
  }

  @override
  String toString() {
    return 'ReadingAssessmentResult(accuracy: ${accuracyPercentage.toStringAsFixed(1)}%, '
        'wpm: ${wordsPerMinute.toStringAsFixed(1)}, '
        'level: $level, '
        'passed: $overallPassed)';
  }
}

/// Assessment for an individual word within a sentence
class WordAssessment {
  final String targetWord;
  final String spokenWord;
  final bool isCorrect;
  final double similarity;
  final int position;

  const WordAssessment({
    required this.targetWord,
    required this.spokenWord,
    required this.isCorrect,
    required this.similarity,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'targetWord': targetWord,
      'spokenWord': spokenWord,
      'isCorrect': isCorrect,
      'similarity': similarity,
      'position': position,
    };
  }

  factory WordAssessment.fromJson(Map<String, dynamic> json) {
    return WordAssessment(
      targetWord: json['targetWord'] ?? '',
      spokenWord: json['spokenWord'] ?? '',
      isCorrect: json['isCorrect'] ?? false,
      similarity: (json['similarity'] ?? 0.0).toDouble(),
      position: json['position'] ?? 0,
    );
  }

  @override
  String toString() {
    return 'WordAssessment(target: "$targetWord", spoken: "$spokenWord", '
        'correct: $isCorrect, similarity: ${similarity.toStringAsFixed(2)})';
  }
}

/// Reading proficiency levels
enum AssessmentLevel {
  developing,
  beginner,
  intermediate,
  advanced;

  String get displayName {
    switch (this) {
      case AssessmentLevel.developing:
        return 'Developing';
      case AssessmentLevel.beginner:
        return 'Beginner';
      case AssessmentLevel.intermediate:
        return 'Intermediate';
      case AssessmentLevel.advanced:
        return 'Advanced';
    }
  }

  String get description {
    switch (this) {
      case AssessmentLevel.developing:
        return 'Building basic reading skills';
      case AssessmentLevel.beginner:
        return 'Reading simple sentences with support';
      case AssessmentLevel.intermediate:
        return 'Reading confidently with good accuracy';
      case AssessmentLevel.advanced:
        return 'Fluent reading with excellent comprehension';
    }
  }
}
