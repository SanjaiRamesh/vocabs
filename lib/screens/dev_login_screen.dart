import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'admin_screen.dart';
import 'main_screen.dart';

class DevLoginScreen extends StatefulWidget {
  DevLoginScreen({super.key});

  @override
  State<DevLoginScreen> createState() => _DevLoginScreenState();
}

class _DevLoginScreenState extends State<DevLoginScreen> {
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

    final email = _emailController.text.trim();
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
      appBar: AppBar(title: const Text('Dev Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
