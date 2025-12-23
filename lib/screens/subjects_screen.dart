import 'package:flutter/material.dart';
import '../navigation/app_routes.dart';
import '../services/word_list_service.dart';
import '../models/word_list.dart';
import 'admin_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  List<String> availableSubjects = [];
  bool isLoading = true;
  bool showDeleteButtons = false; // Control visibility of delete buttons

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = await WordListService.getAvailableSubjects();
      setState(() {
        availableSubjects = subjects;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subjects',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Admin button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminScreen(),
                ),
              );
            },
            icon: const Icon(Icons.settings),
            color: Colors.deepPurple,
            tooltip: 'Subject Management',
          ),
          // Toggle delete mode button
          IconButton(
            onPressed: () {
              setState(() {
                showDeleteButtons = !showDeleteButtons;
              });
            },
            icon: Icon(
              showDeleteButtons ? Icons.close : Icons.delete,
              color: showDeleteButtons ? Colors.red : Colors.deepPurple,
            ),
            tooltip: showDeleteButtons ? 'Cancel Delete' : 'Delete Mode',
          ),
        ],
      ),
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
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildSubjectsGrid(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(context),
        backgroundColor: Colors.deepPurple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Add Subject',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSubjectsGrid(BuildContext context) {
    // Default subjects with their icons and colors (Art and History removed)
    final defaultSubjects = [
      SubjectData(
        name: 'English',
        icon: Icons.library_books,
        color: Colors.blue,
      ),
      SubjectData(name: 'Math', icon: Icons.calculate, color: Colors.green),
      SubjectData(name: 'Science', icon: Icons.science, color: Colors.purple),
      SubjectData(name: 'Social', icon: Icons.public, color: Colors.teal), // Changed from Geography to Social
    ];

    // Combine default subjects with available subjects from database
    final allSubjects = <SubjectData>[];
    final subjectNames = <String>{};

    // Add default subjects
    for (final defaultSubject in defaultSubjects) {
      allSubjects.add(defaultSubject);
      subjectNames.add(defaultSubject.name);
    }

    // Add custom subjects that aren't in defaults
    for (final subjectName in availableSubjects) {
      if (!subjectNames.contains(subjectName)) {
        allSubjects.add(
          SubjectData(
            name: subjectName,
            icon: _getIconForSubject(
              subjectName,
              availableSubjects,
            ), // Unique icon for custom subjects
            color: _getColorForSubject(
              subjectName,
              availableSubjects,
            ), // Unique color for custom subjects
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _getCrossAxisCount(context),
          childAspectRatio: 1.0,
          crossAxisSpacing: 16.0,
          mainAxisSpacing: 16.0,
        ),
        itemCount: allSubjects.length,
        itemBuilder: (context, index) {
          final subject = allSubjects[index];
          return _buildSubjectCard(context, subject);
        },
      ),
    );
  }

  Color _getColorForSubject(String subjectName, List<String> existingSubjects) {
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
      Colors.deepOrange,
      Colors.lightBlue,
      Colors.lime,
      Colors.deepPurple,
      Colors.brown,
      Colors.grey,
    ];

    // Get default subject names to avoid conflicts
    final defaultSubjectNames = [
      'English',
      'Math',
      'Science',
      'Social',
    ];

    // If this is a default subject, return its predefined color
    final defaultSubjects = [
      SubjectData(
        name: 'English',
        icon: Icons.library_books,
        color: Colors.blue,
      ),
      SubjectData(name: 'Math', icon: Icons.calculate, color: Colors.green),
      SubjectData(name: 'Science', icon: Icons.science, color: Colors.purple),
      SubjectData(name: 'Social', icon: Icons.public, color: Colors.teal),
    ];

    for (final defaultSubject in defaultSubjects) {
      if (defaultSubject.name == subjectName) {
        return defaultSubject.color;
      }
    }

    // For custom subjects, get a unique color based on index
    final customSubjects = existingSubjects
        .where((s) => !defaultSubjectNames.contains(s))
        .toList();
    final subjectIndex = customSubjects.indexOf(subjectName);

    if (subjectIndex >= 0) {
      // Use available colors starting from index 6 (after default colors)
      final colorIndex = (6 + subjectIndex) % colors.length;
      return colors[colorIndex];
    }

    // Fallback color
    return Colors.grey;
  }

  IconData _getIconForSubject(
    String subjectName,
    List<String> existingSubjects,
  ) {
    final icons = [
      Icons.school,
      Icons.book,
      Icons.menu_book,
      Icons.auto_stories,
      Icons.psychology,
      Icons.lightbulb,
      Icons.quiz,
      Icons.assignment,
      Icons.language,
      Icons.computer,
      Icons.music_note,
      Icons.sports,
      Icons.camera_alt,
      Icons.build,
      Icons.nature,
      Icons.business,
    ];

    // Get default subject names
    final defaultSubjectNames = [
      'English',
      'Math',
      'Science',
      'Social',
    ];

    // If this is a default subject, return its predefined icon
    final defaultSubjects = [
      SubjectData(
        name: 'English',
        icon: Icons.library_books,
        color: Colors.blue,
      ),
      SubjectData(name: 'Math', icon: Icons.calculate, color: Colors.green),
      SubjectData(name: 'Science', icon: Icons.science, color: Colors.purple),
      SubjectData(name: 'Social', icon: Icons.public, color: Colors.teal),
    ];

    for (final defaultSubject in defaultSubjects) {
      if (defaultSubject.name == subjectName) {
        return defaultSubject.icon;
      }
    }

    // For custom subjects, get a unique icon based on index
    final customSubjects = existingSubjects
        .where((s) => !defaultSubjectNames.contains(s))
        .toList();
    final subjectIndex = customSubjects.indexOf(subjectName);

    if (subjectIndex >= 0) {
      return icons[subjectIndex % icons.length];
    }

    // Fallback icon
    return Icons.school;
  }

  int _getCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 800) return 4;
    if (width > 600) return 3;
    return 2;
  }

  Widget _buildSubjectCard(BuildContext context, SubjectData subject) {
    return Hero(
      tag: subject.name,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: () {
            if (subject.isAddButton) {
              _showAddSubjectDialog(context);
            } else if (!showDeleteButtons) {
              NavigationHelper.navigateToSubjectWordLists(
                context,
                subject.name,
              );
            }
          },
          onLongPress: subject.isAddButton
              ? null
              : () => _showDeleteSubjectDialog(context, subject.name),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: subject.isAddButton
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.withValues(alpha: 0.3),
                        Colors.grey.withValues(alpha: 0.2),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        subject.color.withValues(alpha: 0.8),
                        subject.color.withValues(alpha: 0.6),
                      ],
                    ),
              border: subject.isAddButton
                  ? Border.all(
                      color: Colors.grey.withValues(alpha: 0.5),
                      width: 2,
                      style: BorderStyle.solid,
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      subject.icon,
                      size: 48,
                      color: subject.isAddButton
                          ? Colors.grey[600]
                          : Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subject.name,
                      style: TextStyle(
                        fontSize: subject.isAddButton ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: subject.isAddButton
                            ? Colors.grey[700]
                            : Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (subject.isAddButton)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Tap to create',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
                // Add delete button for non-add subjects (only when showDeleteButtons is true)
                if (!subject.isAddButton && showDeleteButtons)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () =>
                          _showDeleteSubjectDialog(context, subject.name),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDeleteSubjectDialog(
    BuildContext context,
    String subjectName,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning, color: Colors.red, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Subject',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete the subject "$subjectName"?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will permanently delete all word lists, progress data, and practice history for this subject.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteSubject(subjectName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteSubject(String subjectName) async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Text('Deleting subject "$subjectName"...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Delete the subject and all its word lists
      await WordListService.deleteSubject(subjectName);

      // Refresh the subjects list
      await _loadSubjects();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Subject "$subjectName" deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting subject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddSubjectDialog(BuildContext context) async {
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController listNameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_box, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add New Subject',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create a new subject by adding its first word list:',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: subjectController,
                  decoration: InputDecoration(
                    labelText: 'Subject Name',
                    hintText: 'e.g., Physics, French, Music',
                    prefixIcon: const Icon(Icons.school),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: listNameController,
                  decoration: InputDecoration(
                    labelText: 'First Word List Name',
                    hintText: 'e.g., Basic Terms, Lesson 1',
                    prefixIcon: const Icon(Icons.list_alt),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can add words to this list after creation.',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => _createNewSubject(
                context,
                subjectController.text.trim(),
                listNameController.text.trim(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewSubject(
    BuildContext context,
    String subjectName,
    String listName,
  ) async {
    if (subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a subject name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (listName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a word list name'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check if subject already exists
    if (availableSubjects.contains(subjectName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subject "$subjectName" already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    // Capture navigator and messenger before async operations
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // Create a new word list for this subject
      final newWordList = WordList(
        id: '${subjectName.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
        subject: subjectName,
        listName: listName,
        words: [], // Start with empty list
      );

      await WordListService.saveWordList(newWordList);

      // Refresh the subjects list
      await _loadSubjects();

      if (!mounted) return;
      navigator.pop();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Subject "$subjectName" created successfully!'),
          backgroundColor: Colors.green,
          action: SnackBarAction(
            label: 'Add Words',
            textColor: Colors.white,
            onPressed: () {
              if (mounted) {
                NavigationHelper.navigateToSubjectWordLists(
                  context,
                  subjectName,
                );
              }
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error creating subject: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class SubjectData {
  final String name;
  final IconData icon;
  final Color color;
  final bool isAddButton;

  SubjectData({
    required this.name,
    required this.icon,
    required this.color,
    this.isAddButton = false,
  });
}
