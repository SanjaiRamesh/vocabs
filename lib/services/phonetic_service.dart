import 'package:dart_phonetics/dart_phonetics.dart';
import 'package:english_words/english_words.dart';

class PhoneticService {
  static final Map<String, String> _commonIPA = {
    'the': '/ðə/',
    'a': '/ə/',
    'cat': '/kæt/',
    'dog': '/dɔːg/',
    'run': '/rʌn/',
    'jump': '/dʒʌmp/',
    'play': '/pleɪ/',
    'happy': '/ˈhæpi/',
    'ball': '/bɔːl/',
    'book': '/bʊk/',
    'read': '/riːd/',
    'once': '/wʌns/',
    'upon': '/əˈpɔːn/',
    'time': '/taɪm/',
    'there': '/ðeər/',
    'was': '/wʌz/',
    'little': '/ˈlɪtəl/',
    'girl': '/ɡɜːrl/',
    'named': '/neɪmd/',
    'and': '/ænd/',
    'go': '/ɡoʊ/',
    'come': '/kʌm/',
    'get': '/ɡet/',
    'make': '/meɪk/',
    'take': '/teɪk/',
    'big': '/bɪɡ/',
    'small': '/smɔːl/',
    'house': '/haʊs/',
    'three': '/θriː/',
    'bears': '/beərz/',
    'chair': '/tʃeər/',
    'bed': '/bed/',
    'walk': '/wɔːk/',
    'found': '/faʊnd/',
    'inside': '/ɪnˈsaɪd/',
    'tired': '/ˈtaɪərd/',
    'scared': '/skeərd/',
    'ran': '/ræn/',
    'away': '/əˈweɪ/',
    'never': '/ˈnevər/',
    'again': '/əˈɡen/',
  };

  /// Get IPA transcription for a word
  static String getIPA(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.isEmpty) return word;

    // Check common IPA mappings first
    if (_commonIPA.containsKey(cleanWord)) {
      return _commonIPA[cleanWord]!;
    }

    // Generate basic IPA using phonetic rules
    return _generateBasicIPA(cleanWord);
  }

  /// Get phonetic breakdown using dart_phonetics
  static String getPhonetics(String word) {
    try {
      final soundex = Soundex();
      final metaphone = DoubleMetaphone();

      final soundexEncoding = soundex.encode(word);
      final metaphoneEncoding = metaphone.encode(word);

      String result = word;

      if (soundexEncoding?.primary != null &&
          soundexEncoding!.primary.isNotEmpty) {
        result += ' (Soundex: ${soundexEncoding.primary})';
      }

      if (metaphoneEncoding?.primary != null &&
          metaphoneEncoding!.primary.isNotEmpty) {
        result += ' (Metaphone: ${metaphoneEncoding.primary})';
      }

      return result;
    } catch (e) {
      return word;
    }
  }

  /// Get syllable breakdown using english_words package
  static String getSyllables(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.length <= 1) return cleanWord;

    try {
      int syllableCount = syllables(cleanWord);
      return '$cleanWord (${syllableCount} syllable${syllableCount == 1 ? '' : 's'})';
    } catch (e) {
      return cleanWord;
    }
  }

  /// Generate basic IPA using simple phonetic rules
  static String _generateBasicIPA(String word) {
    if (word.length <= 1) return '/$word/';

    // Basic consonant mappings
    String result = word
        .replaceAll('ch', 'tʃ')
        .replaceAll('sh', 'ʃ')
        .replaceAll('th', 'θ') // voiceless th
        .replaceAll('ng', 'ŋ')
        .replaceAll('ph', 'f')
        .replaceAll('gh', 'f')
        .replaceAll('ck', 'k')
        .replaceAll('qu', 'kw')
        .replaceAll('x', 'ks')
        .replaceAll('c', 'k') // simplified
        .replaceAll('y', 'i'); // simplified

    // Basic vowel mappings (simplified)
    result = result
        .replaceAll('ee', 'iː')
        .replaceAll('ea', 'iː')
        .replaceAll('oo', 'uː')
        .replaceAll('ou', 'aʊ')
        .replaceAll('ow', 'aʊ')
        .replaceAll('ai', 'eɪ')
        .replaceAll('ay', 'eɪ')
        .replaceAll('oi', 'ɔɪ')
        .replaceAll('oy', 'ɔɪ')
        .replaceAll('ie', 'aɪ')
        .replaceAll('igh', 'aɪ');

    return '/$result/';
  }

  /// Get phonics breakdown for early readers (simple sound groupings)
  static String getPhonics(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.length <= 1) return cleanWord;

    // Use educational phonics breakdown optimized for children
    return _educationalPhonicsBreakdown(cleanWord);
  }

  /// Educational phonics breakdown for children learning to read
  static String _educationalPhonicsBreakdown(String word) {
    if (word.length <= 1) return word;

    String result = '';

    // Common digraphs and trigraphs that should stay together
    List<String> consonantClusters = [
      'thr', 'shr', 'scr', 'spr', 'str', // 3-letter clusters first
      'ch', 'sh', 'th', 'ph', 'wh', 'ck', 'ng', 'qu',
      'bl', 'br', 'cl', 'cr', 'dr', 'fl', 'fr', 'gl', 'gr',
      'pl', 'pr', 'sc', 'sk', 'sl', 'sm', 'sn', 'sp', 'st', 'sw', 'tr', 'tw',
    ];

    // Vowel combinations that should stay together
    List<String> vowelCombinations = [
      'igh', 'ough', 'augh', // 3+ letter combinations first
      'ai', 'ay', 'ea', 'ee', 'ei', 'ie', 'oa', 'oo', 'ou', 'ow', 'ue', 'ui',
    ];

    List<String> vowels = ['a', 'e', 'i', 'o', 'u', 'y'];

    int i = 0;
    while (i < word.length) {
      bool clusterFound = false;

      // Check for vowel combinations first (longer ones first)
      for (String combo in vowelCombinations) {
        if (i + combo.length <= word.length &&
            word.substring(i, i + combo.length) == combo) {
          if (result.isNotEmpty) result += '-';
          result += combo;
          i += combo.length;
          clusterFound = true;
          break;
        }
      }

      if (clusterFound) continue;

      // Check for consonant clusters (longer ones first)
      for (String cluster in consonantClusters) {
        if (i + cluster.length <= word.length &&
            word.substring(i, i + cluster.length) == cluster) {
          if (result.isNotEmpty) result += '-';
          result += cluster;
          i += cluster.length;
          clusterFound = true;
          break;
        }
      }

      if (!clusterFound) {
        // Handle single letters with syllable-friendly breaks
        if (result.isNotEmpty) {
          String currentChar = word[i];
          String lastChar = result[result.length - 1];

          bool currentIsVowel = vowels.contains(currentChar);
          bool lastWasVowel = vowels.contains(lastChar);

          // Add hyphen between different sound types
          if (currentIsVowel != lastWasVowel) {
            result += '-';
          }
          // Don't break between consecutive consonants in most cases
          else if (!currentIsVowel && !lastWasVowel && result.length > 1) {
            // Only break if we have a clear syllable boundary
            if (i < word.length - 1 && vowels.contains(word[i + 1])) {
              result += '-';
            }
          }
        }
        result += word[i];
        i++;
      }
    }

    return result;
  }

  /// Check if two words sound similar using phonetic algorithms
  static bool soundsSimilar(String word1, String word2) {
    try {
      final soundex = Soundex();
      final encoding1 = soundex.encode(word1);
      final encoding2 = soundex.encode(word2);

      return encoding1?.primary == encoding2?.primary;
    } catch (e) {
      return false;
    }
  }
}
