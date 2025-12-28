import 'package:flutter/material.dart';
import '../screens/subjects_screen.dart';
import '../screens/subject_word_lists_screen.dart';
import '../screens/practice_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/word_list_editor_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String subjectWordLists = '/subject-word-lists';
  static const String practice = '/practice';
  static const String progress = '/progress';
  static const String wordListEditor = '/word-list-editor';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(builder: (_) => const SubjectsScreen());

      case subjectWordLists:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) =>
              SubjectWordListsScreen(subject: args?['subject'] ?? 'Unknown'),
        );

      case practice:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => PracticeScreen(
            wordList: args?['wordList'],
            mode: args?['mode'] ?? 'auditory',
          ),
        );

      case progress:
        return MaterialPageRoute(builder: (_) => const ProgressScreen());

      case wordListEditor:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => WordListEditorScreen(
            subject: args?['subject'],
            listId: args?['listId'],
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }
}

class NavigationHelper {
  static void navigateToSubjectWordLists(BuildContext context, String subject) {
    Navigator.pushNamed(
      context,
      AppRoutes.subjectWordLists,
      arguments: {'subject': subject},
    );
  }

  static void navigateToPractice(
    BuildContext context,
    dynamic wordList,
    String mode,
  ) {
    Navigator.pushNamed(
      context,
      AppRoutes.practice,
      arguments: {'wordList': wordList, 'mode': mode},
    );
  }

  static void navigateToProgress(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.progress);
  }

  static Future<bool?> navigateToWordListEditor(
    BuildContext context, {
    String? subject,
    String? listId,
  }) {
    return Navigator.pushNamed(
      context,
      AppRoutes.wordListEditor,
      arguments: {'subject': subject, 'listId': listId},
    ).then((result) => result as bool?);
  }
}
