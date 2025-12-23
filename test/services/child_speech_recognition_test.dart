import 'package:flutter_test/flutter_test.dart';
import 'package:ra/services/child_speech_recognition_service.dart';

void main() {
  group('ChildFriendlyMatcher Tests', () {
    test('Perfect match should return high similarity', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the cat sits on the mat',
        'the cat sits on the mat',
      );
      expect(similarity, greaterThan(0.9)); // Perfect matches get ~95%
    });

    test('Child speech corrections should work', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'dis is a good book', // Child says "dis" instead of "this"
        'this is a good book',
      );
      expect(similarity, greaterThan(0.8));
    });

    test('Common mispronunciations should be handled', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'i wike dis book', // "like" -> "wike", "this" -> "dis"
        'i like this book',
      );
      expect(similarity, greaterThan(0.75));
    });

    test('Missing final consonants should be handled', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the ca is red', // "cat" -> "ca"
        'the cat is red',
      );
      expect(similarity, greaterThan(0.75));
    });

    test('R sound issues should be corrected', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the wed bird can wun', // "red" -> "wed", "run" -> "wun"
        'the red bird can run',
      );
      expect(similarity, greaterThan(0.75));
    });

    test('Extra words should reduce similarity but not fail', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the cat um sits on the mat', // Extra "um"
        'the cat sits on the mat',
      );
      expect(similarity, greaterThan(0.6));
      expect(similarity, lessThan(1.0));
    });

    test('Partial sentence should have lower score', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the cat sits', // Only part of the sentence
        'the cat sits on the mat',
      );
      expect(similarity, greaterThan(0.4)); // Adjusted expectation
      expect(similarity, lessThan(0.8));
    });

    test('Word order changes should be handled', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'sits the cat on mat', // Mixed word order
        'the cat sits on the mat',
      );
      expect(similarity, greaterThan(0.6));
    });

    test('Spelling out words should be partially recognized', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'the c a t sits', // Child spells "cat"
        'the cat sits',
      );
      expect(similarity, greaterThan(0.4));
    });

    test('Completely different text should have low similarity', () {
      final similarity = ChildFriendlyMatcher.calculateSimilarity(
        'dogs are running fast',
        'the cat sits on the mat',
      );
      expect(similarity, lessThan(0.3));
    });

    test('isAcceptableMatch should work with default threshold', () {
      // Good match
      expect(
        ChildFriendlyMatcher.isAcceptableMatch('dis is good', 'this is good'),
        isTrue,
      );

      // Poor match
      expect(
        ChildFriendlyMatcher.isAcceptableMatch(
          'completely different text',
          'this is good',
        ),
        isFalse,
      );
    });

    test('isAcceptableMatch should work with custom threshold', () {
      expect(
        ChildFriendlyMatcher.isAcceptableMatch(
          'the cat sits on mat', // Missing "the"
          'the cat sits on the mat',
          threshold: 0.5, // Lower threshold
        ),
        isTrue,
      );

      expect(
        ChildFriendlyMatcher.isAcceptableMatch(
          'the cat sits on mat', // Missing "the"
          'the cat sits on the mat',
          threshold: 0.9, // Higher threshold
        ),
        isFalse,
      );
    });
  });
}
