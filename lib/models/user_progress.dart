class UserProgress {
  String userId;
  int coins;
  int currentStreak;
  int longestStreak;
  String lastPracticeDate; // YYYY-MM-DD format
  int totalWordsCompleted;
  int totalCorrectAnswers;
  int totalIncorrectAnswers;
  List<String> unlockedAchievements;
  String? equippedPet;
  String? equippedPlant;
  List<String> aquariumFish;
  DateTime createdAt;
  DateTime updatedAt;

  UserProgress({
    this.userId = 'default_user',
    this.coins = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    required this.lastPracticeDate,
    this.totalWordsCompleted = 0,
    this.totalCorrectAnswers = 0,
    this.totalIncorrectAnswers = 0,
    List<String>? unlockedAchievements,
    this.equippedPet,
    this.equippedPlant,
    List<String>? aquariumFish,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : unlockedAchievements = unlockedAchievements ?? [],
       aquariumFish = aquariumFish ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'coins': coins,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_practice_date': lastPracticeDate,
      'total_words_completed': totalWordsCompleted,
      'total_correct_answers': totalCorrectAnswers,
      'total_incorrect_answers': totalIncorrectAnswers,
      'unlocked_achievements': unlockedAchievements.join(','),
      'equipped_pet': equippedPet,
      'equipped_plant': equippedPlant,
      'aquarium_fish': aquariumFish.join(','),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProgress.fromMap(Map<String, dynamic> map) {
    return UserProgress(
      userId: map['user_id'] ?? 'default_user',
      coins: map['coins'] ?? 0,
      currentStreak: map['current_streak'] ?? 0,
      longestStreak: map['longest_streak'] ?? 0,
      lastPracticeDate: map['last_practice_date'] ?? DateTime.now().toIso8601String().split('T')[0],
      totalWordsCompleted: map['total_words_completed'] ?? 0,
      totalCorrectAnswers: map['total_correct_answers'] ?? 0,
      totalIncorrectAnswers: map['total_incorrect_answers'] ?? 0,
      unlockedAchievements: map['unlocked_achievements'] != null && (map['unlocked_achievements'] as String).isNotEmpty
          ? (map['unlocked_achievements'] as String).split(',')
          : [],
      equippedPet: map['equipped_pet'],
      equippedPlant: map['equipped_plant'],
      aquariumFish: map['aquarium_fish'] != null && (map['aquarium_fish'] as String).isNotEmpty
          ? (map['aquarium_fish'] as String).split(',')
          : [],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  UserProgress copyWith({
    String? userId,
    int? coins,
    int? currentStreak,
    int? longestStreak,
    String? lastPracticeDate,
    int? totalWordsCompleted,
    int? totalCorrectAnswers,
    int? totalIncorrectAnswers,
    List<String>? unlockedAchievements,
    String? equippedPet,
    String? equippedPlant,
    List<String>? aquariumFish,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      coins: coins ?? this.coins,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastPracticeDate: lastPracticeDate ?? this.lastPracticeDate,
      totalWordsCompleted: totalWordsCompleted ?? this.totalWordsCompleted,
      totalCorrectAnswers: totalCorrectAnswers ?? this.totalCorrectAnswers,
      totalIncorrectAnswers: totalIncorrectAnswers ?? this.totalIncorrectAnswers,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      equippedPet: equippedPet ?? this.equippedPet,
      equippedPlant: equippedPlant ?? this.equippedPlant,
      aquariumFish: aquariumFish ?? this.aquariumFish,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Calculate accuracy percentage
  double get accuracy {
    final total = totalCorrectAnswers + totalIncorrectAnswers;
    if (total == 0) return 0.0;
    return (totalCorrectAnswers / total) * 100;
  }

  @override
  String toString() {
    return 'UserProgress{userId: $userId, coins: $coins, streak: $currentStreak, totalWords: $totalWordsCompleted}';
  }
}
