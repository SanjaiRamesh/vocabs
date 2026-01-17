import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import '../services/word_list_service.dart';
import '../services/gamification_service.dart';
import 'admin_screen.dart';
import 'main_screen.dart';

class DevLoginScreen extends StatefulWidget {
  DevLoginScreen({super.key});

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
  static const String _domainSuffix = '@test.app';
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    debugPrint('DEBUG: Login button pressed');
    final usernameOrEmail = _emailController.text.trim();
    final email = usernameOrEmail.contains('@')
        ? usernameOrEmail
        : '$usernameOrEmail$_domainSuffix';
    final password = _passwordController.text.trim();

    debugPrint('DEBUG: Email = $email');

    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password are required');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('DEBUG: Calling signInWithEmailAndPassword...');

      // Sign in with Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // DEBUG LOG
      debugPrint('DEBUG: Sign-in successful!');

      final uid = userCredential.user!.uid;
      debugPrint('UID_RAW=[$uid]');
      debugPrint('UID_CODES=${uid.runes.toList()}');

      debugPrint(
        'DEBUG: Logged-in UID = ${FirebaseAuth.instance.currentUser?.uid}',
      );

      if (uid == null) {
        throw Exception('User ID not found');
      }

      debugPrint('DEBUG: Fetching user role from Firestore...');

      // Read user role from Firestore
      final userDoc = await _firestore.collection('users').doc(uid).get();

      debugPrint('DEBUG: User doc exists = ${userDoc.exists}');

      if (!userDoc.exists) {
        throw Exception('User document not found in Firestore for uid=$uid');
      }

      final role = userDoc.data()?['role'] as String?;

      debugPrint('DEBUG: User role = $role');

      if (role == null) {
        throw Exception('User role not found');
      }

      // Create default word lists if none exist for this user
      if (!kIsWeb) {
        try {
          await WordListService.createDefaultWordLists(uid);
          debugPrint(
            'DEBUG: Default word lists created/verified for user $uid',
          );
        } catch (e) {
          debugPrint('Warning: Failed to create default word lists: $e');
        }

        // Initialize gamification system for this user
        try {
          await GamificationService.init(uid);
          debugPrint('DEBUG: Gamification system initialized for user $uid');
        } catch (e) {
          debugPrint('Warning: Failed to initialize gamification system: $e');
        }
      }

      if (!mounted) return;

      // Navigate based on role
      if (role == 'admin') {
        debugPrint('DEBUG: Navigating to AdminScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
        );
      } else if (role == 'student') {
        debugPrint('DEBUG: Navigating to MainScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        throw Exception('Unknown role: $role');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('DEBUG: FirebaseAuthException - ${e.code}: ${e.message}');
      if (mounted) {
        _showError('Login failed: ${e.message ?? e.code}');
      }
    } catch (e) {
      debugPrint('DEBUG: Error - $e');
      if (mounted) {
        _showError('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    debugPrint('DEBUG: Error - $message');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Friendly header
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.face_retouching_natural,
                                color: Colors.deepPurple,
                                size: 36,
                              ),
                            ),
                            const Text(
                              'welcome to RA, Please login',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                                fontFamily: 'OpenDyslexic',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Enter your username; the domain is added automatically',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Email field
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Username',
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixText: _domainSuffix,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          keyboardType: TextInputType.text,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 12),

                        // Password field
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          obscureText: true,
                          enabled: !_isLoading,
                        ),

                        const SizedBox(height: 20),

                        // Login button
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'OpenDyslexic',
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Helper text
                        const Text(
                          'Use your school email and password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                            fontFamily: 'OpenDyslexic',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
