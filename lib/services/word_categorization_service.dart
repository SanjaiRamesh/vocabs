import 'package:english_words/english_words.dart';

/// Professional word categorization service using English Words package
/// Replaces large hardcoded word lists with intelligent categorization
class WordCategorizationService {
  /// Get word category using professional algorithms and word lists
  static String getWordCategory(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (cleanWord.isEmpty) return 'UNKNOWN';

    // Question words (small hardcoded list is fine for these)
    if (_isQuestionWord(cleanWord)) {
      return 'QUESTION';
    }

    // Check connectors first (before other checks)
    if (_isConnector(cleanWord)) {
      return 'CONNECTOR';
    }

    // Check people first (before other patterns that might match)
    if (_isPeopleRelated(cleanWord)) {
      return 'PEOPLE';
    }

    // Check animals
    if (_isAnimalRelated(cleanWord)) {
      return 'ANIMAL';
    }

    // Check if it's a verb/action word
    if (_isLikelyVerb(cleanWord)) {
      return 'ACTION';
    }

    // Check if it's an adjective/descriptive word
    if (_isLikelyAdjective(cleanWord)) {
      return 'DESCRIBE';
    }

    // Use english_words package predefined lists for remaining nouns
    if (nouns.contains(cleanWord)) {
      return 'OBJECT';
    }

    return 'OTHER';
  }

  /// Check if word is a question word (small list is manageable)
  static bool _isQuestionWord(String word) {
    const questionWords = {
      'who',
      'what',
      'where',
      'when',
      'why',
      'how',
      'which',
      'whose',
    };
    return questionWords.contains(word);
  }

  /// Smart people detection using common patterns
  static bool _isPeopleRelated(String word) {
    const peopleWords = {
      'person', 'people', 'man', 'woman', 'child', 'boy', 'girl', 'baby',
      'mother', 'father', 'parent', 'family', 'friend', 'teacher', 'student',
      'doctor', 'nurse', 'police', 'firefighter', 'cook', 'driver', 'artist',
      'king', 'queen', 'prince', 'princess', 'knight', 'witch', 'wizard',
      'goldilocks', 'worker', 'helper', 'builder', 'painter', 'singer',
      'dancer',
      'writer',
      'reader',
      'player',
      'runner',
      'walker', // Story characters
    };

    // Check exact matches first
    if (peopleWords.contains(word)) return true;

    // Pattern matching: words ending in -er, -or often refer to people (professions)
    if (word.endsWith('er') || word.endsWith('or')) {
      // But exclude common adjectives ending in -er
      const adjectiveExceptions = {
        'bigger',
        'smaller',
        'faster',
        'slower',
        'better',
        'other',
      };
      if (!adjectiveExceptions.contains(word)) {
        return true;
      }
    }

    return false;
  }

  /// Smart animal detection
  static bool _isAnimalRelated(String word) {
    const animalWords = {
      'animal', 'cat', 'dog', 'bird', 'fish', 'bear', 'lion', 'tiger',
      'elephant', 'horse', 'cow', 'pig', 'sheep', 'chicken', 'duck',
      'rabbit', 'mouse', 'squirrel', 'fox', 'wolf', 'deer', 'monkey',
      'snake', 'frog', 'turtle', 'butterfly', 'bee', 'ant', 'spider',
      'bears', 'cats', 'dogs', 'birds', // Common plural forms
    };

    // Check exact matches
    if (animalWords.contains(word)) return true;

    // Pattern: plural animals (remove 's' and check)
    if (word.endsWith('s') && word.length > 3) {
      final singular = word.substring(0, word.length - 1);
      if (animalWords.contains(singular)) {
        return true;
      }
    }

    return false;
  }

  /// Common connectors (manageable small list)
  static bool _isConnector(String word) {
    const connectors = {
      'and',
      'but',
      'because',
      'then',
      'so',
      'or',
      'if',
      'while',
      'after',
      'before',
      'since',
      'until',
      'although',
      'however',
      'therefore',
    };
    return connectors.contains(word);
  }

  /// Detect likely adjectives using linguistic patterns
  static bool _isLikelyAdjective(String word) {
    // Common adjective endings
    if (word.endsWith('ful') ||
        word.endsWith('less') ||
        word.endsWith('able') ||
        word.endsWith('ible') ||
        word.endsWith('ous') ||
        word.endsWith('ive') ||
        word.endsWith('al') ||
        word.endsWith('ic') ||
        word.endsWith('ary')) {
      return true;
    }

    // Comparative and superlative forms
    if (word.endsWith('er') || word.endsWith('est')) {
      return true;
    }

    // Short descriptive words are often adjectives
    if (word.length <= 6) {
      const shortAdjectives = {
        'big',
        'small',
        'good',
        'bad',
        'new',
        'old',
        'happy',
        'sad',
        'hot',
        'cold',
        'fast',
        'slow',
        'loud',
        'quiet',
        'bright',
        'dark',
        'little',
        'large',
        'tiny',
        'quick',
        'beautiful',
        'ugly',
        'warm',
        'cool',
        'soft',
        'hard',
        'smooth',
        'rough',
        'sweet',
        'sour',
        'young',
        'tall',
        'short',
        'long',
        'wide',
        'narrow',
        'thick',
        'thin',
        'heavy',
        'light',
        'strong',
        'weak',
        'clean',
        'dirty',
        'full',
        'empty',
        'open',
        'closed',
      };
      return shortAdjectives.contains(word);
    }

    return false;
  }

  /// Detect likely verbs using linguistic patterns
  static bool _isLikelyVerb(String word) {
    // Common verb endings
    if (word.endsWith('ing') ||
        word.endsWith('ed') ||
        word.endsWith('ize') ||
        word.endsWith('ise') ||
        word.endsWith('ate') ||
        word.endsWith('fy')) {
      return true;
    }

    // Common action words
    const actionWords = {
      'run',
      'walk',
      'jump',
      'play',
      'eat',
      'drink',
      'sleep',
      'wake',
      'go',
      'come',
      'see',
      'look',
      'hear',
      'say',
      'tell',
      'make',
      'do',
      'get',
      'give',
      'take',
      'put',
      'move',
      'stop',
      'start',
      'help',
      'work',
      'love',
      'like',
      'want',
      'need',
      'sit',
      'stand',
      'dance',
      'sing',
      'read',
      'write',
      'draw',
      'paint',
      'cook',
      'clean',
      'wash',
      'brush',
      'dress',
      'wear',
      'open',
      'close',
      'push',
      'pull',
      'throw',
      'catch',
      'kick',
      'hit',
      'touch',
      'hold',
      'carry',
      'lift',
      'drop',
      'fall',
      'climb',
      'fly',
      'swim',
      'drive',
      'ride',
      'arrive',
      'leave',
      'enter',
      'exit',
      'begin',
      'end',
      'finish',
      'continue',
      'hurt',
      'heal',
      'hope',
      'wish',
      'think',
      'know',
      'learn',
      'teach',
      'remember',
      'forget',
      'understand',
      'explain',
      'listen',
      'watch',
      'show',
      'hide',
      'find',
      'lose',
      'search',
      'discover',
      'explore',
      'travel',
      'visit',
      'stay',
      'live',
      'study',
      'practice',
      'try',
      'succeed',
      'fail',
      'win',
      'choose',
      'decide',
      'agree',
      'disagree',
      'argue',
      'fight',
      'forgive',
      'apologize',
      'thank',
      'welcome',
      'invite',
      'celebrate',
      'enjoy',
      'relax',
      'rest',
      'exercise',
      'stretch',
      'bend',
      'turn',
      'wait',
      'hurry',
      'rush',
    };
    return actionWords.contains(word);
  }

  /// Get additional word information
  static Map<String, dynamic> getWordInfo(String word) {
    final cleanWord = word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    final category = getWordCategory(cleanWord);
    final syllableCount = syllables(cleanWord);

    return {
      'word': cleanWord,
      'category': category,
      'syllables': syllableCount,
      'isCommonNoun': nouns.contains(cleanWord),
      'isCommonWord': all.take(5000).contains(cleanWord), // Top 5000 words
    };
  }
}
