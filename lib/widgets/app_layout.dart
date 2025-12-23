import 'package:flutter/material.dart';
import '../screens/profile_screen.dart';
import '../screens/achievements_screen.dart';
import '../screens/shop_screen.dart';

class AppLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final int currentIndex;
  final Function(int) onTabChanged;

  const AppLayout({
    super.key,
    required this.child,
    required this.title,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  State<AppLayout> createState() => _AppLayoutState();
}

class _AppLayoutState extends State<AppLayout> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE1F5FE), // Light blue
              Color(0xFFF3E5F5), // Light purple
              Color(0xFFE8F5E8), // Light green
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: widget.child),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Text(
            widget.title,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 28,
            ),
          ),
          const Spacer(),
          // Gamification buttons
          _buildHeaderButton(
            Icons.emoji_events,
            Colors.amber,
            'Achievements',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AchievementsScreen(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(
            Icons.store,
            Colors.green,
            'Shop',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShopScreen()),
            ),
          ),
          const SizedBox(width: 8),
          _buildHeaderButton(
            Icons.person,
            Colors.deepPurple,
            'Profile',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderButton(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color),
          iconSize: 24,
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: widget.currentIndex,
          onTap: widget.onTabChanged,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.deepPurple,
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school, size: 28),
              label: 'Practice',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart, size: 28),
              label: 'Progress',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.book, size: 28),
              label: 'Books',
            ),
          ],
        ),
      ),
    );
  }
}
