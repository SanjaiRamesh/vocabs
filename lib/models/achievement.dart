class Achievement {
  String id;
  String name;
  String description;
  String iconName;
  String category; // 'words', 'streak', 'practice', 'shop'
  int requirement; // Number needed to unlock
  bool isUnlocked;
  DateTime? unlockedAt;
  String? rewardType; // 'coins', 'badge'
  int rewardAmount;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.iconName,
    required this.category,
    required this.requirement,
    this.isUnlocked = false,
    this.unlockedAt,
    this.rewardType = 'coins',
    this.rewardAmount = 10,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'icon_name': iconName,
      'category': category,
      'requirement': requirement,
      'is_unlocked': isUnlocked ? 1 : 0,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'reward_type': rewardType,
      'reward_amount': rewardAmount,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      iconName: map['icon_name'] ?? 'emoji_events',
      category: map['category'] ?? 'words',
      requirement: map['requirement'] ?? 10,
      isUnlocked: (map['is_unlocked'] ?? 0) == 1,
      unlockedAt: map['unlocked_at'] != null 
          ? DateTime.parse(map['unlocked_at'])
          : null,
      rewardType: map['reward_type'] ?? 'coins',
      rewardAmount: map['reward_amount'] ?? 10,
    );
  }

  Achievement copyWith({
    String? id,
    String? name,
    String? description,
    String? iconName,
    String? category,
    int? requirement,
    bool? isUnlocked,
    DateTime? unlockedAt,
    String? rewardType,
    int? rewardAmount,
  }) {
    return Achievement(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      iconName: iconName ?? this.iconName,
      category: category ?? this.category,
      requirement: requirement ?? this.requirement,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
    );
  }

  @override
  String toString() {
    return 'Achievement{id: $id, name: $name, isUnlocked: $isUnlocked}';
  }
}
