import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/book_page.dart';
import 'worksheet_ocr_helper.dart';

class BookPageService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'book_pages.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE book_pages(id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT, content TEXT, imagePath TEXT, questionBlocks TEXT)',
        );
      },
    );
  }

  static Future<int> addBookPage(BookPage bookPage) async {
    final db = await database;
    Map<String, dynamic> bookPageMap = bookPage.toMap();
    // Remove id for auto-increment
    bookPageMap.remove('id');
    return await db.insert('book_pages', bookPageMap);
  }

  static Future<int> saveBookPage(BookPage bookPage) async {
    // Alias for addBookPage to match screen expectations
    return await addBookPage(bookPage);
  }

  static Future<List<BookPage>> getAllBookPages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('book_pages');
    return List.generate(maps.length, (i) {
      return BookPage.fromMap(maps[i]);
    });
  }

  static Future<BookPage?> getBookPage(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'book_pages',
      where: 'id = ?',
      whereArgs: [int.parse(id)],
    );
    if (maps.isNotEmpty) {
      return BookPage.fromMap(maps.first);
    }
    return null;
  }

  static Future<void> deleteBookPage(String id) async {
    final db = await database;
    await db.delete('book_pages', where: 'id = ?', whereArgs: [int.parse(id)]);
  }

  static Future<String> extractTextWithLayout(String imagePath) async {
    try {
      print('🔍 Starting enhanced OCR analysis...');

      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();

      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      // Use the new worksheet OCR helper to process the result
      String processedText = WorksheetOcrHelper.processToMarkdown(
        recognizedText,
      );

      if (processedText.trim().isEmpty) {
        print('⚠️ No text found in the image');
        return 'No text found in the image';
      }

      print('✅ Enhanced OCR completed successfully');
      return processedText;
    } catch (e) {
      print('❌ Enhanced OCR error: $e');
      return 'Error extracting text: $e';
    }
  }
}
