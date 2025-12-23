import 'package:english_words/english_words.dart';

void main() {
  // Test simple but effective syllable breaking
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

  print('=== SIMPLE EFFECTIVE SYLLABLE BREAKING ===');
  for (String word in testWords) {
    int count = syllables(word);
    String broken = _simpleSyllableBreaking(word);
    print('$word (${count} syllables) -> $broken');
  }
}

String _simpleSyllableBreaking(String word) {
  if (word.length <= 3) return word;

  String cleanWord = word.toLowerCase();
  List<String> vowels = ['a', 'e', 'i', 'o', 'u'];

  // Step 1: Handle common endings first
  if (cleanWord.endsWith('ing') && cleanWord.length > 5) {
    String base = word.substring(0, word.length - 3);
    return '${_simpleSyllableBreaking(base)}•ing';
  }

  if (cleanWord.endsWith('tion') && cleanWord.length > 6) {
    String base = word.substring(0, word.length - 4);
    return '${_simpleSyllableBreaking(base)}•tion';
  }

  if (cleanWord.endsWith('sion') && cleanWord.length > 6) {
    String base = word.substring(0, word.length - 4);
    return '${_simpleSyllableBreaking(base)}•sion';
  }

  if (cleanWord.endsWith('ment') && cleanWord.length > 6) {
    String base = word.substring(0, word.length - 4);
    return '${_simpleSyllableBreaking(base)}•ment';
  }

  if (cleanWord.endsWith('ful') && cleanWord.length > 5) {
    String base = word.substring(0, word.length - 3);
    return '${_simpleSyllableBreaking(base)}•ful';
  }

  if (cleanWord.endsWith('less') && cleanWord.length > 6) {
    String base = word.substring(0, word.length - 4);
    return '${_simpleSyllableBreaking(base)}•less';
  }

  if (cleanWord.endsWith('ness') && cleanWord.length > 6) {
    String base = word.substring(0, word.length - 4);
    return '${_simpleSyllableBreaking(base)}•ness';
  }

  // Step 2: Handle consonant + le endings
  if (cleanWord.length > 4 && cleanWord.endsWith('le')) {
    String beforeLe = cleanWord[cleanWord.length - 3];
    if (!vowels.contains(beforeLe)) {
      String base = word.substring(0, word.length - 3);
      String ending = word.substring(word.length - 3);
      return '${base}•${ending}';
    }
  }

  // Step 3: Handle double consonants
  for (int i = 1; i < cleanWord.length - 1; i++) {
    if (cleanWord[i] == cleanWord[i + 1] &&
        !vowels.contains(cleanWord[i]) &&
        i > 0 &&
        vowels.contains(cleanWord[i - 1]) &&
        i + 2 < cleanWord.length &&
        vowels.contains(cleanWord[i + 2])) {
      return '${word.substring(0, i + 1)}•${word.substring(i + 1)}';
    }
  }

  // Step 4: Simple vowel-consonant-vowel split
  List<int> vowelPositions = [];
  for (int i = 0; i < cleanWord.length; i++) {
    if (vowels.contains(cleanWord[i])) {
      vowelPositions.add(i);
    }
  }

  if (vowelPositions.length >= 2) {
    // Find consonants between first two vowels
    int firstVowel = vowelPositions[0];
    int secondVowel = vowelPositions[1];

    List<int> consonantsBetween = [];
    for (int i = firstVowel + 1; i < secondVowel; i++) {
      if (!vowels.contains(cleanWord[i])) {
        consonantsBetween.add(i);
      }
    }

    if (consonantsBetween.length == 1) {
      // Single consonant: usually goes with second syllable (CV•CV)
      int splitPoint = consonantsBetween[0];
      return '${word.substring(0, splitPoint)}•${word.substring(splitPoint)}';
    } else if (consonantsBetween.length >= 2) {
      // Multiple consonants: split between them (CVC•CV)
      int splitPoint = consonantsBetween[0] + 1;
      return '${word.substring(0, splitPoint)}•${word.substring(splitPoint)}';
    }
  }

  return word; // Can't split
}
