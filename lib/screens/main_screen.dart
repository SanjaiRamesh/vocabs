import 'package:flutter/material.dart';
import '../widgets/app_layout.dart';
import '../screens/subjects_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/todays_practice_screen.dart';
import '../screens/books_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  final List<Widget> _pages = [
    const SubjectsScreen(),
    const TodaysPracticeScreen(),
    const ProgressScreen(),
    const BooksScreen(),
  ];

  final List<String> _titles = ['RA', 'Practice', 'Progress', 'Books'];

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      currentIndex: _currentIndex,
      title: _titles[_currentIndex],
      onTabChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
        _pageController.jumpToPage(index);
      },
      child: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
