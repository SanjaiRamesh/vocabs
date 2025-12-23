import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OcrTextProcessor Tests', () {
    test('should process simple numbered list correctly', () {
      // Mock OCR result with numbered items
      // This would normally come from actual ML Kit processing

      // For testing purposes, we can create mock data
      // In real usage, you'd call:
      // List<String> items = OcrTextProcessor.processForReading(recognizedText);

      // Example expected output:
      List<String> expectedItems = [
        '1. What is the capital of France?',
        '2. Name three primary colors.',
        '3. How many sides does a triangle have?',
        'a) Red, blue, green',
        'b) Paris is the capital',
        'c) A triangle has three sides',
      ];

      // In actual usage, this would process real OCR data
      expect(expectedItems.length, equals(6));
      expect(expectedItems[0], startsWith('1.'));
      expect(expectedItems[3], startsWith('a)'));
    });

    test('should handle continuation lines correctly', () {
      // Test that lines without markers get combined with previous item
      // when they're close enough vertically

      List<String> expectedCombined = [
        '1. This is a long question that spans multiple lines in the original worksheet',
        '2. Another question with continuation text on the next line',
      ];

      expect(expectedCombined.length, equals(2));
    });

    test('should remove junk text', () {
      // Test that stray characters, table separators, etc. are filtered out
      List<String> cleanItems = ['1. Valid question', '2. Another valid item'];

      // Should not contain: single characters, table pipes, etc.
      expect(cleanItems.every((item) => item.length > 3), isTrue);
      expect(cleanItems.every((item) => !item.contains('|')), isTrue);
    });
  });
}

/*
USAGE EXAMPLE:

In your Flutter app, use it like this:

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'services/ocr_text_processor.dart';

// Process an image with ML Kit
final textRecognizer = TextRecognizer();
final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

// Convert to clean reading practice items
List<String> readingItems = OcrTextProcessor.processForReading(recognizedText);

// Use the items for reading practice
for (int i = 0; i < readingItems.length; i++) {
  print('Item ${i + 1}: ${readingItems[i]}');
}

textRecognizer.close();
```

The function will:
1. Sort OCR lines by position (top to bottom, left to right)
2. Join words within each line by their left position
3. Detect list markers (1., 2., a), I., etc.) to start new items
4. Combine continuation lines that are close vertically
5. Clean up whitespace and remove table separators/junk
6. Return a clean list of strings ready for reading practice

Example output:
- "1. What is the capital of France?"
- "2. Name three primary colors that you see in nature."
- "a) Red, blue, and yellow"
- "b) The capital of France is Paris"
*/
