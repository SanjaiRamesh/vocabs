import 'package:english_words/english_words.dart';

void main() {
  // Test the actual syllable breaking logic from the app
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
  ];

  print('=== CURRENT SYLLABLE BREAKING LOGIC ===');
  for (String word in testWords) {
    int count = syllables(word);
    String broken = _breakIntoSyllables(word, count);
    print('$word (${count} syllables) -> $broken');
  }
}

String _breakIntoSyllables(String word, int targetSyllableCount) {
  if (word.length <= 3 || targetSyllableCount <= 1) return word;

  try {
    // Use the accurate syllable count from english_words package
    List<String> syllableParts = [];
    List<String> vowels = ['a', 'e', 'i', 'o', 'u', 'y'];

    // Find vowel positions to guide syllable breaks
    List<int> vowelPositions = [];
    for (int i = 0; i < word.length; i++) {
      if (vowels.contains(word[i])) {
        vowelPositions.add(i);
      }
    }

    if (vowelPositions.length <= 1) {
      return word; // Single syllable word
    }

    // Break the word based on the target syllable count
    if (targetSyllableCount == 2) {
      // For two syllables, split roughly in the middle
      int midPoint = (word.length / 2).round();

      // Adjust mid point to avoid breaking vowel clusters
      for (
        int i = midPoint - 1;
        i <= midPoint + 1 && i < word.length - 1;
        i++
      ) {
        if (i > 0 &&
            !vowels.contains(word[i]) &&
            vowels.contains(word[i + 1])) {
          midPoint = i + 1;
          break;
        }
      }

      return '${word.substring(0, midPoint)}•${word.substring(midPoint)}';
    } else if (targetSyllableCount >= 3) {
      // For multiple syllables, distribute evenly
      List<int> breakPoints = [];
      double segmentLength = word.length / targetSyllableCount;

      for (int i = 1; i < targetSyllableCount; i++) {
        int breakPoint = (segmentLength * i).round();

        // Adjust break point to find best consonant-vowel boundary
        for (
          int j = breakPoint - 1;
          j <= breakPoint + 1 && j < word.length - 1;
          j++
        ) {
          if (j > 0 &&
              !vowels.contains(word[j]) &&
              vowels.contains(word[j + 1])) {
            breakPoint = j + 1;
            break;
          }
        }

        if (breakPoint > 0 && breakPoint < word.length) {
          breakPoints.add(breakPoint);
        }
      }

      // Create syllable parts
      int lastBreak = 0;
      for (int breakPoint in breakPoints) {
        if (breakPoint > lastBreak) {
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

    return word;
  } catch (e) {
    // Ultra-simple fallback
    return word;
  }
}
