import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/database_helper.dart';
import 'services/word_list_service.dart';
import 'services/word_attempt_service.dart';
import 'services/spaced_repetition_service.dart';
import 'services/gamification_service.dart';
import 'services/local_tts_service.dart';
import 'assessment_result_service.dart';
import 'navigation/app_routes.dart';
import 'screens/main_screen.dart';
import 'screens/dev_login_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ INSERT FIREBASE HERE (always first)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    // Initialize database factory for platform-specific SQLite (not supported on web)
    await DatabaseHelper.init();

    // Initialize services (SQLite database will be created automatically)
    try {
      await WordListService.init();
      await WordAttemptService.init();
      await SpacedRepetitionService.init();
      await GamificationService.init();
      await AssessmentResultService.init();
    } catch (e) {
      debugPrint('Warning: Failed to initialize database services: $e');
    }
  } else {
    debugPrint('Running on web - database services disabled');
  }

  // Initialize TTS service
  try {
    await LocalTtsService.instance.init();
    debugPrint('TTS service initialized successfully');
  } catch (e) {
    debugPrint('Warning: Failed to initialize TTS service: $e');
    // Continue anyway - the service will handle fallbacks
  }

  // Create default word lists if none exist (only for non-web platforms)
  if (!kIsWeb) {
    try {
      await WordListService.createDefaultWordLists();
    } catch (e) {
      debugPrint('Warning: Failed to create default word lists: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Reading Assistant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: DevLoginScreen(), // Change from MainScreen
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
