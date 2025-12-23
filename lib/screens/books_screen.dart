import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/book_service.dart';
import 'upload_book_screen.dart';
import 'book_reading_screen.dart';

class BooksScreen extends StatefulWidget {
  const BooksScreen({super.key});

  @override
  State<BooksScreen> createState() => _BooksScreenState();
}

class _BooksScreenState extends State<BooksScreen> {
  List<Book> _books = [];
  List<Book> _allBooks = []; // Store all books for filtering
  bool _isLoading = true;
  String _selectedFilter = 'All Books';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  final List<String> _filterOptions = [
    'All Books',
    'Name',
    'Favorites',
    'Description',
    'Difficulty Level',
    'Author',
    'Recently Added',
    'Most Read',
  ];

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _initializeBookService();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _applyFilters();
  }

  Future<void> _initializeBookService() async {
    try {
      await BookService.init();
    } catch (e) {
      print('Error initializing BookService: $e');
    }
  }

  Future<void> _loadBooks() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Load all books
      final books = await BookService.getAllBooks();

      setState(() {
        _allBooks = books;
        _isLoading = false;
      });
      
      // Apply current filters
      _applyFilters();
    } catch (e) {
      print('Error loading books: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Book> filteredBooks = List.from(_allBooks);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filteredBooks = filteredBooks.where((book) {
        final query = _searchQuery.toLowerCase();
        return book.title.toLowerCase().contains(query) ||
               book.author.toLowerCase().contains(query) ||
               book.description.toLowerCase().contains(query);
      }).toList();
    }

    // Apply selected filter
    switch (_selectedFilter) {
      case 'All Books':
        // No additional filtering needed
        break;
      case 'Name':
        filteredBooks.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'Favorites':
        filteredBooks = filteredBooks.where((book) => book.isFavorite == true).toList();
        break;
      case 'Description':
        filteredBooks = filteredBooks.where((book) => 
          book.description.isNotEmpty).toList();
        break;
      case 'Difficulty Level':
        filteredBooks.sort((a, b) {
          final difficultyOrder = ['Beginner', 'Elementary', 'Intermediate', 'Advanced'];
          final aIndex = difficultyOrder.indexOf(a.difficulty ?? '');
          final bIndex = difficultyOrder.indexOf(b.difficulty ?? '');
          return aIndex.compareTo(bIndex);
        });
        break;
      case 'Author':
        filteredBooks.sort((a, b) => a.author.compareTo(b.author));
        break;
      case 'Recently Added':
        filteredBooks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'Most Read':
        filteredBooks.sort((a, b) => (b.timesRead ?? 0).compareTo(a.timesRead ?? 0));
        break;
    }

    setState(() {
      _books = filteredBooks;
    });
  }

  void _navigateToUpload() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const UploadBookScreen()))
        .then((_) => _loadBooks()); // Refresh books after upload
  }

  void _navigateToReading(Book book) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => BookReadingScreen(book: book)),
    );
  }

  Future<void> _toggleFavorite(String bookId) async {
    try {
      await BookService.toggleBookFavorite(bookId);
      _loadBooks(); // Refresh the list
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Future<void> _deleteBook(Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await BookService.deleteBook(book.id);
        _loadBooks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${book.title}"'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        print('Error deleting book: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error deleting book'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editBook(Book book) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UploadBookScreen(book: book),
      ),
    );
    
    // Refresh the book list after editing
    if (result != null || mounted) {
      _loadBooks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
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
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Header with filter and search
                _buildHeader(),
                const SizedBox(height: 24),

                // Books grid/list
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _books.isEmpty
                      ? _buildEmptyState()
                      : _buildBooksGrid(),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToUpload,
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.book, size: 40, color: Colors.deepPurple),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reading Books',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                    Text(
                      '${_books.length} books available',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filter and Search Row
          Row(
            children: [
              // Filter Dropdown
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Text(
                      'Filter: ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedFilter,
                        isExpanded: true,
                        items: _filterOptions.map((filter) {
                          return DropdownMenuItem(
                            value: filter,
                            child: Text(
                              filter,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedFilter = value!;
                          });
                          _applyFilters();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Search Bar
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search books...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No books found',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the + button to upload your first book',
            style: TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToUpload,
            icon: const Icon(Icons.upload_file),
            label: const Text('Upload Book'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksGrid() {
    return ListView.builder(
      itemCount: _books.length,
      itemBuilder: (context, index) {
        final book = _books[index];
        return _buildHorizontalBookCard(book);
      },
    );
  }

  Widget _buildHorizontalBookCard(Book book) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToReading(book),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            // Left: Book Cover (Small Square/Rectangle)
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.deepPurple.withOpacity(0.7),
                    Colors.blue.withOpacity(0.7),
                  ],
                ),
              ),
              child: const Icon(
                Icons.book,
                size: 30,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Middle: Book Details (Expandable)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                      fontFamily: 'OpenDyslexic',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Author
                  Text(
                    'by ${book.author}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: 'OpenDyslexic',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Difficulty Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      book.difficulty ?? 'Unknown',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontFamily: 'OpenDyslexic',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Right: Action Buttons (Responsive)
            isLargeScreen
                ? _buildActionButtons(book)
                : _buildBurgerMenu(book),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(Book book) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Favorite Button
        IconButton(
          onPressed: () => _toggleFavorite(book.id),
          icon: Icon(
            book.isFavorite == true
                ? Icons.favorite
                : Icons.favorite_border,
            color: Colors.red,
            size: 24,
          ),
          tooltip: 'Toggle Favorite',
        ),
        
        // Edit Button (assuming you want to add edit functionality)
        IconButton(
          onPressed: () => _editBook(book),
          icon: const Icon(
            Icons.edit_outlined,
            color: Colors.blue,
            size: 24,
          ),
          tooltip: 'Edit Book',
        ),
        
        // Delete Button
        IconButton(
          onPressed: () => _deleteBook(book),
          icon: const Icon(
            Icons.delete_outline,
            color: Colors.grey,
            size: 24,
          ),
          tooltip: 'Delete Book',
        ),
      ],
    );
  }

  Widget _buildBurgerMenu(Book book) {
    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.grey,
        size: 24,
      ),
      onSelected: (value) {
        switch (value) {
          case 'favorite':
            _toggleFavorite(book.id);
            break;
          case 'edit':
            _editBook(book);
            break;
          case 'delete':
            _deleteBook(book);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'favorite',
          child: Row(
            children: [
              Icon(
                book.isFavorite == true
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.red,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                book.isFavorite == true 
                    ? 'Remove from Favorites'
                    : 'Add to Favorites',
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
              SizedBox(width: 12),
              Text('Edit Book'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 20),
              SizedBox(width: 12),
              Text('Delete Book'),
            ],
          ),
        ),
      ],
    );
  }

}
