import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:io';
import '../models/word_list.dart';
import '../services/word_list_service.dart';

class WordListEditorScreen extends StatefulWidget {
  final String? subject;
  final String? listId;

  const WordListEditorScreen({super.key, this.subject, this.listId});

  @override
  State<WordListEditorScreen> createState() => _WordListEditorScreenState();
}

class _WordListEditorScreenState extends State<WordListEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _listNameController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bulkWordController = TextEditingController();

  List<String> words = [];
  bool isLoading = false;
  bool isEditMode = false;
  WordList? existingWordList;

  // Image scanning variables
  final ImagePicker _imagePicker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() async {
    if (widget.subject != null) {
      _subjectController.text = widget.subject!;
    }

    if (widget.listId != null) {
      setState(() {
        isEditMode = true;
        isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        final wordList = await WordListService.getWordListById(
          user.uid,
          widget.listId!,
        );
        if (wordList != null) {
          setState(() {
            existingWordList = wordList;
            _listNameController.text = wordList.listName;
            _subjectController.text = wordList.subject;
            words = List.from(wordList.words);
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Word list not found')),
            );
          }
        }
      } catch (e) {
        setState(() {
          isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading word list: $e')),
          );
        }
      }
    }
  }

  void _addBulkWords() {
    if (_bulkWordController.text.trim().isNotEmpty) {
      final bulkText = _bulkWordController.text.trim();

      // Split by various delimiters: newlines, commas, semicolons, spaces
      final newWords = bulkText
          .split(RegExp(r'[\n,;]+'))
          .map((word) => word.trim().toLowerCase())
          .where((word) => word.isNotEmpty)
          .toSet() // Remove duplicates
          .toList();

      if (newWords.isNotEmpty) {
        // Filter out words that already exist
        final wordsToAdd = newWords
            .where((word) => !words.contains(word))
            .toList();
        final duplicateCount = newWords.length - wordsToAdd.length;

        setState(() {
          words.addAll(wordsToAdd);
        });

        _bulkWordController.clear();

        String message = '${wordsToAdd.length} words added successfully';
        if (duplicateCount > 0) {
          message += ' ($duplicateCount duplicates skipped)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid words found to add')),
        );
      }
    }
  }

  Future<void> _scanImageForWords() async {
    try {
      // Show comprehensive image source selection dialog
      final String? source = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.add_a_photo, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('Scan Text from Image'),
            ],
          ),
          content: const Text(
            'Choose how you want to capture or select the image:',
          ),
          actions: [
            // Gallery option
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, 'gallery'),
                icon: const Icon(Icons.photo_library, color: Colors.green),
                label: const Text(
                  'Open Gallery',
                  style: TextStyle(fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            // Document scanner option
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context, 'document'),
                icon: const Icon(Icons.document_scanner, color: Colors.orange),
                label: const Text(
                  'Scan Document',
                  style: TextStyle(fontSize: 16),
                ),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            // Cancel option
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      );

      if (source == null) return;

      setState(() {
        isLoading = true;
      });

      XFile? pickedFile;

      // Handle different source types
      switch (source) {
        case 'gallery':
          pickedFile = await _imagePicker.pickImage(
            source: ImageSource.gallery,
            imageQuality: 80,
          );
          break;
        case 'document':
          // High quality capture for documents
          pickedFile = await _imagePicker.pickImage(
            source: ImageSource.camera,
            imageQuality: 95, // Higher quality for document text
            preferredCameraDevice: CameraDevice.rear,
          );
          break;
      }

      if (pickedFile == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Process image with ML Kit
      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract words from recognized text
      final extractedText = recognizedText.text;
      if (extractedText.trim().isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text found in the image'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Process and extract unique words
      final newWords = _extractWordsFromText(extractedText);

      if (newWords.isNotEmpty) {
        // Filter out words that already exist
        final wordsToAdd = newWords
            .where((word) => !words.contains(word))
            .toList();
        final duplicateCount = newWords.length - wordsToAdd.length;

        setState(() {
          words.addAll(wordsToAdd);
        });

        String message = '${wordsToAdd.length} words extracted from image';
        if (duplicateCount > 0) {
          message += ' ($duplicateCount duplicates skipped)';
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.green),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid words found in the image'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Clean up
      await File(pickedFile.path).delete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scanning image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<String> _extractWordsFromText(String text) {
    // Clean the text and extract individual words
    final cleanedText = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Replace punctuation with spaces
        .replaceAll(
          RegExp(r'\s+'),
          ' ',
        ) // Replace multiple spaces with single space
        .trim();

    if (cleanedText.isEmpty) return [];

    // Split into words and filter
    final words = cleanedText
        .split(' ')
        .where(
          (word) => word.isNotEmpty && word.length >= 2,
        ) // Filter out single characters
        .toSet() // Remove duplicates within the extracted text
        .toList();

    return words;
  }

  void _removeWord(int index) {
    setState(() {
      words.removeAt(index);
    });
  }

  void _saveWordList() async {
    if (_formKey.currentState!.validate() && words.isNotEmpty) {
      setState(() {
        isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        final wordList = WordList(
          id: widget.listId ?? 'list_${DateTime.now().millisecondsSinceEpoch}',
          userId: user.uid,
          subject: _subjectController.text.trim(),
          listName: _listNameController.text.trim(),
          words: words,
          createdAt: existingWordList?.createdAt ?? DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await WordListService.saveWordList(wordList);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditMode ? 'Word list updated!' : 'Word list created!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving word list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one word')),
      );
    }
  }

  void _deleteWordList() async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Delete Word List',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
        ),
        content: Text(
          'Are you sure you want to delete "${_listNameController.text}"?\n\nThis action cannot be undone and will remove all words and progress data.',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && widget.listId != null) {
      setState(() {
        isLoading = true;
      });

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          throw Exception('User not logged in');
        }

        await WordListService.deleteWordList(user.uid, widget.listId!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Word list deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting word list: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          isLoading = false;
        });
      }
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
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildEditorContent(),
              ),
            ],
          ),
        ),
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
          Expanded(
            child: Text(
              isEditMode ? 'Edit Word List' : 'Create Word List',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          // Delete button (only show in edit mode)
          if (isEditMode) ...[
            IconButton(
              onPressed: isLoading ? null : _deleteWordList,
              icon: const Icon(Icons.delete, color: Colors.red, size: 28),
              tooltip: 'Delete List',
            ),
            const SizedBox(width: 8),
          ],
          ElevatedButton.icon(
            onPressed: isLoading ? null : _saveWordList,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditorContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBasicInfo(),
            const SizedBox(height: 24),
            _buildWordInput(),
            const SizedBox(height: 24),
            _buildWordsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfo() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _subjectController,
              decoration: InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g., English, Math, Science',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.subject),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a subject';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _listNameController,
              decoration: InputDecoration(
                labelText: 'List Name',
                hintText: 'e.g., V1 - Basic Words',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.list),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a list name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordInput() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with image scan button
            Row(
              children: [
                const Icon(
                  Icons.text_fields,
                  color: Colors.deepPurple,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add Words to List',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.purple.withValues(alpha: 0.3),
                    ),
                  ),
                  child: IconButton(
                    onPressed: isLoading ? null : _scanImageForWords,
                    icon: const Icon(
                      Icons.add_a_photo,
                      color: Colors.purple,
                      size: 24,
                    ),
                    tooltip: 'Scan text from images or documents',
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 100, // smaller height than default
              child: TextField(
                controller: _bulkWordController,
                maxLines: null,
                decoration: InputDecoration(
                  hintText: 'Paste or type words...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.content_paste),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _addBulkWords,
                icon: const Icon(Icons.playlist_add),
                label: const Text('Add All Words'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordsList() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Words in List',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${words.length} words',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (words.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                ),
                child: Column(
                  children: [
                    Icon(Icons.text_fields, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No words added yet',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the input field above to add words',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: words.asMap().entries.map((entry) {
                  final index = entry.key;
                  final word = entry.value;
                  return Chip(
                    label: Text(word),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeWord(index),
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.1),
                    deleteIconColor: Colors.red,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _listNameController.dispose();
    _subjectController.dispose();
    _bulkWordController.dispose();
    _textRecognizer.close();
    super.dispose();
  }
}
