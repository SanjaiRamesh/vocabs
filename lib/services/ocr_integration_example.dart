// EXAMPLE: How to integrate OcrTextProcessor into your app

// In your book_page_service.dart, you can add this method:

/*
Add this import:
import 'ocr_text_processor.dart';

Then add this method to your BookPageService class:
*/

  /// Extract text as reading practice items using the new OCR processor
  static Future<List<String>> extractReadingItems(String imagePath) async {
    try {
      print('🔍 Starting reading items extraction...');
      
      final inputImage = InputImage.fromFilePath(imagePath);
      final textRecognizer = TextRecognizer();
      
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      
      // Use the new OCR processor to get clean reading items
      List<String> readingItems = OcrTextProcessor.processForReading(recognizedText);
      
      textRecognizer.close();
      
      if (readingItems.isEmpty) {
        print('⚠️ No reading items found in the image');
        return [];
      }
      
      print('✅ Found ${readingItems.length} reading items');
      for (int i = 0; i < readingItems.length; i++) {
        print('Item ${i + 1}: ${readingItems[i]}');
      }
      
      return readingItems;
      
    } catch (e) {
      print('❌ Error extracting reading items: $e');
      return [];
    }
  }

/*
USAGE EXAMPLES:

1. In a reading practice screen:
```dart
List<String> questions = await BookPageService.extractReadingItems(imagePath);
for (String question in questions) {
  // Display each question for reading practice
  // Use TTS to read it aloud
  // Allow student to practice reading it
}
```

2. For individual item practice:
```dart
List<String> items = await BookPageService.extractReadingItems(imagePath);
String currentItem = items[currentIndex];
// Practice reading this specific item
```

3. For progress tracking:
```dart
List<String> worksheet = await BookPageService.extractReadingItems(imagePath);
// Track which items the student has practiced
// Save progress for each numbered question
```

WHAT THE FUNCTION DOES:

✅ Sorts OCR lines by position (top→bottom, left→right)
✅ Joins words within each line by their position  
✅ Detects list markers: 1., 2., a), b., I., II., (1), (a)
✅ Starts new items when it finds markers
✅ Combines continuation lines that are close vertically  
✅ Removes table separators (|), extra whitespace
✅ Filters out junk (single letters, stray punctuation)
✅ Returns clean List<String> ready for reading practice

EXAMPLE OUTPUT:
Input: OCR detects scattered text from worksheet
Output: 
[
  "1. What is the capital of France?",
  "2. Name three primary colors you see in nature.",  
  "3. How many sides does a triangle have?",
  "a) Red, blue, and yellow are primary colors",
  "b) Paris is the capital of France", 
  "c) A triangle has exactly three sides"
]

Each string is a complete, clean sentence ready for reading practice!
*/
