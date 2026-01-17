import 'package:flutter/material.dart';
import '../widgets/app_layout.dart';
import '../screens/subjects_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/todays_practice_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dev_login_screen.dart';
import '../services/app_settings_service.dart';
import '../services/local_tts_service.dart';
import 'package:http/http.dart' as http;

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
  ];

  final List<String> _titles = ['RA', 'Practice', 'Progress'];

  Future<void> _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DevLoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error signing out: $e')));
      }
    }
  }

  Future<void> _openSettings() async {
    // Load current base URL
    final current = await AppSettingsService.getBaseUrl();
    final controller = TextEditingController(
      text: current ?? LocalTtsService.baseUrl,
    );

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) {
        bool isTesting = false;
        String? testMessage;
        Color? testColor;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('TTS Server Settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Update the TTS Base URL (e.g., your ngrok https URL).',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'https://your-ngrok-url.ngrok-free.dev',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isTesting
                          ? null
                          : () async {
                              final url = controller.text.trim();
                              if (url.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Base URL cannot be empty'),
                                  ),
                                );
                                return;
                              }
                              setState(() {
                                isTesting = true;
                                testMessage = null;
                              });
                              try {
                                final uri = Uri.parse(
                                  url.endsWith('/health') ? url : '$url/health',
                                );
                                final resp = await http
                                    .get(
                                      uri,
                                      headers: const {
                                        'ngrok-skip-browser-warning': 'true',
                                      },
                                    )
                                    .timeout(const Duration(seconds: 5));
                                final ok = resp.statusCode == 200;
                                setState(() {
                                  isTesting = false;
                                  testMessage = ok
                                      ? 'Connection OK: ${resp.body.isNotEmpty ? resp.body : '200'}'
                                      : 'Failed: ${resp.statusCode}';
                                  testColor = ok ? Colors.green : Colors.red;
                                });
                              } catch (e) {
                                setState(() {
                                  isTesting = false;
                                  testMessage = 'Error: $e';
                                  testColor = Colors.red;
                                });
                              }
                            },
                      icon: const Icon(Icons.health_and_safety),
                      label: const Text('Test Connection'),
                    ),
                    const SizedBox(width: 12),
                    if (isTesting)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (testMessage != null)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            testMessage!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: testColor ?? Colors.black87,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = controller.text.trim();
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Base URL cannot be empty')),
                    );
                    return;
                  }
                  await LocalTtsService.setBaseUrl(url);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Base URL updated to: $url')),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
          IconButton(
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          _pageController.jumpToPage(index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.play_arrow),
            label: 'Practice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart),
            label: 'Progress',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
