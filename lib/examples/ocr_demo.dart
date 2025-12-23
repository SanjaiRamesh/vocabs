// Example usage of OcrTextProcessor
// This demonstrates how to use the function we created

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/ocr_text_processor.dart';

void demonstrateOcrProcessor() {
  print('=== OCR Text Processor Demo ===');

  // Example 1: Simple numbered list
  print('\n1. Simple numbered list:');
  print(
    'Input OCR text: "1. First question\\n2. Second question\\na) Sub item"',
  );

  // In real usage, you would get RecognizedText from ML Kit
  // For demonstration, let's show the expected output:
  List<String> result1 = [
    '1. First question',
    '2. Second question',
    'a) Sub item',
  ];

  print('Expected output:');
  for (int i = 0; i < result1.length; i++) {
    print('  [$i]: "${result1[i]}"');
  }

  // Example 2: Continuation lines
  print('\n2. Continuation lines:');
  print(
    'Input OCR text: "1. This is a long question\\n   that continues on next line\\n2. Next question"',
  );

  List<String> result2 = [
    '1. This is a long question that continues on next line',
    '2. Next question',
  ];

  print('Expected output:');
  for (int i = 0; i < result2.length; i++) {
    print('  [$i]: "${result2[i]}"');
  }

  // Example 3: Cleaning junk
  print('\n3. Cleaning junk and extra spaces:');
  print('Input OCR text: "1.   Extra   spaces\\n| | |\\n2. Clean question"');

  List<String> result3 = ['1. Extra spaces', '2. Clean question'];

  print('Expected output:');
  for (int i = 0; i < result3.length; i++) {
    print('  [$i]: "${result3[i]}"');
  }

  print('\n=== Key Features ===');
  print('✓ Sorts OCR lines by position (top then left)');
  print('✓ Joins words within lines by left position');
  print('✓ Detects markers (1., 2., a), I.) to start new items');
  print('✓ Merges continuation lines within 0.4x median height');
  print('✓ Removes junk like "|" and extra whitespace');
  print('✓ Returns clean List<String> for reading practice');
}

// Integration example with your existing book system
void integrationExample() {
  print('\n=== Integration with Book System ===');
  print('''
// In your book page service:
Future<List<String>> processOcrForReading(RecognizedText ocrResult) async {
  final readingItems = OcrTextProcessor.extractReadingItems(ocrResult);
  
  // Save to database if needed
  for (int i = 0; i < readingItems.length; i++) {
    print('Reading item \${i + 1}: \${readingItems[i]}');
  }
  
  return readingItems;
}

// Usage in your book reading screen:
List<String> items = await processOcrForReading(recognizedText);
// Now you have clean, ordered items for TTS reading!
  ''');
}
