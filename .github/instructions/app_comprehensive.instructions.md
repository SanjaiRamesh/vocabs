---
applyTo: '**'
---
project: AI Reading Assistant
framework: Flutter
audience: Early-grade children (age 5–10)
database: Hive (preferred) or SQLite
export_format: XLSX and CSV
style: child-friendly UI (bright colors, large text, icons)

# DEPENDENCIES (pubspec.yaml)
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  flutter_sound: ^9.3.10
  permission_handler: ^12.0.1
  speech_to_text: ^7.1.0
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.2
  csv: ^6.0.0
  flutter_tts: ^4.0.2
  image_picker: ^1.0.4
  google_mlkit_text_recognition: ^0.15.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  hive_generator: ^2.0.1
  build_runner: ^2.4.11

# MAIN APPLICATION ENTRY
main_dart:
  path: lib/main.dart
  implementation: |
    import 'package:flutter/material.dart';
    import 'package:hive_flutter/hive_flutter.dart';
    import 'services/word_list_service.dart';
    import 'services/word_attempt_service.dart';
    import 'services/spaced_repetition_service.dart';
    import 'navigation/app_routes.dart';
    import 'screens/main_screen.dart';

    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Hive.initFlutter();
      await WordListService.init();
      await WordAttemptService.init();
      await SpacedRepetitionService.init();
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

modules:

  - name: AppLayout
    description: >
      Base UI shell for the app with header, footer, and SafeArea layout.
    path: lib/widgets/app_layout.dart
    implementation: |
      - Gradient background: LinearGradient with pastel colors (light blue, purple, green)
      - Header with app title styled with deepPurple color, fontSize 28, bold
      - Bottom navigation with rounded corners (topLeft/topRight: 20px)
      - BoxShadow on bottom nav with black opacity 0.1
      - Tab icons: Home, Practice, Progress with corresponding colors
      - Uses TickerProviderStateMixin for animations
    features:
      - Header: App title "RA" left-aligned
      - Footer: Tab navigation bar (Home, Practice, Progress)
      - Apply rounded buttons, animations, and child-friendly themes
      - Scaffold background color: pastel gradient
    code_structure: |
      class AppLayout extends StatefulWidget {
        final Widget child;
        final String title;
        final int currentIndex;
        final Function(int) onTabChanged;
        
        // Gradient background: Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)
        // Bottom nav with ClipRRect and borderRadius
        // BottomNavigationBar with 3 items: Home, Practice, Progress
      }

  - name: MainScreen
    description: >
      Central navigation hub using PageView and bottom navigation.
    path: lib/screens/main_screen.dart
    implementation: |
      - PageController for smooth transitions between tabs
      - Three main pages: SubjectsScreen, Practice placeholder, ProgressScreen
      - Integrates with AppLayout widget for consistent UI
      - Handles tab changes with setState and pageController.jumpToPage()
    structure: |
      class MainScreen extends StatefulWidget {
        int _currentIndex = 0;
        PageController _pageController = PageController();
        List<Widget> _pages = [SubjectsScreen(), Practice, ProgressScreen()];
        List<String> _titles = ['RA', 'Practice', 'Progress'];
        
        // AppLayout wrapper with PageView child
        // onTabChanged updates currentIndex and jumps to page
      }

  - name: Navigation
    description: >
      App routing using Navigator with named routes and NavigationHelper.
    path: lib/navigation/app_routes.dart
    implementation: |
      - Static route constants: home, subjectWordLists, practice, progress, wordListEditor
      - generateRoute method with switch statement for route handling
      - NavigationHelper class with static methods for navigation
      - Argument passing through RouteSettings.arguments as Map<String, dynamic>
    routes:
      - Home (/) → SubjectsScreen
      - Word Lists (/subject-word-lists) → SubjectWordListsScreen with subject arg
      - Practice (/practice) → PracticeScreen with wordList and mode args
      - Progress (/progress) → ProgressScreen
      - Word List Editor (/word-list-editor) → WordListEditorScreen with subject/listId args
    helper_methods: |
      static void navigateToSubjectWordLists(BuildContext context, String subject)
      static void navigateToPractice(BuildContext context, dynamic wordList, String mode)
      static void navigateToProgress(BuildContext context)
      static void navigateToWordListEditor(BuildContext context, String? subject, String? listId)

  - name: SubjectsScreen
    description: >
      Grid of subjects (English, Math, Science, etc.) with tappable cards.
    path: lib/screens/subjects_screen.dart
    implementation: |
      - Gradient background matching AppLayout
      - GridView.builder with crossAxisCount based on screen width
      - Subject cards with ElevatedButton styling
      - Card shadows and rounded corners (borderRadius: 15)
      - Icon and text layout in Column with SizedBox spacing
      - NavigationHelper.navigateToSubjectWordLists on tap
      - Loads subjects using WordListService.getAvailableSubjects()
    behavior:
      - On tap → NavigationHelper.navigateToSubjectWordLists(context, subject)
      - Grid count: MediaQuery.of(context).size.width > 600 ? 3 : 2
      - Each card shows subject icon (Icons.subject) and name
    styling: |
      - Card elevation: 5
      - BorderRadius: 15
      - Background: Colors.white
      - Text style: fontSize 18, fontWeight bold, color deepPurple
      - Icon size: 50, color deepPurple
      - Gradient background: LinearGradient with E1F5FE, F3E5F5, E8F5E8

  - name: SubjectWordListsScreen
    description: >
      Displays all word lists for the selected subject with action buttons.
    path: lib/screens/subject_word_lists_screen.dart
    implementation: |
      - AppBar with subject name and gradient background
      - ListView.builder for word lists
      - Card widgets with elevation and rounded corners
      - Row layout: ListTile + action buttons (View, Audio, Edit)
      - FloatingActionButton for adding new word lists
      - Uses WordListService.getWordListsBySubject() for data
    features:
      - Each list shows:
          - Name (title)
          - Word count (subtitle: "${wordList.words.length} words")
          - 👁 View button (shows word list in dialog)
          - 🔊 Auditory button (navigates to practice auditory mode)
          - ✏️ Edit button (navigates to WordListEditor)
      - Add button (FloatingActionButton) routes to WordListEditor
    layout: |
      - Card with ListTile(title: listName, subtitle: word count)
      - Row of IconButtons: visibility, volume_up, edit
      - FloatingActionButton with add icon
      - Loading state with CircularProgressIndicator

  - name: WordListEditor
    description: >
      Create or edit a word list with image scanning and bulk word input.
    path: lib/screens/word_list_editor_screen.dart
    implementation: |
      - Form with GlobalKey<FormState> for validation
      - TextEditingController for listName, subject, word, bulkWord inputs
      - Image scanning using ImagePicker + GoogleMLKit TextRecognizer
      - Bulk word input with comma/newline separation
      - Individual word chips with delete functionality
      - Save/Update logic with WordListService
    fields:
      - List Name (required)
      - Subject (required)
      - Individual word input
      - Bulk word input (textarea)
      - Image scanning for word extraction
    features: |
      - Photo scanning: ImagePicker → TextRecognizer → extract words
      - Bulk input: split by comma, newline, or whitespace
      - Word chips: Chip widgets with deleteIcon
      - Form validation with error messages
      - Loading states during save operations
      - Camera permission handling
    ui_components: |
      - TextFormField for list name and subject
      - TextField for individual word input
      - TextField for bulk word input (maxLines: 3)
      - Wrap widget for word chips display
      - ElevatedButton for photo scanning
      - FloatingActionButton for save action

  - name: PracticeScreen
    description: >
      Interactive practice screen with auditory and visual modes.
    path: lib/screens/practice_screen.dart
    implementation: |
      - TickerProviderStateMixin for animations
      - FlutterTts for text-to-speech
      - SpeechToText for voice recognition
      - AnimationController with scaleAnimation
      - Current word display with large text (fontSize 32)
      - Input handling: TextField (auditory) or microphone (visual)
      - Result feedback with color-coded messages
      - Progress tracking with WordAttemptService
    modes:
      - Auditory Mode: plays word via TTS, child types response in TextField
      - Visual Mode: shows word on screen, child speaks response via microphone
    logic:
      - Stores only first attempt per word per day (WordAttemptService.saveAttempt)
      - Color feedback: correct (green), wrong (red), missed (yellow)
      - Supports retry option but doesn't re-record to database
      - Updates spaced repetition schedule via SpacedRepetitionService
    ui_flow: |
      - AppBar with mode indicator
      - Large text display for current word (fontSize 32)
      - Input area: TextField or microphone button
      - Result feedback with AnimatedContainer
      - Next/Retry buttons
      - Progress indicator showing current word index

  - name: ProgressScreen
    description: >
      TabBar-based progress tracking with horizontal scrollable tables.
    path: lib/screens/progress_screen.dart
    implementation: |
      - TickerProviderStateMixin with TabController
      - TabBar for subjects with scrollable tabs
      - TabBarView with subject-specific progress tables
      - Horizontal DataTable with spaced repetition columns (D1, D2, D4, D8, D16, D30, D60, D150)
      - Color-coded cells: green (correct), red (incorrect), yellow (missed)
      - Interactive cells with onTap showing detailed attempt info
      - Sample data generation for testing (debug button)
    features:
      - Subject tabs with TabController (length: subjects.length)
      - Horizontal scrollable table per word list
      - Spaced repetition columns showing step progression
      - Color-coded result visualization
      - Expandable word list sections (ExpansionTile)
      - Detail dialogs showing attempt information
    structure: |
      - AppBar with refresh and debug buttons
      - TabBar with subject names (isScrollable: true)
      - TabBarView containing:
        - ListView of ExpansionTile widgets per word list
        - Horizontal SingleChildScrollView with DataTable
        - Word rows with repetition step columns (D1-D150)
        - Color-coded cells with GestureDetector for details
    table_layout: |
      - First column: Word name (fixed width: 120)
      - Remaining columns: D1, D2, D4, D8, D16, D30, D60, D150 (width: 80 each)
      - Header row with step labels and day numbers
      - Data rows with colored containers based on attempt result
      - Empty cells for steps not yet attempted

  - name: SpacedRepetitionEngine
    description: >
      Drives scheduling of word reviews with fixed day intervals.
    path: lib/services/spaced_repetition_service.dart
    implementation: |
      - Hive box storage with WordSchedule model
      - Fixed schedule: [1, 2, 4, 8, 16, 30, 60, 150] days
      - updateWordSchedule method handling correct/incorrect responses
      - Hard word marking after 3 incorrect attempts
      - Next review date calculation with date arithmetic
    schedule_days: [1, 2, 4, 8, 16, 30, 60, 150]
    rules:
      - After correct response: advance to next repetition step
      - After incorrect: reset to next day, increment incorrect count
      - After 3 incorrect attempts: mark as hard word
      - All 8 fixed review dates maintained regardless of correctness
    model: |
      @HiveType(typeId: 4)
      class WordSchedule extends HiveObject {
        @HiveField(0) String word;
        @HiveField(1) int repetitionStep;  // 0-7 index into schedule array
        @HiveField(2) String lastReviewDate;  // YYYY-MM-DD
        @HiveField(3) String nextReviewDate;  // YYYY-MM-DD
        @HiveField(4) int incorrectCount;    // Counter for failed attempts
        @HiveField(5) bool isHard;           // Marked after 3 failures
      }
    methods: |
      static Future<void> updateWordSchedule(String word, bool isCorrect)
      static Future<WordSchedule?> getWordSchedule(String word)
      static Future<List<WordSchedule>> getWordsForReview(String date)
      static String _calculateNextReviewDate(String currentDate, int repetitionStep)

  - name: DataModel
    description: >
      Hive-based data models with type adapters and compound keys.
    models:
      - WordList (typeId: 1):
          path: lib/models/word_list.dart
          fields: id(String), subject(String), listName(String), words(List<String>), createdAt(DateTime), updatedAt(DateTime)
          extends: HiveObject
          methods: toString() override
      - WordItem (typeId: 2):
          fields: word(String), imagePath(String?), exampleSentence(String?), audioPath(String?)
          extends: HiveObject
      - WordAttempt (typeId: 3):
          path: lib/models/word_attempt.dart
          fields: word(String), date(String YYYY-MM-DD), result(String enum), type(String enum), repetitionStep(int), isHard(bool), subject(String), listName(String), heardOrTyped(String)
          extends: HiveObject
          compound_key: "${word}_${date}"
          result_values: ["correct", "incorrect", "missed"]
          type_values: ["auditory", "visual"]
      - WordSchedule (typeId: 4):
          path: lib/services/spaced_repetition_service.dart
          fields: word(String), repetitionStep(int), lastReviewDate(String), nextReviewDate(String), incorrectCount(int), isHard(bool)
          extends: HiveObject
    notes:
      - All models extend HiveObject for database operations
      - Use @HiveType and @HiveField annotations
      - Generate adapters with hive_generator and build_runner
      - Only one WordAttempt per word per day (compound key enforcement)
      - Run: flutter packages pub run build_runner build

  - name: HardWordsManager
    description: >
      Tracks and manages words marked as difficult.
    implementation: |
      - Integrated into WordAttemptService.markWordAsHard()
      - Updates isHard field on all attempts for word+subject
      - Filtered queries via WordAttemptService.getHardWords()
      - Visual indicators in progress tracking (different background colors)
    behavior:
      - Mark word as hard after 3 incorrect attempts in SpacedRepetitionService
      - Filter hard words in practice mode for focused review
      - Export hard words in separate section of reports
      - Display hard words with different styling in progress view

  - name: ExportModule
    description: >
      CSV/XLSX export functionality for assessment reports.
    implementation: |
      - Uses csv package for CSV generation
      - File structure: subject_assessment.csv
      - Columns: word, date, heard_typed, result, subject, list_name
      - Color coding preserved through conditional formatting
      - Save to device storage using path_provider
    structure:
      - File name: <subject>_assessment.csv/xlsx
      - Headers: Word, Date, Input, Result, Subject, List
      - Color format: correct(green), incorrect(red), missed(yellow)
      - Save location: app documents directory

# SERVICES LAYER

services:
  - name: WordListService
    path: lib/services/word_list_service.dart
    implementation: |
      - Hive box: 'word_lists'
      - CRUD operations: getAllWordLists, getWordListsBySubject, getWordListById
      - Default data creation: createDefaultWordLists with sample English/Math/Science lists
      - Subject aggregation: getAvailableSubjects returns unique subjects
    box_name: 'word_lists'
    methods: |
      static Future<void> init() - Initialize Hive adapters and open box
      static Future<List<WordList>> getAllWordLists()
      static Future<List<WordList>> getWordListsBySubject(String subject)
      static Future<WordList?> getWordListById(String id)
      static Future<void> saveWordList(WordList wordList)
      static Future<void> deleteWordList(String id)
      static Future<void> createDefaultWordLists()
      static List<String> getAvailableSubjects() - Returns unique subjects from all lists
    default_data: |
      - English V1: ['find', 'put', 'what', 'where', 'when', 'who', 'why', 'how']
      - English V2: ['the', 'and', 'for', 'are', 'but', 'not', 'you', 'all']
      - Science Lesson 1: ['atom', 'cell', 'energy', 'matter', 'force', 'light']
      - Math Numbers: ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight']

  - name: WordAttemptService
    path: lib/services/word_attempt_service.dart
    implementation: |
      - Hive box: 'word_attempts'
      - First-attempt-per-day enforcement in saveAttempt method
      - Progress statistics calculation: getProgressStats
      - Sample data generation for testing: generateSampleData
      - Hard word management: markWordAsHard
    box_name: 'word_attempts'
    methods: |
      static Future<void> init() - Initialize Hive adapters and open box
      static Future<void> saveAttempt(WordAttempt attempt) - Checks for existing attempt on same date
      static Future<List<WordAttempt>> getAllAttempts()
      static Future<List<WordAttempt>> getAttemptsBySubject(String subject)
      static Future<List<WordAttempt>> getAttemptsByWordList(String subject, String listName)
      static Future<WordAttempt?> getAttemptByWordAndDate(String word, String date)
      static Future<List<WordAttempt>> getHardWords()
      static Future<void> markWordAsHard(String word, String subject)
      static Future<Map<String, dynamic>> getProgressStats(String subject)
      static Future<void> generateSampleData() - Creates realistic test data
    sample_data_logic: |
      - Generate attempts for last 30 days
      - Random distribution of correct/incorrect/missed results
      - Realistic repetition step progression
      - Some words marked as hard for testing

  - name: SpacedRepetitionService
    path: lib/services/spaced_repetition_service.dart
    implementation: |
      - Hive box: 'spaced_repetition'
      - Fixed schedule array: [1, 2, 4, 8, 16, 30, 60, 150]
      - Date arithmetic for next review calculation
      - Incorrect attempt tracking and hard word marking
    box_name: 'spaced_repetition'
    schedule: [1, 2, 4, 8, 16, 30, 60, 150]
    methods: |
      static Future<void> init() - Initialize Hive adapters and open box
      static Future<void> updateWordSchedule(String word, bool isCorrect)
      static Future<WordSchedule?> getWordSchedule(String word)
      static Future<List<WordSchedule>> getWordsForReview(String date)
      static Future<List<WordSchedule>> getHardWords()
      static Future<List<WordSchedule>> getAllSchedules()
      static String _calculateNextReviewDate(String currentDate, int repetitionStep)
      static String _addDaysToDate(String dateString, int days)

# UI STYLING & THEME

styling:
  colors:
    primary: Color(0xFF6B73FF)
    background_gradient: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)]
    card_background: Colors.white
    success: Colors.green
    error: Colors.red
    warning: Colors.orange / Colors.yellow
    text_primary: Colors.deepPurple
    progress_screen_bg: Color(0xFFF8F9FF)
  typography:
    header: fontSize 24-28, fontWeight bold
    body: fontSize 16-18
    button: fontSize 16, fontWeight w600
    large_display: fontSize 32 (for practice words)
    chip_text: fontSize 14
  components:
    card_elevation: 5
    border_radius: 15
    button_padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12)
    icon_size: 50 (subject cards), 24 (buttons)
    table_cell_width: 80
    word_column_width: 120

ui_guidelines:
  - Use LinearGradient backgrounds for visual appeal
  - Large text (18pt+) for readability by children
  - Rounded corners (15px) on all interactive elements
  - Color-coded feedback: green/red/yellow for immediate recognition
  - Icons with text labels for non-readers
  - Elevation and shadows for depth perception
  - Hero animations for smooth transitions
  - Loading states with CircularProgressIndicator
  - SnackBar messages for user feedback
  - SafeArea for proper display on various devices

# ASSETS & FONTS

assets:
  fonts:
    - family: OpenDyslexic
      fonts:
        - asset: assets/fonts/OpenDyslexic-Regular.otf
        - asset: assets/fonts/OpenDyslexic-Bold.otf
          weight: 700

voice_support:
  - flutter_tts: Text-to-speech for word pronunciation
  - speech_to_text: Voice recognition for spoken responses
  - permission_handler: Microphone permission management
  - Audio feedback with play/pause controls in practice mode
  - TTS initialization and configuration for child-friendly voice

# BUILD CONFIGURATION

build_setup:
  required_commands: |
    flutter clean
    flutter pub get
    flutter packages pub run build_runner build
  generated_files: |
    - lib/models/word_list.g.dart
    - lib/models/word_attempt.g.dart  
    - lib/services/spaced_repetition_service.g.dart
  android_permissions: |
    - RECORD_AUDIO (speech recognition)
    - CAMERA (image scanning)
    - WRITE_EXTERNAL_STORAGE (file export)
  
# DEVELOPMENT NOTES

implementation_notes:
  critical_patterns: |
    - All async operations use try-catch with mounted checks
    - Navigator and ScaffoldMessenger captured before async calls
    - Hive boxes initialized in service init() methods
    - Only first attempt per word per day stored in database
    - TabController disposed properly to prevent memory leaks
    - BuildContext checks with mounted before setState calls
  performance: |
    - Horizontal scroll tables for large datasets
    - Lazy loading with ListView.builder
    - Efficient Hive queries with indexing
    - Sample data generation for testing without real usage
  debugging: |
    - Sample data generation button in ProgressScreen
    - Debug actions in app bars for development
    - Comprehensive error handling with user-friendly messages
    - Console logging for development tracking
