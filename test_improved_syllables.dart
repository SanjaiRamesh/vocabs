import 'package:english_words/english_words.dart';

void main() {
  // Test improved syllable breaking logic
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
  ];

  print('=== IMPROVED SYLLABLE BREAKING ===');
  for (String word in testWords) {
    int count = syllables(word);
    String broken = _improvedSyllableBreaking(word);
    print('$word (${count} syllables) -> $broken');
  }
}

String _improvedSyllableBreaking(String word) {
  if (word.length <= 2) return word;

  String cleanWord = word.toLowerCase();
  List<String> vowels = ['a', 'e', 'i', 'o', 'u'];
  List<String> consonants = [
    'b',
    'c',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
    'm',
    'n',
    'p',
    'q',
    'r',
    's',
    't',
    'v',
    'w',
    'x',
    'z',
  ];

  // Common prefixes and suffixes that are usually separate syllables
  List<String> prefixes = [
    'un',
    're',
    'pre',
    'dis',
    'mis',
    'over',
    'under',
    'out',
  ];
  List<String> suffixes = [
    'ing',
    'ed',
    'er',
    'est',
    'ly',
    'tion',
    'sion',
    'ness',
    'ment',
    'ful',
    'less',
  ];

  // Find vowel positions
  List<int> vowelPositions = [];
  for (int i = 0; i < cleanWord.length; i++) {
    if (vowels.contains(cleanWord[i])) {
      vowelPositions.add(i);
    }
  }

  if (vowelPositions.length <= 1) {
    return word; // Single syllable or no vowels
  }

  List<int> breakPoints = [];

  // Rule 1: Split between consonants when there are two or more consonants between vowels
  for (int i = 0; i < vowelPositions.length - 1; i++) {
    int vowel1 = vowelPositions[i];
    int vowel2 = vowelPositions[i + 1];

    if (vowel2 - vowel1 > 2) {
      // There are consonants between vowels
      List<int> consonantsBetween = [];
      for (int j = vowel1 + 1; j < vowel2; j++) {
        if (consonants.contains(cleanWord[j])) {
          consonantsBetween.add(j);
        }
      }

      if (consonantsBetween.length >= 2) {
        // Split between consonants (usually after the first consonant)
        int splitPoint = consonantsBetween[0] + 1;
        breakPoints.add(splitPoint);
      } else if (consonantsBetween.length == 1) {
        // Single consonant - usually goes with the second vowel
        int splitPoint = consonantsBetween[0];
        breakPoints.add(splitPoint);
      }
    }
  }

  // Rule 2: Handle common endings
  for (String suffix in suffixes) {
    if (cleanWord.endsWith(suffix) && cleanWord.length > suffix.length + 2) {
      int suffixStart = cleanWord.length - suffix.length;
      if (!breakPoints.contains(suffixStart)) {
        breakPoints.add(suffixStart);
      }
    }
  }

  // Rule 3: Handle common prefixes
  for (String prefix in prefixes) {
    if (cleanWord.startsWith(prefix) && cleanWord.length > prefix.length + 2) {
      if (!breakPoints.contains(prefix.length)) {
        breakPoints.add(prefix.length);
      }
    }
  }

  // Remove duplicates and sort
  breakPoints = breakPoints.toSet().toList();
  breakPoints.sort();

  // Create syllable parts
  if (breakPoints.isEmpty) {
    return word; // Can't split
  }

  List<String> syllableParts = [];
  int lastBreak = 0;

  for (int breakPoint in breakPoints) {
    if (breakPoint > lastBreak && breakPoint < cleanWord.length) {
      syllableParts.add(word.substring(lastBreak, breakPoint));
      lastBreak = breakPoint;
    }
  }

  // Add the final part
  if (lastBreak < word.length) {
    syllableParts.add(word.substring(lastBreak));
  }

  return syllableParts.join('•');
}
