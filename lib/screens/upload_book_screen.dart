import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/book.dart';
import '../services/book_service.dart';

class UploadBookScreen extends StatefulWidget {
  final Book? book; // For editing existing book
  
  const UploadBookScreen({super.key, this.book});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageTextController = TextEditingController();
  final _bulkPagesController = TextEditingController();

  List<String> _pages = [];
  String _selectedDifficulty = 'Beginner';
  List<String> _tags = [];
  String _newTag = '';
  bool _isLoading = false;
  bool _isScanning = false;
  File? _coverImage;

  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  final List<String> _difficulties = [
    'Beginner',
    'Elementary',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _pageTextController.dispose();
    _bulkPagesController.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeForEdit();
  }

  void _initializeForEdit() {
    if (widget.book != null) {
      // Pre-fill form fields with existing book data
      _titleController.text = widget.book!.title;
      _authorController.text = widget.book!.author;
      _descriptionController.text = widget.book!.description;
      _selectedDifficulty = widget.book!.difficulty ?? 'Beginner';
      _pages = List<String>.from(widget.book!.pages);
      _tags = widget.book!.tags != null ? List<String>.from(widget.book!.tags!) : [];
      
      // Note: Cover image path from existing book - for display only
      // User can change it by picking a new one
    }
  }

  Future<void> _pickCoverImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _coverImage = File(image.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking cover image: $e');
    }
  }

  Future<void> _scanImageForText() async {
    try {
      setState(() {
        _isScanning = true;
      });

      // Request camera permission
      if (await Permission.camera.request().isGranted) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 95,
        );

        if (image != null) {
          await _processImageForText(File(image.path));
        }
      } else {
        _showErrorSnackBar('Camera permission is required for scanning');
      }
    } catch (e) {
      _showErrorSnackBar('Error scanning image: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _scanGalleryImageForText() async {
    try {
      setState(() {
        _isScanning = true;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 95,
      );

      if (image != null) {
        await _processImageForText(File(image.path));
      }
    } catch (e) {
      _showErrorSnackBar('Error scanning gallery image: $e');
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _processImageForText(File imageFile) async {
    try {
      final InputImage inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      if (recognizedText.text.isNotEmpty) {
        // Clean and format the extracted text
        String extractedText = recognizedText.text
            .split('\n')
            .where((line) => line.trim().isNotEmpty)
            .join(' ')
            .trim();

        // Add to bulk pages text area
        if (_bulkPagesController.text.isNotEmpty) {
          _bulkPagesController.text += '\n\n$extractedText';
        } else {
          _bulkPagesController.text = extractedText;
        }

        _showSuccessSnackBar(
          'Text extracted successfully! Review and edit as needed.',
        );
      } else {
        _showErrorSnackBar('No text found in the image. Try a clearer image.');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing image: $e');
    }
  }

  void _addPageFromInput() {
    final pageText = _pageTextController.text.trim();
    if (pageText.isNotEmpty) {
      setState(() {
        _pages.add(pageText);
        _pageTextController.clear();
      });
    }
  }

  void _processBulkPages() {
    final bulkText = _bulkPagesController.text.trim();
    if (bulkText.isEmpty) return;

    // Split by double newlines, single newlines, or periods followed by capital letters
    List<String> newPages = [];

    // First split by double newlines (clear page breaks)
    final sections = bulkText.split(RegExp(r'\n\s*\n'));

    for (String section in sections) {
      section = section.trim();
      if (section.isEmpty) continue;

      // If section is very long, try to split by sentences
      if (section.length > 200) {
        final sentences = section.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));
        for (String sentence in sentences) {
          sentence = sentence.trim();
          if (sentence.isNotEmpty) {
            newPages.add(sentence);
          }
        }
      } else {
        newPages.add(section);
      }
    }

    if (newPages.isNotEmpty) {
      setState(() {
        _pages.addAll(newPages);
        _bulkPagesController.clear();
      });
      _showSuccessSnackBar('Added ${newPages.length} pages from bulk text');
    }
  }

  void _removePage(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Page'),
        content: Text('Are you sure you want to delete page ${index + 1}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _pages.removeAt(index);
      });
      _showSuccessSnackBar('Page ${index + 1} deleted successfully!');
    }
  }

  void _editPage(int index) async {
    final currentContent = _pages[index];
    final controller = TextEditingController(text: currentContent);
    
    final editedContent = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: Colors.blue),
            const SizedBox(width: 8),
            Text('Edit Page ${index + 1}'),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          height: MediaQuery.of(context).size.height * 0.4,
          child: Column(
            children: [
              const Text(
                'Edit the content for this page:',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: 'Page Content',
                    border: OutlineInputBorder(),
                    hintText: 'Enter the content for this page...',
                    alignLabelWithHint: true,
                  ),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(context).pop(controller.text.trim());
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );

    // Update the page content if user saved changes
    if (editedContent != null && editedContent.isNotEmpty && editedContent != currentContent) {
      setState(() {
        _pages[index] = editedContent;
      });
      _showSuccessSnackBar('Page ${index + 1} updated successfully!');
    }
  }

  void _addTag() {
    final tag = _newTag.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _newTag = '';
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _saveBook() async {
    if (!_formKey.currentState!.validate() || _pages.isEmpty) {
      _showErrorSnackBar(
        'Please fill all required fields and add at least one page',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.book != null) {
        // Update existing book
        final updatedBook = widget.book!.copyWith(
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          description: _descriptionController.text.trim(),
          coverImagePath: _coverImage?.path ?? widget.book!.coverImagePath,
          pages: _pages,
          difficulty: _selectedDifficulty,
          tags: _tags.isNotEmpty ? _tags : null,
        );
        
        await BookService.saveBook(updatedBook);
        
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Create new book
        final book = Book.create(
          title: _titleController.text.trim(),
          author: _authorController.text.trim(),
          description: _descriptionController.text.trim(),
          coverImagePath:
              _coverImage?.path ?? 'assets/images/default_book_cover.png',
          pages: _pages,
          difficulty: _selectedDifficulty,
          tags: _tags.isNotEmpty ? _tags : null,
          language: 'English',
        );

        await BookService.saveBook(book);

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error saving book: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book != null ? 'Edit Book' : 'Upload New Book',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE1F5FE), Color(0xFFF3E5F5), Color(0xFFE8F5E8)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image Section
                _buildCoverImageSection(),
                const SizedBox(height: 24),

                // Basic Information
                _buildBasicInfoSection(),
                const SizedBox(height: 24),

                // Page Content Section
                _buildPageContentSection(),
                const SizedBox(height: 24),

                // OCR Scanning Section
                _buildOCRSection(),
                const SizedBox(height: 24),

                // Bulk Pages Section
                _buildBulkPagesSection(),
                const SizedBox(height: 24),

                // Pages Preview
                _buildPagesPreview(),
                const SizedBox(height: 24),

                // Tags Section
                _buildTagsSection(),
                const SizedBox(height: 32),

                // Save Button
                _buildSaveButton(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImageSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cover Image',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _coverImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_coverImage!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Tap to add\ncover image',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Book Title *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.book),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a book title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _authorController,
              decoration: const InputDecoration(
                labelText: 'Author *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter the author name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a book description';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedDifficulty,
              decoration: const InputDecoration(
                labelText: 'Difficulty Level',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up),
              ),
              items: _difficulties.map((difficulty) {
                return DropdownMenuItem(
                  value: difficulty,
                  child: Text(difficulty),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDifficulty = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContentSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Pages',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pageTextController,
                    decoration: const InputDecoration(
                      labelText: 'Page content',
                      border: OutlineInputBorder(),
                      hintText: 'Enter text for one page...',
                    ),
                    maxLines: 3,
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addPageFromInput,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Add Page'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOCRSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Scan Text from Images',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Capture or select images with text to automatically extract content',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanImageForText,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(_isScanning ? 'Scanning...' : 'Take Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isScanning ? null : _scanGalleryImageForText,
                    icon: _isScanning
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.photo_library),
                    label: Text(_isScanning ? 'Scanning...' : 'From Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBulkPagesSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bulk Page Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste or type multiple pages of text. Separate pages with double line breaks.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bulkPagesController,
              decoration: const InputDecoration(
                labelText: 'Multiple pages text',
                border: OutlineInputBorder(),
                hintText:
                    'Page 1 content...\n\nPage 2 content...\n\nPage 3 content...',
                alignLabelWithHint: true,
              ),
              maxLines: 8,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _processBulkPages,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Process Bulk Text'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagesPreview() {
    if (_pages.isEmpty) {
      return Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No pages added yet. Use the sections above to add content.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pages Preview (${_pages.length} pages)',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      _pages[index],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15),
                    ),
                    subtitle: Text(
                      '${_pages[index].length} characters',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                            onPressed: () => _editPage(index),
                            tooltip: 'Edit Page Content',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Delete button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () => _removePage(index),
                            tooltip: 'Delete Page',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagsSection() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tags (Optional)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Add tag',
                      border: OutlineInputBorder(),
                      hintText: 'e.g., Adventure, Educational, Animals',
                    ),
                    onChanged: (value) {
                      _newTag = value;
                    },
                    onSubmitted: (value) => _addTag(),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _addTag,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: Colors.deepPurple.withOpacity(0.1),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveBook,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        child: _isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    widget.book != null ? 'Updating Book...' : 'Saving Book...',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Text(
                widget.book != null ? 'Update Book' : 'Save Book',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
