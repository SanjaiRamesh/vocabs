import 'package:sqflite/sqflite.dart';
import '../models/achievement.dart';
import '../models/shop_item.dart';
import '../models/user_progress.dart';
import 'database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class GamificationService {
  static final DatabaseHelper _databaseHelper = DatabaseHelper();

  // Initialize gamification system
  static Future<void> init() async {
    if (kIsWeb) return; // Web doesn't support SQLite
    await _createTables();
    await _createDefaultAchievements();
    await _createDefaultShopItems();
    await _initializeUserProgress();
  }

  // Create database tables
  static Future<void> _createTables() async {
    final db = await _databaseHelper.database;

    // Achievements table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL,
        requirement INTEGER NOT NULL,
        is_unlocked INTEGER NOT NULL DEFAULT 0,
        unlocked_at TEXT,
        reward_type TEXT NOT NULL DEFAULT 'coins',
        reward_amount INTEGER NOT NULL DEFAULT 10
      )
    ''');

    // Shop items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS shop_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon_name TEXT NOT NULL,
        category TEXT NOT NULL,
        price INTEGER NOT NULL,
        rarity TEXT NOT NULL DEFAULT 'common',
        is_owned INTEGER NOT NULL DEFAULT 0,
        purchased_at TEXT,
        is_equipped INTEGER NOT NULL DEFAULT 0,
        animation TEXT
      )
    ''');

    // User progress table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_progress (
        user_id TEXT PRIMARY KEY,
        coins INTEGER NOT NULL DEFAULT 0,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        last_practice_date TEXT NOT NULL,
        total_words_completed INTEGER NOT NULL DEFAULT 0,
        total_correct_answers INTEGER NOT NULL DEFAULT 0,
        total_incorrect_answers INTEGER NOT NULL DEFAULT 0,
        unlocked_achievements TEXT NOT NULL DEFAULT '',
        equipped_pet TEXT,
        equipped_plant TEXT,
        aquarium_fish TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // Create default achievements
  static Future<void> _createDefaultAchievements() async {
    final db = await _databaseHelper.database;

    // Check if achievements already exist
    final count = await db.rawQuery(
      'SELECT COUNT(*) as count FROM achievements',
    );
    if ((count.first['count'] as int) > 0) return;

    final defaultAchievements = [
      // Word completion achievements
      Achievement(
        id: 'first_words_10',
        name: 'First Steps',
        description: 'Complete your first 10 words!',
        iconName: 'star',
        category: 'words',
        requirement: 10,
        rewardAmount: 50,
      ),
      Achievement(
        id: 'words_25',
        name: 'Getting Started',
        description: 'Complete 25 words!',
        iconName: 'stars',
        category: 'words',
        requirement: 25,
        rewardAmount: 100,
      ),
      Achievement(
        id: 'words_50',
        name: 'Word Explorer',
        description: 'Complete 50 words!',
        iconName: 'emoji_events',
        category: 'words',
        requirement: 50,
        rewardAmount: 200,
      ),
      Achievement(
        id: 'words_100',
        name: 'Word Master',
        description: 'Complete 100 words!',
        iconName: 'military_tech',
        category: 'words',
        requirement: 100,
        rewardAmount: 500,
      ),

      // Streak achievements
      Achievement(
        id: 'streak_3',
        name: 'On Fire',
        description: 'Practice for 3 days in a row!',
        iconName: 'local_fire_department',
        category: 'streak',
        requirement: 3,
        rewardAmount: 75,
      ),
      Achievement(
        id: 'streak_7',
        name: 'Weekly Warrior',
        description: 'Practice for 7 days in a row!',
        iconName: 'whatshot',
        category: 'streak',
        requirement: 7,
        rewardAmount: 200,
      ),
      Achievement(
        id: 'streak_14',
        name: 'Dedication',
        description: 'Practice for 14 days in a row!',
        iconName: 'flash_on',
        category: 'streak',
        requirement: 14,
        rewardAmount: 500,
      ),
      Achievement(
        id: 'streak_30',
        name: 'Champion',
        description: 'Practice for 30 days in a row!',
        iconName: 'emoji_events',
        category: 'streak',
        requirement: 30,
        rewardAmount: 1000,
      ),

      // Practice achievements
      Achievement(
        id: 'perfect_10',
        name: 'Perfect Practice',
        description: 'Get 10 words correct in a row!',
        iconName: 'check_circle',
        category: 'practice',
        requirement: 10,
        rewardAmount: 100,
      ),
      Achievement(
        id: 'accuracy_90',
        name: 'Sharp Shooter',
        description: 'Achieve 90% accuracy!',
        iconName: 'gps_fixed',
        category: 'practice',
        requirement: 90,
        rewardAmount: 300,
      ),

      // Shop achievements
      Achievement(
        id: 'first_pet',
        name: 'Pet Lover',
        description: 'Buy your first pet!',
        iconName: 'pets',
        category: 'shop',
        requirement: 1,
        rewardAmount: 50,
      ),
      Achievement(
        id: 'collector',
        name: 'Collector',
        description: 'Own 5 shop items!',
        iconName: 'collections',
        category: 'shop',
        requirement: 5,
        rewardAmount: 250,
      ),
    ];

    for (final achievement in defaultAchievements) {
      await db.insert('achievements', achievement.toMap());
    }
  }

  // Create default shop items
  static Future<void> _createDefaultShopItems() async {
    final db = await _databaseHelper.database;

    // Check if shop items already exist
    final count = await db.rawQuery('SELECT COUNT(*) as count FROM shop_items');
    if ((count.first['count'] as int) > 0) return;

    final defaultItems = [
      // Pets - Common
      ShopItem(
        id: 'pet_dog',
        name: 'Friendly Dog',
        description: 'A loyal companion for your studies!',
        iconName: 'pets',
        category: 'pets',
        price: 100,
        rarity: 'common',
        animation: 'bounce',
      ),
      ShopItem(
        id: 'pet_cat',
        name: 'Curious Cat',
        description: 'A playful kitty to keep you company!',
        iconName: 'pets',
        category: 'pets',
        price: 120,
        rarity: 'common',
        animation: 'sway',
      ),

      // Pets - Rare
      ShopItem(
        id: 'pet_dragon',
        name: 'Baby Dragon',
        description: 'A magical friend with sparkling eyes!',
        iconName: 'pets',
        category: 'pets',
        price: 300,
        rarity: 'rare',
        animation: 'flutter',
      ),
      ShopItem(
        id: 'pet_unicorn',
        name: 'Rainbow Unicorn',
        description: 'Magical and mystical study buddy!',
        iconName: 'pets',
        category: 'pets',
        price: 400,
        rarity: 'rare',
        animation: 'sparkle',
      ),

      // Plants - Common
      ShopItem(
        id: 'plant_cactus',
        name: 'Happy Cactus',
        description: 'A low-maintenance green friend!',
        iconName: 'local_florist',
        category: 'plants',
        price: 75,
        rarity: 'common',
      ),
      ShopItem(
        id: 'plant_sunflower',
        name: 'Sunny Flower',
        description: 'Bright and cheerful decoration!',
        iconName: 'local_florist',
        category: 'plants',
        price: 100,
        rarity: 'common',
      ),

      // Plants - Rare
      ShopItem(
        id: 'plant_bonsai',
        name: 'Zen Bonsai',
        description: 'Brings peace and focus to learning!',
        iconName: 'local_florist',
        category: 'plants',
        price: 250,
        rarity: 'rare',
      ),
      ShopItem(
        id: 'plant_venus',
        name: 'Venus Flytrap',
        description: 'A unique and fascinating plant!',
        iconName: 'local_florist',
        category: 'plants',
        price: 200,
        rarity: 'rare',
      ),

      // Aquarium Fish - Common
      ShopItem(
        id: 'fish_goldfish',
        name: 'Golden Fish',
        description: 'Classic and beautiful aquarium fish!',
        iconName: 'water',
        category: 'aquarium',
        price: 50,
        rarity: 'common',
      ),
      ShopItem(
        id: 'fish_clownfish',
        name: 'Clown Fish',
        description: 'Colorful and playful swimmer!',
        iconName: 'water',
        category: 'aquarium',
        price: 75,
        rarity: 'common',
      ),

      // Aquarium Fish - Rare
      ShopItem(
        id: 'fish_angelfish',
        name: 'Angel Fish',
        description: 'Elegant and graceful swimmer!',
        iconName: 'water',
        category: 'aquarium',
        price: 150,
        rarity: 'rare',
      ),
      ShopItem(
        id: 'fish_seahorse',
        name: 'Magical Seahorse',
        description: 'Mystical creature of the deep!',
        iconName: 'water',
        category: 'aquarium',
        price: 200,
        rarity: 'rare',
      ),

      // Legendary Items
      ShopItem(
        id: 'pet_phoenix',
        name: 'Phoenix Bird',
        description: 'A legendary bird of fire and wisdom!',
        iconName: 'pets',
        category: 'pets',
        price: 1000,
        rarity: 'legendary',
        animation: 'glow',
      ),
      ShopItem(
        id: 'plant_world_tree',
        name: 'World Tree',
        description: 'The most magnificent tree of all!',
        iconName: 'local_florist',
        category: 'plants',
        price: 800,
        rarity: 'legendary',
      ),
    ];

    for (final item in defaultItems) {
      await db.insert('shop_items', item.toMap());
    }
  }

  // Initialize user progress
  static Future<void> _initializeUserProgress() async {
    final existingProgress = await getUserProgress();
    if (existingProgress == null) {
      final progress = UserProgress(
        lastPracticeDate: DateTime.now().toIso8601String().split('T')[0],
      );
      await _saveUserProgress(progress);
    }
  }

  // Get user progress
  static Future<UserProgress?> getUserProgress() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'user_progress',
      where: 'user_id = ?',
      whereArgs: ['default_user'],
    );

    if (result.isNotEmpty) {
      return UserProgress.fromMap(result.first);
    }
    return null;
  }

  // Save user progress
  static Future<void> _saveUserProgress(UserProgress progress) async {
    final db = await _databaseHelper.database;
    progress.updatedAt = DateTime.now();

    await db.insert(
      'user_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Award coins for correct answer
  static Future<void> awardCoins(
    int amount, {
    String reason = 'Correct answer',
  }) async {
    final progress = await getUserProgress();
    if (progress != null) {
      final updatedProgress = progress.copyWith(coins: progress.coins + amount);
      await _saveUserProgress(updatedProgress);
    }
  }

  // Update practice stats and check achievements
  static Future<List<Achievement>> updatePracticeStats({
    required bool isCorrect,
    required int totalQuestions,
    required int correctAnswers,
  }) async {
    final progress = await getUserProgress();
    if (progress == null) return [];

    final today = DateTime.now().toIso8601String().split('T')[0];
    List<Achievement> newAchievements = [];

    // Update streak
    int newStreak = progress.currentStreak;
    if (progress.lastPracticeDate != today) {
      final lastDate = DateTime.parse(progress.lastPracticeDate);
      final todayDate = DateTime.parse(today);
      final difference = todayDate.difference(lastDate).inDays;

      if (difference == 1) {
        newStreak = progress.currentStreak + 1;
      } else if (difference > 1) {
        newStreak = 1; // Reset streak
      }
    }

    // Award coins for correct answers
    if (isCorrect) {
      await awardCoins(5, reason: 'Correct answer');
    }

    // Update progress
    final updatedProgress = progress.copyWith(
      currentStreak: newStreak,
      longestStreak: newStreak > progress.longestStreak
          ? newStreak
          : progress.longestStreak,
      lastPracticeDate: today,
      totalWordsCompleted: progress.totalWordsCompleted + 1,
      totalCorrectAnswers: progress.totalCorrectAnswers + (isCorrect ? 1 : 0),
      totalIncorrectAnswers:
          progress.totalIncorrectAnswers + (isCorrect ? 0 : 1),
    );

    await _saveUserProgress(updatedProgress);

    // Check for new achievements
    newAchievements.addAll(
      await _checkWordAchievements(updatedProgress.totalWordsCompleted),
    );
    newAchievements.addAll(await _checkStreakAchievements(newStreak));
    newAchievements.addAll(await _checkPracticeAchievements(updatedProgress));

    return newAchievements;
  }

  // Check word-based achievements
  static Future<List<Achievement>> _checkWordAchievements(
    int totalWords,
  ) async {
    final wordMilestones = [10, 25, 50, 100, 200, 500, 1000];
    final achievements = <Achievement>[];

    for (final milestone in wordMilestones) {
      if (totalWords >= milestone) {
        final achievement = await _unlockAchievement('words', milestone);
        if (achievement != null) {
          achievements.add(achievement);
        }
      }
    }

    return achievements;
  }

  // Check streak-based achievements
  static Future<List<Achievement>> _checkStreakAchievements(int streak) async {
    final streakMilestones = [3, 7, 14, 30, 60, 100];
    final achievements = <Achievement>[];

    for (final milestone in streakMilestones) {
      if (streak >= milestone) {
        final achievement = await _unlockAchievement('streak', milestone);
        if (achievement != null) {
          achievements.add(achievement);
        }
      }
    }

    return achievements;
  }

  // Check practice-based achievements
  static Future<List<Achievement>> _checkPracticeAchievements(
    UserProgress progress,
  ) async {
    final achievements = <Achievement>[];

    // Check accuracy achievement
    if (progress.accuracy >= 90) {
      final achievement = await _unlockAchievement('practice', 90);
      if (achievement != null) {
        achievements.add(achievement);
      }
    }

    return achievements;
  }

  // Unlock achievement
  static Future<Achievement?> _unlockAchievement(
    String category,
    int requirement,
  ) async {
    final db = await _databaseHelper.database;

    final result = await db.query(
      'achievements',
      where: 'category = ? AND requirement = ? AND is_unlocked = 0',
      whereArgs: [category, requirement],
    );

    if (result.isNotEmpty) {
      final achievement = Achievement.fromMap(result.first);
      final unlockedAchievement = achievement.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
      );

      await db.update(
        'achievements',
        unlockedAchievement.toMap(),
        where: 'id = ?',
        whereArgs: [achievement.id],
      );

      // Award coins for achievement
      if (achievement.rewardType == 'coins') {
        await awardCoins(
          achievement.rewardAmount,
          reason: 'Achievement: ${achievement.name}',
        );
      }

      return unlockedAchievement;
    }

    return null;
  }

  // Get all achievements
  static Future<List<Achievement>> getAllAchievements() async {
    final db = await _databaseHelper.database;
    final result = await db.query('achievements', orderBy: 'requirement ASC');
    return result.map((map) => Achievement.fromMap(map)).toList();
  }

  // Get unlocked achievements
  static Future<List<Achievement>> getUnlockedAchievements() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'achievements',
      where: 'is_unlocked = 1',
      orderBy: 'unlocked_at DESC',
    );
    return result.map((map) => Achievement.fromMap(map)).toList();
  }

  // Get shop items by category
  static Future<List<ShopItem>> getShopItemsByCategory(String category) async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'shop_items',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'price ASC',
    );
    return result.map((map) => ShopItem.fromMap(map)).toList();
  }

  // Get all shop items
  static Future<List<ShopItem>> getAllShopItems() async {
    final db = await _databaseHelper.database;
    final result = await db.query('shop_items', orderBy: 'price ASC');
    return result.map((map) => ShopItem.fromMap(map)).toList();
  }

  // Get owned shop items
  static Future<List<ShopItem>> getOwnedItems() async {
    final db = await _databaseHelper.database;
    final result = await db.query(
      'shop_items',
      where: 'is_owned = 1',
      orderBy: 'purchased_at DESC',
    );
    return result.map((map) => ShopItem.fromMap(map)).toList();
  }

  // Purchase shop item
  static Future<bool> purchaseItem(String itemId) async {
    final db = await _databaseHelper.database;
    final progress = await getUserProgress();
    if (progress == null) return false;

    // Get item details
    final itemResult = await db.query(
      'shop_items',
      where: 'id = ? AND is_owned = 0',
      whereArgs: [itemId],
    );

    if (itemResult.isEmpty) return false;

    final item = ShopItem.fromMap(itemResult.first);

    // Check if user has enough coins
    if (progress.coins < item.price) return false;

    // Deduct coins and mark item as owned
    final updatedProgress = progress.copyWith(
      coins: progress.coins - item.price,
    );
    await _saveUserProgress(updatedProgress);

    await db.update(
      'shop_items',
      {'is_owned': 1, 'purchased_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [itemId],
    );

    // Check shop achievements
    await _checkShopAchievements();

    return true;
  }

  // Check shop-based achievements
  static Future<void> _checkShopAchievements() async {
    final ownedItems = await getOwnedItems();

    if (ownedItems.isNotEmpty) {
      await _unlockAchievement('shop', 1);
    }
    if (ownedItems.length >= 5) {
      await _unlockAchievement('shop', 5);
    }
  }

  // Equip item
  static Future<void> equipItem(String itemId, String category) async {
    final db = await _databaseHelper.database;

    // Unequip all items in category
    await db.update(
      'shop_items',
      {'is_equipped': 0},
      where: 'category = ?',
      whereArgs: [category],
    );

    // Equip selected item
    await db.update(
      'shop_items',
      {'is_equipped': 1},
      where: 'id = ? AND is_owned = 1',
      whereArgs: [itemId],
    );
  }

  // Get equipped items
  static Future<Map<String, ShopItem?>> getEquippedItems() async {
    final db = await _databaseHelper.database;
    final result = await db.query('shop_items', where: 'is_equipped = 1');

    final equipped = <String, ShopItem?>{
      'pets': null,
      'plants': null,
      'aquarium': null,
    };

    for (final map in result) {
      final item = ShopItem.fromMap(map);
      equipped[item.category] = item;
    }

    return equipped;
  }
}
