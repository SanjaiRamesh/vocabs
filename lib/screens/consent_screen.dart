import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'auth_gate.dart';
import 'privacy_screen.dart';

class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _saving = false;

  Future<void> _acceptConsent() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final packageInfo = await PackageInfo.fromPlatform();
      await prefs.setBool('consentAccepted', true);
      await prefs.setString(
        'consentTimestamp',
        DateTime.now().toIso8601String(),
      );
      await prefs.setString(
        'consentAppVersion',
        '${packageInfo.version}+${packageInfo.buildNumber}',
      );

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthGate()));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _declineConsent() {
    // Close the app or block usage. Prefer SystemNavigator.pop on Android.
    // On platforms where closing isn't allowed, user remains blocked on this screen.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Consent Required'),
          content: const Text(
            'You must accept consent to use this app. The app will now close.',
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await SystemNavigator.pop(); // best for Android
              },
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = const [
      Color(0xFFE1F5FE),
      Color(0xFFF3E5F5),
      Color(0xFFE8F5E8),
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome to AI Reading Assistant',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromARGB(25, 0, 0, 0),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'To continue, please review and accept our consent.\n\n'
                      'This app is part of a research study/demo. Your learning activity data may be used in aggregated form for analysis. '
                      'We store minimal learning activity data locally (e.g., word attempts and schedules) to support progress tracking. '
                      'No personal identifiers (name, phone, email) are collected. Data is stored locally after you agree.\n\n'
                      'Tap "I Agree" to proceed.',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacyScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'View Privacy & Data Usage',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: _saving ? null : _acceptConsent,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text('I Agree'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _saving ? null : _declineConsent,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
