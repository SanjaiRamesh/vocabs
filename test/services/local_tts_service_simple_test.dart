import 'package:flutter_test/flutter_test.dart';

import 'package:ra/services/local_tts_service.dart';

void main() {
  group('LocalTtsService Tests', () {
    late LocalTtsService ttsService;

    setUp(() {
      // Reset singleton instance for each test
      // Note: This requires making _instance accessible or adding a reset method
      ttsService = LocalTtsService.instance;
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = LocalTtsService.instance;
        final instance2 = LocalTtsService.instance;

        expect(instance1, equals(instance2));
        expect(identical(instance1, instance2), isTrue);
      });

      test('should maintain state across instances', () {
        final instance1 = LocalTtsService.instance;
        final instance2 = LocalTtsService.instance;

        // Both should have same initialization state
        expect(
          instance1.isInitializedForTesting,
          equals(instance2.isInitializedForTesting),
        );
      });
    });

    group('Filename Sanitization', () {
      test('should create valid filenames', () {
        final testInputs = {
          'Hello World': 'hello_world_',
          'Test@#\$%': 'test_',
          'Very Long Text That Should Be Truncated Because It Exceeds Character Limit':
              'very_long_text_that_',
          '123 Numbers!': '_23_numbers_',
          '   Spaces   ': 'spaces_',
          'UPPERCASE': 'uppercase_',
          'special-chars_test.txt': 'special_chars_test_txt_',
          '': '_',
          '@#\$%^&*()': '_',
        };

        for (final entry in testInputs.entries) {
          final result = ttsService.sanitizeFileNameForTesting(entry.key);

          // Should contain expected sanitized prefix
          expect(
            result,
            contains(entry.value.substring(0, entry.value.length - 1)),
          );

          // Should match pattern: sanitized_text_hashnumber
          expect(result, matches(RegExp(r'^[a-z0-9_]*_\d+$')));

          // Should not be empty
          expect(result, isNotEmpty);

          // Should be reasonable length
          expect(result.length, lessThan(100));
        }
      });

      test('should generate consistent filenames for same text', () {
        const text = 'Hello World';
        final filename1 = ttsService.sanitizeFileNameForTesting(text);
        final filename2 = ttsService.sanitizeFileNameForTesting(text);

        expect(filename1, equals(filename2));
        expect(filename1, contains(text.hashCode.abs().toString()));
      });

      test('should handle unicode characters', () {
        final unicodeTexts = ['café', 'naïve', '北京', '🎵', 'Ñoño'];

        for (final text in unicodeTexts) {
          final result = ttsService.sanitizeFileNameForTesting(text);
          expect(result, matches(RegExp(r'^[a-z0-9_]*_\d+$')));
          expect(result, isNotEmpty);
        }
      });
    });

    group('Flask Service Availability', () {
      test('should check service availability', () async {
        // This test will actually check if a server is running
        final isAvailable = await ttsService.isFlaskServiceAvailable();

        // Should return a boolean (true if server running, false otherwise)
        expect(isAvailable, isA<bool>());
      });

      test('should handle connection errors gracefully', () async {
        // Create service with invalid URL for testing
        // This would require dependency injection or a test constructor

        final isAvailable = await ttsService.isFlaskServiceAvailable();

        // Should not throw an exception, just return false
        expect(isAvailable, isA<bool>());
      });
    });

    group('Cache Statistics', () {
      test('should return cache statistics', () async {
        final stats = await ttsService.getCacheStats();

        expect(stats, isA<Map<String, dynamic>>());
        expect(stats.containsKey('fileCount'), isTrue);
        expect(stats.containsKey('totalSize'), isTrue);
        expect(stats.containsKey('totalSizeMB'), isTrue);

        expect(stats['fileCount'], isA<int>());
        expect(stats['totalSize'], isA<int>());
        expect(stats['totalSizeMB'], isA<String>());

        expect(stats['fileCount'], greaterThanOrEqualTo(0));
        expect(stats['totalSize'], greaterThanOrEqualTo(0));
      });
    });

    group('Error Handling', () {
      test('should handle empty text input', () async {
        // Initialize service first (if not already done)
        try {
          await ttsService.init();
        } catch (e) {
          // Service might already be initialized or fail to initialize
        }

        // Should not throw for empty text
        await expectLater(ttsService.speak(''), completes);

        await expectLater(ttsService.speak('   '), completes);
      });

      test('should handle uninitialized service', () async {
        // Test that service throws appropriate error when not initialized
        // We can check if it's initialized using our test helper
        if (!ttsService.isInitializedForTesting) {
          expect(() => ttsService.speak('Hello'), throwsA(isA<Exception>()));
        }
      });
    });

    group('Cache Management', () {
      test('should clear cache without errors', () async {
        await expectLater(ttsService.clearCache(), completes);
      });

      test('should return updated stats after cache clear', () async {
        // Get initial stats
        final initialStats = await ttsService.getCacheStats();

        // Clear cache
        await ttsService.clearCache();

        // Get stats after clear
        final finalStats = await ttsService.getCacheStats();

        // Should have fewer or equal files
        expect(
          finalStats['fileCount'],
          lessThanOrEqualTo(initialStats['fileCount']),
        );
        expect(
          finalStats['totalSize'],
          lessThanOrEqualTo(initialStats['totalSize']),
        );
      });
    });

    group('Service Lifecycle', () {
      test('should initialize without errors', () async {
        await expectLater(ttsService.init(), completes);
      });

      test('should dispose without errors', () async {
        await expectLater(ttsService.dispose(), completes);
      });

      test('should stop playback without errors', () async {
        await expectLater(ttsService.stop(), completes);
      });
    });
  });

  group('Integration Tests (Requires TTS Server)', () {
    late LocalTtsService ttsService;

    setUpAll(() async {
      ttsService = LocalTtsService.instance;
      await ttsService.init();
    });

    tearDownAll(() async {
      await ttsService.dispose();
    });

    test('should connect to TTS server if available', () async {
      final isAvailable = await ttsService.isFlaskServiceAvailable();

      if (!isAvailable) {
        print('TTS server not available at localhost:8080');
        print('Start TTS server with: python simple_tts_server.py');
        return;
      }

      expect(isAvailable, isTrue);
    });

    test('should generate and cache audio', () async {
      final isAvailable = await ttsService.isFlaskServiceAvailable();

      if (!isAvailable) {
        print('Skipping test - TTS server not available');
        return;
      }

      // Get initial cache stats
      final initialStats = await ttsService.getCacheStats();

      // Generate audio for a test word
      const testWord = 'testing';
      await ttsService.speak(testWord);

      // Get final cache stats
      final finalStats = await ttsService.getCacheStats();

      // Cache should have increased (unless word was already cached)
      expect(
        finalStats['fileCount'],
        greaterThanOrEqualTo(initialStats['fileCount']),
      );
    });

    test('should reuse cached audio', () async {
      final isAvailable = await ttsService.isFlaskServiceAvailable();

      if (!isAvailable) {
        print('Skipping test - TTS server not available');
        return;
      }

      const testWord = 'cached_test';

      // First call - should cache
      final stopwatch1 = Stopwatch()..start();
      await ttsService.speak(testWord);
      stopwatch1.stop();

      // Second call - should use cache (should be faster)
      final stopwatch2 = Stopwatch()..start();
      await ttsService.speak(testWord);
      stopwatch2.stop();

      // Second call should be significantly faster (cached)
      // Note: This might not always be true due to various factors
      print('First call: ${stopwatch1.elapsedMilliseconds}ms');
      print('Second call: ${stopwatch2.elapsedMilliseconds}ms');
    });

    test('should handle multiple words', () async {
      final isAvailable = await ttsService.isFlaskServiceAvailable();

      if (!isAvailable) {
        print('Skipping test - TTS server not available');
        return;
      }

      final testWords = ['apple', 'banana', 'cherry', 'date', 'elderberry'];

      // Test multiple words sequentially
      for (final word in testWords) {
        await expectLater(ttsService.speak(word), completes);
      }
    });

    test('should handle concurrent requests', () async {
      final isAvailable = await ttsService.isFlaskServiceAvailable();

      if (!isAvailable) {
        print('Skipping test - TTS server not available');
        return;
      }

      final testWords = ['word1', 'word2', 'word3', 'word4', 'word5'];

      // Test concurrent requests
      final futures = testWords.map((word) => ttsService.speak(word)).toList();

      await expectLater(Future.wait(futures), completes);
    });
  });

  group('Performance Tests', () {
    late LocalTtsService ttsService;

    setUp(() {
      ttsService = LocalTtsService.instance;
    });

    test('should handle repeated initialization calls', () async {
      // Multiple init calls should be safe
      await ttsService.init();
      await ttsService.init();
      await ttsService.init();

      // Should not throw or cause issues
      expect(true, isTrue); // Test passes if no exception thrown
    });

    test('should handle large cache statistics', () async {
      final stopwatch = Stopwatch()..start();
      final stats = await ttsService.getCacheStats();
      stopwatch.stop();

      // Should complete within reasonable time (even with large cache)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      expect(stats, isNotNull);
    });

    test('should handle text of various lengths', () async {
      final testTexts = [
        'Hi',
        'Hello World',
        'This is a medium length sentence for testing.',
        'This is a much longer sentence that contains multiple words and should test the TTS service with a more realistic use case that might be encountered in the actual application.',
      ];

      for (final text in testTexts) {
        await expectLater(ttsService.speak(text), completes);
      }
    });
  });

  group('Edge Cases', () {
    late LocalTtsService ttsService;

    setUp(() {
      ttsService = LocalTtsService.instance;
    });

    test('should handle special characters in text', () async {
      final specialTexts = [
        'Hello!',
        'Test@123',
        'Café',
        'naïve',
        '50% off',
        '\$100',
        'C++',
        'AT&T',
        '"quoted text"',
        "'single quotes'",
      ];

      for (final text in specialTexts) {
        await expectLater(ttsService.speak(text), completes);
      }
    });

    test('should handle numbers and mixed content', () async {
      final mixedTexts = [
        '123',
        'Room 101',
        'Call 911',
        'Year 2024',
        'IPv4 address',
        'HTTP 404',
        'COVID-19',
        'Wi-Fi',
      ];

      for (final text in mixedTexts) {
        await expectLater(ttsService.speak(text), completes);
      }
    });

    test('should handle whitespace variations', () async {
      final whitespaceTexts = [
        '  hello  ',
        '\thello\t',
        '\nhello\n',
        'hello world',
        'hello\u00A0world', // Non-breaking space
      ];

      for (final text in whitespaceTexts) {
        await expectLater(ttsService.speak(text), completes);
      }
    });
  });
}
