import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/database_helper.dart';
import 'services/word_list_service.dart';
import 'services/word_attempt_service.dart';
import 'services/spaced_repetition_service.dart';
import 'services/gamification_service.dart';
import 'services/local_tts_service.dart';
import 'services/app_settings_service.dart';
import 'assessment_result_service.dart';
import 'navigation/app_routes.dart';
import 'screens/dev_login_screen.dart';
import 'screens/auth_gate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';
import 'screens/consent_screen.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ INSERT FIREBASE HERE (always first)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize app settings (Hive-based)
  try {
    await AppSettingsService.init();
  } catch (e) {
    logDebug('Warning: AppSettingsService init failed: $e');
  }

  if (!kIsWeb) {
    // Initialize database factory for platform-specific SQLite (not supported on web)
    await DatabaseHelper.init();

    // Initialize services (SQLite database will be created automatically)
    try {
      await WordListService.init();
      await WordAttemptService.init();
      await SpacedRepetitionService.init();
      await AssessmentResultService.init();
      // Note: GamificationService.init() is called per-user after login
    } catch (e) {
      logDebug('Warning: Failed to initialize database services: $e');
    }
  } else {
    logDebug('Running on web - database services disabled');
  }

  // Initialize TTS service
  try {
    await LocalTtsService.instance.init();
    logDebug('TTS service initialized successfully');
  } catch (e) {
    logDebug('Warning: Failed to initialize TTS service: $e');
    // Continue anyway - the service will handle fallbacks
  }

  // Note: Default word lists are now created after user login (see dev_login_screen.dart)

  final prefs = await SharedPreferences.getInstance();
  final accepted = prefs.getBool('consentAccepted') ?? false;

  runApp(MyApp(showConsent: !accepted));
}

class MyApp extends StatelessWidget {
  final bool showConsent;
  const MyApp({super.key, required this.showConsent});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Reading Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: showConsent ? const ConsentScreen() : const AuthGate(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
