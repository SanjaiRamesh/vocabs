import 'package:english_words/english_words.dart';

void main() {
  // Test common words to see how syllables() function works
  List<String> testWords = [
    'hello',
    'world',
    'beautiful',
    'computer',
    'elephant',
    'cat',
    'dog',
    'running',
    'children',
    'wonderful',
    'education',
    'development',
    'important',
    'together',
    'family',
    'reading',
    'learning',
    'student',
  ];

  print('=== SYLLABLE COUNT TESTING ===');
  for (String word in testWords) {
    try {
      int count = syllables(word);
      print('$word -> $count syllables');
    } catch (e) {
      print('$word -> ERROR: $e');
    }
  }

  print('\n=== SIMPLE VOWEL-BASED COUNTING ===');
  for (String word in testWords) {
    int count = _simpleVowelCount(word);
    print('$word -> $count syllables (simple method)');
  }
}

int _simpleVowelCount(String word) {
  List<String> vowels = ['a', 'e', 'i', 'o', 'u', 'y'];
  int count = 0;
  String cleanWord = word.toLowerCase();

  for (int i = 0; i < cleanWord.length; i++) {
    if (vowels.contains(cleanWord[i])) {
      // Don't count consecutive vowels as separate syllables
      if (i == 0 || !vowels.contains(cleanWord[i - 1])) {
        count++;
      }
    }
  }

  // Handle silent 'e' at the end
  if (cleanWord.endsWith('e') && count > 1) {
    count--;
  }

  // Ensure at least one syllable
  return count < 1 ? 1 : count;
}
