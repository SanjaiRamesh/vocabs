import 'package:flutter/material.dart';
import '../models/achievement.dart';
import '../models/user_progress.dart';
import '../services/gamification_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with TickerProviderStateMixin {
  List<Achievement> _achievements = [];
  UserProgress? _userProgress;
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final achievements = await GamificationService.getAllAchievements();
      final progress = await GamificationService.getUserProgress();
      
      setState(() {
        _achievements = achievements;
        _userProgress = progress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Achievement> _getAchievementsByCategory(String category) {
    return _achievements.where((achievement) => achievement.category == category).toList();
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
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.deepPurple),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Achievements',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                          if (_userProgress != null)
                            Text(
                              '${_achievements.where((a) => a.isUnlocked).length}/${_achievements.length} unlocked',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.deepPurple.shade600,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Coins display
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.amber, width: 2),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.monetization_on, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            '${_userProgress?.coins ?? 0}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                              fontFamily: 'OpenDyslexic',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Stats Row
              if (_userProgress != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: _buildStatCard('Streak', '${_userProgress!.currentStreak}', Icons.local_fire_department, Colors.orange)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Words', '${_userProgress!.totalWordsCompleted}', Icons.library_books, Colors.blue)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatCard('Accuracy', '${_userProgress!.accuracy.round()}%', Icons.gps_fixed, Colors.green)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: Colors.deepPurple,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  indicatorColor: Colors.deepPurple,
                  tabs: const [
                    Tab(text: 'All', icon: Icon(Icons.emoji_events, size: 20)),
                    Tab(text: 'Words', icon: Icon(Icons.library_books, size: 20)),
                    Tab(text: 'Streaks', icon: Icon(Icons.local_fire_department, size: 20)),
                    Tab(text: 'Practice', icon: Icon(Icons.school, size: 20)),
                    Tab(text: 'Shop', icon: Icon(Icons.shopping_bag, size: 20)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tab Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAchievementsList(_achievements),
                          _buildAchievementsList(_getAchievementsByCategory('words')),
                          _buildAchievementsList(_getAchievementsByCategory('streak')),
                          _buildAchievementsList(_getAchievementsByCategory('practice')),
                          _buildAchievementsList(_getAchievementsByCategory('shop')),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'OpenDyslexic',
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontFamily: 'OpenDyslexic',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsList(List<Achievement> achievements) {
    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No achievements in this category yet!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade500,
                fontFamily: 'OpenDyslexic',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return _buildAchievementCard(achievement);
      },
    );
  }

  Widget _buildAchievementCard(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isUnlocked ? 8 : 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: isUnlocked 
              ? BorderSide(color: Colors.amber, width: 2)
              : BorderSide.none,
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: isUnlocked 
                ? LinearGradient(
                    colors: [Colors.amber.shade50, Colors.yellow.shade50],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Achievement Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: isUnlocked 
                        ? Colors.amber 
                        : Colors.grey.shade300,
                    shape: BoxShape.circle,
                    boxShadow: isUnlocked ? [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    _getAchievementIcon(achievement.iconName),
                    size: 30,
                    color: isUnlocked ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(width: 16),
                
                // Achievement Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              achievement.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked ? Colors.deepPurple : Colors.grey.shade700,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ),
                          if (isUnlocked) ...[
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: isUnlocked ? Colors.grey.shade700 : Colors.grey.shade500,
                          fontFamily: 'OpenDyslexic',
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Progress or Reward
                      Row(
                        children: [
                          // Progress indicator
                          if (!isUnlocked && _userProgress != null) ...[
                            Expanded(
                              child: _buildProgressIndicator(achievement),
                            ),
                          ] else if (isUnlocked) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          
                          // Reward display
                          if (achievement.rewardAmount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monetization_on, size: 14, color: Colors.amber.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${achievement.rewardAmount}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(Achievement achievement) {
    if (_userProgress == null) return const SizedBox.shrink();
    
    double progress = 0.0;
    int current = 0;
    
    switch (achievement.category) {
      case 'words':
        current = _userProgress!.totalWordsCompleted;
        progress = (current / achievement.requirement).clamp(0.0, 1.0);
        break;
      case 'streak':
        current = _userProgress!.longestStreak;
        progress = (current / achievement.requirement).clamp(0.0, 1.0);
        break;
      case 'practice':
        if (achievement.requirement == 90) { // Accuracy achievement
          current = _userProgress!.accuracy.round();
          progress = (current / achievement.requirement).clamp(0.0, 1.0);
        }
        break;
      case 'shop':
        // This would need to be calculated from owned items
        // For now, just show as incomplete
        current = 0;
        progress = 0.0;
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$current / ${achievement.requirement}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          minHeight: 6,
        ),
      ],
    );
  }

  IconData _getAchievementIcon(String iconName) {
    switch (iconName) {
      case 'star':
        return Icons.star;
      case 'stars':
        return Icons.stars;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'military_tech':
        return Icons.military_tech;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'flash_on':
        return Icons.flash_on;
      case 'check_circle':
        return Icons.check_circle;
      case 'gps_fixed':
        return Icons.gps_fixed;
      case 'pets':
        return Icons.pets;
      case 'collections':
        return Icons.collections;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
