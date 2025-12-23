import 'package:flutter/material.dart';
import 'services/database_helper.dart';
import 'services/word_list_service.dart';
import 'services/word_attempt_service.dart';
import 'services/spaced_repetition_service.dart';
import 'services/gamification_service.dart';
import 'services/local_tts_service.dart';
import 'assessment_result_service.dart';
import 'navigation/app_routes.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database factory for platform-specific SQLite
  await DatabaseHelper.init();

  // Initialize services (SQLite database will be created automatically)
  await WordListService.init();
  await WordAttemptService.init();
  await SpacedRepetitionService.init();
  await GamificationService.init();
  await AssessmentResultService.init();

  // Initialize TTS service
  try {
    await LocalTtsService.instance.init();
    debugPrint('TTS service initialized successfully');
  } catch (e) {
    debugPrint('Warning: Failed to initialize TTS service: $e');
    // Continue anyway - the service will handle fallbacks
  }

  // Create default word lists if none exist
  await WordListService.createDefaultWordLists();

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
      home: const MainScreen(),
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
