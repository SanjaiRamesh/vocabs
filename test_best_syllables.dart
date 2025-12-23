import 'package:english_words/english_words.dart';

void main() {
  // Test the best syllable breaking logic
  List<String> testWords = [
    'hello',
    'world',
    'beautiful',
    'computer',
    'elephant',
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
    'table',
    'apple',
    'bottle',
    'little',
    'purple',
    'simple',
    'happy',
    'walking',
    'talking',
    'jumping',
    'sleeping',
    'creating',
    'yellow',
    'flower',
    'water',
    'mother',
    'father',
  ];

  print('=== BEST SYLLABLE BREAKING ===');
  for (String word in testWords) {
    int count = syllables(word);
    String broken = _bestSyllableBreaking(word);
    print('$word (${count} syllables) -> $broken');
  }
}

String _bestSyllableBreaking(String word) {
  if (word.length <= 3) return word;

  String cleanWord = word.toLowerCase();

  // Common syllable patterns - these are the most accurate splits
  Map<RegExp, String> patterns = {
    // Common endings that are separate syllables
    RegExp(r'(.+)(ing)$'): r'$1•$2',
    RegExp(r'(.+)(tion)$'): r'$1•$2',
    RegExp(r'(.+)(sion)$'): r'$1•$2',
    RegExp(r'(.+)(ment)$'): r'$1•$2',
    RegExp(r'(.+)(ness)$'): r'$1•$2',
    RegExp(r'(.+)(ful)$'): r'$1•$2',
    RegExp(r'(.+)(less)$'): r'$1•$2',
    RegExp(r'(.+)(ly)$'): r'$1•$2',

    // Double consonants usually split between them
    RegExp(r'([aeiou])([bcdfghjklmnpqrstvwxz])\2([aeiou])'): r'$1$2•$2$3',

    // Consonant + le at the end
    RegExp(r'(.+)([bcdfghjklmnpqrstvwxz]le)$'): r'$1•$2',

    // Common prefixes
    RegExp(r'^(un)(.{3,})'): r'$1•$2',
    RegExp(r'^(re)(.{3,})'): r'$1•$2',
    RegExp(r'^(pre)(.{3,})'): r'$1•$2',
    RegExp(r'^(dis)(.{3,})'): r'$1•$2',
    RegExp(r'^(mis)(.{3,})'): r'$1•$2',
    RegExp(r'^(over)(.{3,})'): r'$1•$2',
    RegExp(r'^(under)(.{3,})'): r'$1•$2',

    // Vowel + consonant + vowel patterns (most common)
    RegExp(r'([aeiou])([bcdfghjklmnpqrstvwxz])([aeiou])'): r'$1•$2$3',
  };

  String result = word;

  // Apply patterns in order of priority
  for (RegExp pattern in patterns.keys) {
    if (pattern.hasMatch(cleanWord)) {
      result = cleanWord.replaceFirst(pattern, patterns[pattern]!);
      break; // Use first matching pattern
    }
  }

  // If no pattern matched, try basic vowel-consonant splitting
  if (result == word) {
    result = _basicVowelConsonantSplit(cleanWord);
  }

  // Restore original case
  if (result != cleanWord) {
    // Apply original casing to the result
    String finalResult = '';
    int originalIndex = 0;
    for (int i = 0; i < result.length; i++) {
      if (result[i] == '•') {
        finalResult += '•';
      } else {
        if (originalIndex < word.length) {
          finalResult += word[originalIndex];
          originalIndex++;
        }
      }
    }
    return finalResult;
  }

  return word;
}

String _basicVowelConsonantSplit(String word) {
  if (word.length <= 3) return word;

  List<String> vowels = ['a', 'e', 'i', 'o', 'u'];
  List<int> vowelPositions = [];

  // Find all vowel positions
  for (int i = 0; i < word.length; i++) {
    if (vowels.contains(word[i])) {
      vowelPositions.add(i);
    }
  }

  if (vowelPositions.length < 2) return word;

  // Find the best split point (between first and second vowel)
  int firstVowel = vowelPositions[0];
  int secondVowel = vowelPositions[1];

  // If there's a consonant between vowels, split before it
  for (int i = firstVowel + 1; i < secondVowel; i++) {
    if (!vowels.contains(word[i])) {
      return '${word.substring(0, i)}•${word.substring(i)}';
    }
  }

  return word;
}
