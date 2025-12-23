import 'package:flutter/material.dart';
import '../services/word_list_service.dart';
import 'network_test_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<String> _subjects = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final wordLists = await WordListService.getAllWordLists();
      final subjects = wordLists.map((list) => list.subject).toSet().toList();
      subjects.sort();

      setState(() {
        _subjects = subjects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading subjects: $e')));
      }
    }
  }

  Future<void> _quickCleanup() async {
    // Remove Art and History if they exist
    final subjectsToRemove = ['Art', 'History'];
    bool hasChanges = false;

    for (String subject in subjectsToRemove) {
      if (_subjects.contains(subject)) {
        await _deleteSubject(subject, showSnackbar: false);
        hasChanges = true;
      }
    }

    // Rename Geography to Social if it exists
    if (_subjects.contains('Geography')) {
      await _renameSubject('Geography', 'Social', showSnackbar: false);
      hasChanges = true;
    }

    if (hasChanges) {
      await _loadSubjects();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Quick cleanup completed! Removed Art, History and renamed Geography to Social',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No cleanup needed - subjects are already clean'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _renameSubject(
    String oldName,
    String newName, {
    bool showSnackbar = true,
  }) async {
    try {
      await WordListService.renameSubject(oldName, newName);
      await _loadSubjects();
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Renamed "$oldName" to "$newName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error renaming subject: $e')));
      }
    }
  }

  Future<void> _deleteSubject(
    String subject, {
    bool showSnackbar = true,
  }) async {
    try {
      await WordListService.deleteSubject(subject);
      await _loadSubjects();
      if (showSnackbar && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "$subject" and all its word lists')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting subject: $e')));
      }
    }
  }

  void _showRenameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename "$currentName"'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New subject name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != currentName) {
                Navigator.pop(context);
                _renameSubject(currentName, newName);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "$subject"?'),
        content: const Text(
          'This will permanently delete the subject and all its word lists. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              _deleteSubject(subject);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Subject Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Quick cleanup button
          IconButton(
            onPressed: _quickCleanup,
            icon: const Icon(Icons.cleaning_services),
            tooltip:
                'Quick Cleanup (Remove Art, History, rename Geography→Social)',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _subjects.isEmpty
            ? const Center(
                child: Text(
                  'No subjects found',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              )
            : Column(
                children: [
                  // Quick action cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Quick Actions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_subjects.contains('Geography'))
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _renameSubject('Geography', 'Social'),
                                    icon: const Icon(Icons.edit),
                                    label: const Text('Geography→Social'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                if (_subjects.contains('Art'))
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showDeleteConfirmation('Art'),
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete Art'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                if (_subjects.contains('History'))
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _showDeleteConfirmation('History'),
                                    icon: const Icon(Icons.delete),
                                    label: const Text('Delete History'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const NetworkTestScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.network_check),
                                  label: const Text('Network Test'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Subject list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _subjects.length,
                      itemBuilder: (context, index) {
                        final subject = _subjects[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _getSubjectColor(subject),
                              child: Icon(
                                _getSubjectIcon(subject),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              subject,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  onPressed: () => _showRenameDialog(subject),
                                  icon: const Icon(Icons.edit),
                                  color: Colors.orange,
                                  tooltip: 'Rename',
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _showDeleteConfirmation(subject),
                                  icon: const Icon(Icons.delete),
                                  color: Colors.red,
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'english':
        return Colors.blue;
      case 'math':
        return Colors.green;
      case 'science':
        return Colors.purple;
      case 'social':
      case 'geography':
        return Colors.teal;
      case 'history':
        return Colors.orange;
      case 'art':
        return Colors.pink;
      default:
        return Colors.grey;
    }
  }

  IconData _getSubjectIcon(String subject) {
    switch (subject.toLowerCase()) {
      case 'english':
        return Icons.library_books;
      case 'math':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'social':
      case 'geography':
        return Icons.public;
      case 'history':
        return Icons.history_edu;
      case 'art':
        return Icons.palette;
      default:
        return Icons.subject;
    }
  }
}
