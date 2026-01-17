import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_progress.dart';
import '../models/achievement.dart';
import '../models/shop_item.dart';
import '../services/gamification_service.dart';
import 'achievements_screen.dart';
import 'shop_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProgress? _userProgress;
  List<Achievement> _recentAchievements = [];
  List<ShopItem> _equippedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final progress = await GamificationService.getUserProgress(userId);
      final achievements = await GamificationService.getUnlockedAchievements();
      final ownedItems = await GamificationService.getOwnedItems();

      setState(() {
        _userProgress = progress;
        _recentAchievements = achievements.take(3).toList();
        _equippedItems = ownedItems.where((item) => item.isEquipped).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.deepPurple,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.deepPurple,
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Profile',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Stats Card
                      _buildMainStatsCard(),

                      // Quick Actions
                      _buildQuickActions(),

                      // Recent Achievements
                      _buildRecentAchievements(),

                      // Equipped Items
                      _buildEquippedItems(),

                      // Additional Stats
                      _buildDetailedStats(),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMainStatsCard() {
    if (_userProgress == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade400, Colors.purple.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Profile Avatar with Level
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: Colors.deepPurple.shade400,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Learning Champion',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              const SizedBox(height: 20),

              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _buildStatColumn(
                      'Coins',
                      '${_userProgress!.coins}',
                      Icons.monetization_on,
                      Colors.amber,
                    ),
                  ),
                  Container(width: 1, height: 50, color: Colors.white30),
                  Expanded(
                    child: _buildStatColumn(
                      'Streak',
                      '${_userProgress!.currentStreak}',
                      Icons.local_fire_department,
                      Colors.orange.shade300,
                    ),
                  ),
                  Container(width: 1, height: 50, color: Colors.white30),
                  Expanded(
                    child: _buildStatColumn(
                      'Words',
                      '${_userProgress!.totalWordsCompleted}',
                      Icons.library_books,
                      Colors.blue.shade300,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'OpenDyslexic',
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontFamily: 'OpenDyslexic',
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              'Achievements',
              Icons.emoji_events,
              Colors.amber,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AchievementsScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              'Shop',
              Icons.store,
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
                fontFamily: 'OpenDyslexic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAchievements() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Achievements',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              if (_recentAchievements.isNotEmpty)
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AchievementsScreen(),
                    ),
                  ),
                  child: const Text('View All'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (_recentAchievements.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    color: Colors.grey.shade400,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'No achievements yet! Start practicing to unlock your first badge.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            ...(_recentAchievements
                .map((achievement) => _buildAchievementItem(achievement))
                .toList()),
          ],
        ],
      ),
    );
  }

  Widget _buildAchievementItem(Achievement achievement) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.amber,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                    fontFamily: 'OpenDyslexic',
                  ),
                ),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontFamily: 'OpenDyslexic',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (achievement.rewardAmount > 0)
            Row(
              children: [
                Icon(
                  Icons.monetization_on,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  '+${achievement.rewardAmount}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEquippedItems() {
    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Collection',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                  fontFamily: 'OpenDyslexic',
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ShopScreen()),
                ),
                child: const Text('Visit Shop'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_equippedItems.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.pets, color: Colors.grey.shade400, size: 40),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'No items equipped yet! Visit the shop to get your first pet, plant, or aquarium friend.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _equippedItems
                  .map((item) => _buildEquippedItem(item))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEquippedItem(ShopItem item) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.rarityColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: item.rarityColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getCategoryIcon(item.category),
            color: item.rarityColor,
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            item.name,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: item.rarityColor,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStats() {
    if (_userProgress == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistics',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                _buildStatRow(
                  'Total Words Completed',
                  '${_userProgress!.totalWordsCompleted}',
                ),
                _buildStatRow(
                  'Correct Answers',
                  '${_userProgress!.totalCorrectAnswers}',
                ),
                _buildStatRow(
                  'Incorrect Answers',
                  '${_userProgress!.totalIncorrectAnswers}',
                ),
                _buildStatRow(
                  'Longest Streak',
                  '${_userProgress!.longestStreak} days',
                ),
                _buildStatRow(
                  'Current Accuracy',
                  '${_userProgress!.accuracy.round()}%',
                ),
                _buildStatRow('Last Practice', _userProgress!.lastPracticeDate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'pet':
        return Icons.pets;
      case 'plant':
        return Icons.local_florist;
      case 'aquarium':
        return Icons.waves;
      default:
        return Icons.star;
    }
  }
}
