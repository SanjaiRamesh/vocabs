import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/book.dart';

class BookService {
  static Database? _database;
  static const String _databaseName = 'books.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _booksTable = 'books';
  static const String _readingProgressTable = 'reading_progress';

  // Singleton pattern
  static final BookService _instance = BookService._internal();
  factory BookService() => _instance;
  BookService._internal();

  // Initialize database
  static Future<void> init() async {
    if (_database != null) return;

    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _createTables,
        onUpgrade: _onUpgrade,
      );

      // Create default sample books
      await _createDefaultBooks();
    } catch (e) {
      print('Error initializing BookService database: $e');
      rethrow;
    }
  }

  // Create database tables
  static Future<void> _createTables(Database db, int version) async {
    // Books table
    await db.execute('''
      CREATE TABLE $_booksTable (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        description TEXT NOT NULL,
        coverImagePath TEXT NOT NULL,
        pages TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        language TEXT,
        difficulty TEXT,
        tags TEXT,
        readingTime INTEGER,
        isFavorite INTEGER DEFAULT 0,
        userRating REAL,
        timesRead INTEGER DEFAULT 0
      )
    ''');

    // Reading progress table
    await db.execute('''
      CREATE TABLE $_readingProgressTable (
        id TEXT PRIMARY KEY,
        bookId TEXT NOT NULL,
        currentPage INTEGER NOT NULL DEFAULT 0,
        lastReadAt TEXT NOT NULL,
        totalReadingTimeMinutes INTEGER NOT NULL DEFAULT 0,
        completedPages TEXT,
        comprehensionScore REAL,
        readingStats TEXT,
        FOREIGN KEY (bookId) REFERENCES $_booksTable (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_books_title ON $_booksTable (title)');
    await db.execute('CREATE INDEX idx_books_author ON $_booksTable (author)');
    await db.execute(
      'CREATE INDEX idx_books_difficulty ON $_booksTable (difficulty)',
    );
    await db.execute(
      'CREATE INDEX idx_reading_progress_book ON $_readingProgressTable (bookId)',
    );
  }

  // Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Handle future database schema changes
    if (oldVersion < newVersion) {
      // Add migration logic here when needed
    }
  }

  // Get database instance
  static Future<Database> get database async {
    if (_database != null) return _database!;
    await init();
    return _database!;
  }

  // BOOK CRUD OPERATIONS

  // Save a book (create or update)
  static Future<void> saveBook(Book book) async {
    final db = await database;
    try {
      await db.insert(
        _booksTable,
        book.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving book: $e');
      rethrow;
    }
  }

  // Get all books
  static Future<List<Book>> getAllBooks() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _booksTable,
        orderBy: 'updatedAt DESC',
      );
      return maps.map((map) => Book.fromJson(map)).toList();
    } catch (e) {
      print('Error getting all books: $e');
      return [];
    }
  }

  // Get book by ID
  static Future<Book?> getBookById(String id) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _booksTable,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return Book.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting book by ID: $e');
      return null;
    }
  }

  // Get books by difficulty
  static Future<List<Book>> getBooksByDifficulty(String difficulty) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _booksTable,
        where: 'difficulty = ?',
        whereArgs: [difficulty],
        orderBy: 'title ASC',
      );
      return maps.map((map) => Book.fromJson(map)).toList();
    } catch (e) {
      print('Error getting books by difficulty: $e');
      return [];
    }
  }

  // Get favorite books
  static Future<List<Book>> getFavoriteBooks() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _booksTable,
        where: 'isFavorite = ?',
        whereArgs: [1],
        orderBy: 'updatedAt DESC',
      );
      return maps.map((map) => Book.fromJson(map)).toList();
    } catch (e) {
      print('Error getting favorite books: $e');
      return [];
    }
  }

  // Search books by title or author
  static Future<List<Book>> searchBooks(String query) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _booksTable,
        where: 'title LIKE ? OR author LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'title ASC',
      );
      return maps.map((map) => Book.fromJson(map)).toList();
    } catch (e) {
      print('Error searching books: $e');
      return [];
    }
  }

  // Delete a book
  static Future<void> deleteBook(String id) async {
    final db = await database;
    try {
      await db.delete(_booksTable, where: 'id = ?', whereArgs: [id]);
      // Also delete associated reading progress
      await db.delete(
        _readingProgressTable,
        where: 'bookId = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting book: $e');
      rethrow;
    }
  }

  // Update book rating
  static Future<void> updateBookRating(String bookId, double rating) async {
    final db = await database;
    try {
      await db.update(
        _booksTable,
        {
          'userRating': rating.clamp(0.0, 5.0),
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [bookId],
      );
    } catch (e) {
      print('Error updating book rating: $e');
      rethrow;
    }
  }

  // Toggle book favorite status
  static Future<void> toggleBookFavorite(String bookId) async {
    final db = await database;
    try {
      final book = await getBookById(bookId);
      if (book != null) {
        final newFavoriteStatus = !(book.isFavorite ?? false);
        await db.update(
          _booksTable,
          {
            'isFavorite': newFavoriteStatus ? 1 : 0,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } catch (e) {
      print('Error toggling book favorite: $e');
      rethrow;
    }
  }

  // Increment book read count
  static Future<void> markBookAsRead(String bookId) async {
    final db = await database;
    try {
      final book = await getBookById(bookId);
      if (book != null) {
        final newReadCount = (book.timesRead ?? 0) + 1;
        await db.update(
          _booksTable,
          {
            'timesRead': newReadCount,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [bookId],
        );
      }
    } catch (e) {
      print('Error marking book as read: $e');
      rethrow;
    }
  }

  // READING PROGRESS OPERATIONS

  // Save reading progress
  static Future<void> saveReadingProgress(ReadingProgress progress) async {
    final db = await database;
    try {
      await db.insert(
        _readingProgressTable,
        progress.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error saving reading progress: $e');
      rethrow;
    }
  }

  // Get reading progress for a book
  static Future<ReadingProgress?> getReadingProgress(String bookId) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _readingProgressTable,
        where: 'bookId = ?',
        whereArgs: [bookId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return ReadingProgress.fromJson(maps.first);
      }
      return null;
    } catch (e) {
      print('Error getting reading progress: $e');
      return null;
    }
  }

  // Update reading progress
  static Future<void> updateReadingProgress({
    required String bookId,
    int? currentPage,
    int? additionalReadingTime,
    List<String>? newCompletedPages,
    double? comprehensionScore,
  }) async {
    try {
      var progress = await getReadingProgress(bookId);

      if (progress == null) {
        // Create new progress if doesn't exist
        progress = ReadingProgress.create(bookId: bookId);
      }

      // Update progress with new values
      final updatedProgress = progress.copyWith(
        currentPage: currentPage,
        additionalReadingTime: additionalReadingTime,
        newCompletedPages: newCompletedPages,
        comprehensionScore: comprehensionScore,
      );

      await saveReadingProgress(updatedProgress);
    } catch (e) {
      print('Error updating reading progress: $e');
      rethrow;
    }
  }

  // Get all reading progress records
  static Future<List<ReadingProgress>> getAllReadingProgress() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _readingProgressTable,
        orderBy: 'lastReadAt DESC',
      );
      return maps.map((map) => ReadingProgress.fromJson(map)).toList();
    } catch (e) {
      print('Error getting all reading progress: $e');
      return [];
    }
  }

  // Get recently read books
  static Future<List<Book>> getRecentlyReadBooks({int limit = 10}) async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery(
        '''
        SELECT b.* FROM $_booksTable b
        INNER JOIN $_readingProgressTable rp ON b.id = rp.bookId
        ORDER BY rp.lastReadAt DESC
        LIMIT ?
      ''',
        [limit],
      );
      return maps.map((map) => Book.fromJson(map)).toList();
    } catch (e) {
      print('Error getting recently read books: $e');
      return [];
    }
  }

  // UTILITY METHODS

  // Get available difficulties
  static Future<List<String>> getAvailableDifficulties() async {
    final db = await database;
    try {
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT DISTINCT difficulty FROM $_booksTable 
        WHERE difficulty IS NOT NULL 
        ORDER BY difficulty ASC
      ''');
      return maps.map((map) => map['difficulty'] as String).toList();
    } catch (e) {
      print('Error getting available difficulties: $e');
      return [];
    }
  }

  // Get book statistics
  static Future<Map<String, dynamic>> getBookStatistics() async {
    final db = await database;
    try {
      final totalBooksResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_booksTable',
      );
      final totalBooks = totalBooksResult.first['count'] as int;

      final favoriteBooksResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_booksTable WHERE isFavorite = 1',
      );
      final favoriteBooks = favoriteBooksResult.first['count'] as int;

      final totalReadingTimeResult = await db.rawQuery(
        'SELECT SUM(totalReadingTimeMinutes) as total FROM $_readingProgressTable',
      );
      final totalReadingTime =
          totalReadingTimeResult.first['total'] as int? ?? 0;

      final booksInProgressResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_readingProgressTable WHERE currentPage > 0',
      );
      final booksInProgress = booksInProgressResult.first['count'] as int;

      return {
        'totalBooks': totalBooks,
        'favoriteBooks': favoriteBooks,
        'totalReadingTimeMinutes': totalReadingTime,
        'booksInProgress': booksInProgress,
      };
    } catch (e) {
      print('Error getting book statistics: $e');
      return {
        'totalBooks': 0,
        'favoriteBooks': 0,
        'totalReadingTimeMinutes': 0,
        'booksInProgress': 0,
      };
    }
  }

  // Create default sample books
  static Future<void> _createDefaultBooks() async {
    try {
      final existingBooks = await getAllBooks();
      if (existingBooks.isNotEmpty) {
        return; // Don't create defaults if books already exist
      }

      final defaultBooks = [
        Book.create(
          title: "The Little Red Hen",
          author: "Traditional Tale",
          description:
              "A classic story about hard work and sharing. The little red hen plants wheat, tends it, harvests it, and bakes bread, but her friends won't help until it's time to eat!",
          coverImagePath: "assets/images/default_book_cover.png",
          pages: [
            "Once upon a time, there was a little red hen who lived on a farm.",
            "She found some wheat seeds and asked her friends to help plant them.",
            "\"Not I,\" said the cat. \"Not I,\" said the dog. \"Not I,\" said the duck.",
            "So the little red hen planted the wheat all by herself.",
            "When the wheat was ready to harvest, she asked for help again.",
            "But again, all her friends said \"Not I.\"",
            "The little red hen cut the wheat and took it to the mill.",
            "She ground the wheat into flour and baked delicious bread.",
            "When the bread was ready, all her friends wanted to help eat it!",
            "But the little red hen said, \"I will eat it myself!\" And she did.",
          ],
          difficulty: "Beginner",
          tags: ["Classic", "Moral", "Animals"],
        ),
        Book.create(
          title: "The Three Little Pigs",
          author: "Traditional Tale",
          description:
              "Three little pigs build houses of different materials to protect themselves from the big bad wolf.",
          coverImagePath: "assets/images/default_book_cover.png",
          pages: [
            "Once there were three little pigs who left home to seek their fortune.",
            "The first little pig built his house out of straw.",
            "The second little pig built his house out of sticks.",
            "The third little pig built his house out of bricks.",
            "Along came a big bad wolf who was very hungry.",
            "He went to the first pig's house and huffed and puffed and blew it down!",
            "The first pig ran to his brother's stick house.",
            "The wolf huffed and puffed and blew that house down too!",
            "Both pigs ran to their brother's brick house.",
            "The wolf huffed and puffed but could not blow down the brick house.",
            "The three little pigs lived safely ever after in the strong brick house.",
          ],
          difficulty: "Beginner",
          tags: ["Classic", "Safety", "Building"],
        ),
        Book.create(
          title: "Goldilocks and the Three Bears",
          author: "Traditional Tale",
          description:
              "A curious girl discovers a house in the woods belonging to three bears and tries their porridge, chairs, and beds.",
          coverImagePath: "assets/images/default_book_cover.png",
          pages: [
            "Once upon a time, there was a little girl named Goldilocks.",
            "She was walking in the forest when she found a pretty house.",
            "The door was open, so she went inside.",
            "On the table were three bowls of porridge.",
            "She tasted the first bowl. \"Too hot!\" she said.",
            "She tasted the second bowl. \"Too cold!\" she said.",
            "She tasted the third bowl. \"Just right!\" And she ate it all up.",
            "Then she saw three chairs and tried each one.",
            "The smallest chair was just right, but it broke!",
            "Feeling sleepy, she found three beds upstairs.",
            "The smallest bed was just right, and she fell asleep.",
            "When the three bears came home, they found her sleeping!",
            "Goldilocks woke up, jumped out the window, and ran away.",
            "She never went into someone else's house again without permission.",
          ],
          difficulty: "Elementary",
          tags: ["Classic", "Adventure", "Bears"],
        ),
      ];

      for (final book in defaultBooks) {
        await saveBook(book);
      }

      print('Created ${defaultBooks.length} default books');
    } catch (e) {
      print('Error creating default books: $e');
    }
  }

  // Clear all data (for testing purposes)
  static Future<void> clearAllData() async {
    final db = await database;
    try {
      await db.delete(_readingProgressTable);
      await db.delete(_booksTable);
      print('All book data cleared');
    } catch (e) {
      print('Error clearing book data: $e');
      rethrow;
    }
  }

  // Close database connection
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
