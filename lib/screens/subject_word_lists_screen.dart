import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../navigation/app_routes.dart';
import '../models/word_list.dart';
import '../services/word_list_service.dart';

class SubjectWordListsScreen extends StatefulWidget {
  final String subject;

  const SubjectWordListsScreen({super.key, required this.subject});

  @override
  State<SubjectWordListsScreen> createState() => _SubjectWordListsScreenState();
}

class _SubjectWordListsScreenState extends State<SubjectWordListsScreen> {
  List<WordList> wordLists = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWordLists();
  }

  Future<void> _loadWordLists() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final lists = await WordListService.getWordListsBySubject(
        user.uid,
        widget.subject,
      );
      setState(() {
        wordLists = lists;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildWordListsList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await NavigationHelper.navigateToWordListEditor(
            context,
            subject: widget.subject,
          );
          // Refresh the list after returning from editor
          _loadWordLists();
        },
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.subject} Word Lists',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordListsList() {
    if (wordLists.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No word lists found for ${widget.subject}',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await NavigationHelper.navigateToWordListEditor(
                  context,
                  subject: widget.subject,
                );
                // Refresh the list after returning from editor
                _loadWordLists();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Create First List'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: wordLists.length,
      itemBuilder: (context, index) {
        final wordList = wordLists[index];
        return _buildWordListCard(wordList);
      },
    );
  }

  Widget _buildWordListCard(WordList wordList) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    wordList.listName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${wordList.words.length} words',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.visibility,
                  label: 'Visual',
                  color: Colors.blue,
                  onPressed: () {
                    NavigationHelper.navigateToPractice(
                      context,
                      wordList,
                      'visual',
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.volume_up,
                  label: 'Auditory',
                  color: Colors.green,
                  onPressed: () {
                    NavigationHelper.navigateToPractice(
                      context,
                      wordList,
                      'auditory',
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.edit,
                  label: 'Edit',
                  color: Colors.orange,
                  onPressed: () async {
                    final bool? wasDeleted =
                        await NavigationHelper.navigateToWordListEditor(
                          context,
                          subject: widget.subject,
                          listId: wordList.id,
                        );

                    // Refresh the list if the word list was deleted or modified
                    if (wasDeleted == true || mounted) {
                      _loadWordLists();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
