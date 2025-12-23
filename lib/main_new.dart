import 'package:flutter/material.dart';
import 'services/word_list_service.dart';
import 'services/word_attempt_service.dart';
import 'services/spaced_repetition_service.dart';
import 'navigation/app_routes.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  await WordListService.init();
  await WordAttemptService.init();
  await SpacedRepetitionService.init();

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
