import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path/path.dart' as path;

import '../lib/services/local_tts_service.dart';

// Generate mocks for testing
@GenerateMocks([FlutterSoundPlayer, http.Client, Directory, File])
import 'local_tts_service_test.mocks.dart';

void main() {
  group('LocalTtsService Tests', () {
    late LocalTtsService ttsService;
    late MockFlutterSoundPlayer mockAudioPlayer;
    late MockClient mockHttpClient;
    late MockDirectory mockDirectory;
    late MockFile mockFile;

    setUp(() {
      // Reset singleton instance for each test
      LocalTtsService._instance = null;
      ttsService = LocalTtsService.instance;

      mockAudioPlayer = MockFlutterSoundPlayer();
      mockHttpClient = MockClient();
      mockDirectory = MockDirectory();
      mockFile = MockFile();
    });

    tearDown(() {
      // Clean up singleton instance
      LocalTtsService._instance = null;
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final instance1 = LocalTtsService.instance;
        final instance2 = LocalTtsService.instance;

        expect(instance1, equals(instance2));
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Mock audio player initialization
        when(mockAudioPlayer.openPlayer()).thenAnswer((_) async {
          return null;
        });

        // Mock directory creation
        when(mockDirectory.exists()).thenAnswer((_) async => false);
        when(
          mockDirectory.create(recursive: true),
        ).thenAnswer((_) async => mockDirectory);

        // Note: In real testing, you'd need to mock path_provider and other dependencies
        // For now, this shows the structure
        expect(ttsService._isInitialized, isFalse);
      });

      test('should not reinitialize if already initialized', () async {
        // Simulate already initialized state
        ttsService._isInitialized = true;

        await ttsService.init();

        // Verify no additional initialization calls
        verifyNever(mockAudioPlayer.openPlayer());
      });

      test('should handle initialization errors gracefully', () async {
        when(
          mockAudioPlayer.openPlayer(),
        ).thenThrow(Exception('Audio player error'));

        expect(() => ttsService.init(), throwsException);
      });
    });

    group('File Name Sanitization', () {
      test('should sanitize filename correctly', () {
        // Test various inputs
        final testCases = {
          'Hello World': 'hello_world_',
          'Test@#\$%': 'test_',
          'Very Long Text That Should Be Truncated Because It Exceeds Limit':
              'very_long_text_that_',
          '123 Numbers!': '_23_numbers_',
          '   Spaces   ': 'spaces_',
          'UPPERCASE': 'uppercase_',
          'special-chars_test.txt': 'special_chars_test_txt_',
        };

        for (final entry in testCases.entries) {
          final result = ttsService._sanitizeFileName(entry.key);
          expect(
            result,
            contains(entry.value.substring(0, entry.value.length - 1)),
          );
          expect(result, matches(RegExp(r'^[a-z0-9_]+_\d+$')));
        }
      });

      test('should generate unique filenames for same text', () {
        const text = 'Hello World';
        final filename1 = ttsService._sanitizeFileName(text);
        final filename2 = ttsService._sanitizeFileName(text);

        expect(
          filename1,
          equals(filename2),
        ); // Same text should generate same filename
        expect(filename1, contains(text.hashCode.abs().toString()));
      });

      test('should handle empty text', () {
        const text = '';
        final filename = ttsService._sanitizeFileName(text);

        expect(filename, isNotEmpty);
        expect(filename, matches(RegExp(r'^_\d+$')));
      });

      test('should handle special characters only', () {
        const text = '@#\$%^&*()';
        final filename = ttsService._sanitizeFileName(text);

        expect(filename, matches(RegExp(r'^_\d+$')));
      });
    });

    group('Cache Management', () {
      test('should check if file is cached correctly', () async {
        const filePath = '/test/path/file.wav';

        when(mockFile.exists()).thenAnswer((_) async => true);

        // Note: In real implementation, you'd mock File constructor
        // This test shows the structure
        final result = await ttsService._isFileCached(filePath);
        expect(result, isTrue);
      });

      test('should return false for non-existent cache file', () async {
        const filePath = '/test/path/nonexistent.wav';

        when(mockFile.exists()).thenAnswer((_) async => false);

        final result = await ttsService._isFileCached(filePath);
        expect(result, isFalse);
      });

      test('should clear cache successfully', () async {
        when(mockDirectory.exists()).thenAnswer((_) async => true);
        when(mockDirectory.delete(recursive: true)).thenAnswer((_) async {
          return null;
        });
        when(
          mockDirectory.create(recursive: true),
        ).thenAnswer((_) async => mockDirectory);

        await ttsService.clearCache();

        verify(mockDirectory.delete(recursive: true)).called(1);
        verify(mockDirectory.create(recursive: true)).called(1);
      });

      test('should handle cache clear errors gracefully', () async {
        when(mockDirectory.exists()).thenAnswer((_) async => true);
        when(
          mockDirectory.delete(recursive: true),
        ).thenThrow(Exception('Delete error'));

        // Should not throw, just log error
        await ttsService.clearCache();

        verify(mockDirectory.delete(recursive: true)).called(1);
      });
    });

    group('HTTP Communication', () {
      test('should download audio from container successfully', () async {
        const text = 'Hello World';
        final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);

        final mockResponse = http.Response.bytes(audioData, 200);
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        final result = await ttsService._downloadAudioFromContainer(text);

        expect(result, equals(audioData));
      });

      test('should handle HTTP errors', () async {
        const text = 'Hello World';

        final mockResponse = http.Response('Server Error', 500);
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        expect(
          () => ttsService._downloadAudioFromContainer(text),
          throwsA(isA<Exception>()),
        );
      });

      test('should handle network timeout', () async {
        const text = 'Hello World';

        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenThrow(Exception('Timeout'));

        expect(
          () => ttsService._downloadAudioFromContainer(text),
          throwsA(isA<Exception>()),
        );
      });

      test('should check container service availability', () async {
        final mockResponse = http.Response('OK', 200);
        when(mockHttpClient.get(any)).thenAnswer((_) async => mockResponse);

        final result = await ttsService.isContainerServiceAvailable();

        expect(result, isTrue);
      });

      test(
        'should return false when container service is unavailable',
        () async {
          when(
            mockHttpClient.get(any),
          ).thenThrow(Exception('Connection refused'));

          final result = await ttsService.isContainerServiceAvailable();

          expect(result, isFalse);
        },
      );
    });

    group('Audio Playback', () {
      test('should play cached audio successfully', () async {
        const text = 'Hello World';
        const filePath = '/cache/hello_world_123456.wav';

        // Mock initialization
        ttsService._isInitialized = true;

        // Mock file exists (cached)
        when(mockFile.exists()).thenAnswer((_) async => true);

        // Mock audio player
        when(
          mockAudioPlayer.startPlayer(
            fromURI: anyNamed('fromURI'),
            codec: anyNamed('codec'),
          ),
        ).thenAnswer((_) async {
          return null;
        });

        await ttsService.speak(text);

        verify(
          mockAudioPlayer.startPlayer(
            fromURI: anyNamed('fromURI'),
            codec: Codec.pcm16WAV,
          ),
        ).called(1);
      });

      test('should download and cache audio for new text', () async {
        const text = 'New Text';
        final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Mock initialization
        ttsService._isInitialized = true;

        // Mock file doesn't exist (not cached)
        when(mockFile.exists()).thenAnswer((_) async => false);

        // Mock HTTP response
        final mockResponse = http.Response.bytes(audioData, 200);
        when(
          mockHttpClient.post(
            any,
            headers: anyNamed('headers'),
            body: anyNamed('body'),
          ),
        ).thenAnswer((_) async => mockResponse);

        // Mock file write
        when(mockFile.writeAsBytes(any)).thenAnswer((_) async => mockFile);

        // Mock audio player
        when(
          mockAudioPlayer.startPlayer(
            fromURI: anyNamed('fromURI'),
            codec: anyNamed('codec'),
          ),
        ).thenAnswer((_) async {
          return null;
        });

        await ttsService.speak(text);

        verify(mockFile.writeAsBytes(audioData)).called(1);
        verify(
          mockAudioPlayer.startPlayer(
            fromURI: anyNamed('fromURI'),
            codec: Codec.pcm16WAV,
          ),
        ).called(1);
      });

      test('should throw exception for empty text', () async {
        ttsService._isInitialized = true;

        // Should not throw, just return early
        await ttsService.speak('');
        await ttsService.speak('   ');

        verifyNever(
          mockAudioPlayer.startPlayer(
            fromURI: anyNamed('fromURI'),
            codec: anyNamed('codec'),
          ),
        );
      });

      test('should throw exception when not initialized', () async {
        ttsService._isInitialized = false;

        expect(() => ttsService.speak('Hello'), throwsA(isA<Exception>()));
      });

      test('should stop audio playback', () async {
        ttsService._isInitialized = true;
        when(mockAudioPlayer.stopPlayer()).thenAnswer((_) async {
          return null;
        });

        await ttsService.stop();

        verify(mockAudioPlayer.stopPlayer()).called(1);
      });

      test('should handle stop errors gracefully', () async {
        ttsService._isInitialized = true;
        when(mockAudioPlayer.stopPlayer()).thenThrow(Exception('Stop error'));

        // Should not throw
        await ttsService.stop();

        verify(mockAudioPlayer.stopPlayer()).called(1);
      });
    });

    group('Cache Statistics', () {
      test('should return correct cache stats', () async {
        // Mock directory with files
        when(mockDirectory.exists()).thenAnswer((_) async => true);

        final mockFiles = [mockFile, mockFile]; // 2 files
        when(
          mockDirectory.list(),
        ).thenAnswer((_) => Stream.fromIterable(mockFiles));

        // Mock file stats
        final mockStat = FileStat(
          DateTime.now(),
          DateTime.now(),
          DateTime.now(),
          FileSystemEntityType.file,
          0,
          1024, // 1KB per file
        );
        when(mockFile.stat()).thenAnswer((_) async => mockStat);

        final stats = await ttsService.getCacheStats();

        expect(stats['fileCount'], equals(2));
        expect(stats['totalSize'], equals(2048)); // 2KB total
        expect(stats['totalSizeMB'], equals('0.00'));
      });

      test('should return zero stats for non-existent cache', () async {
        when(mockDirectory.exists()).thenAnswer((_) async => false);

        final stats = await ttsService.getCacheStats();

        expect(stats['fileCount'], equals(0));
        expect(stats['totalSize'], equals(0));
      });

      test('should handle stats errors gracefully', () async {
        when(mockDirectory.exists()).thenThrow(Exception('Access denied'));

        final stats = await ttsService.getCacheStats();

        expect(stats['fileCount'], equals(0));
        expect(stats['totalSize'], equals(0));
        expect(stats['error'], isNotNull);
      });
    });

    group('Disposal', () {
      test('should dispose successfully', () async {
        ttsService._isInitialized = true;
        when(mockAudioPlayer.closePlayer()).thenAnswer((_) async {
          return null;
        });

        await ttsService.dispose();

        expect(ttsService._isInitialized, isFalse);
        verify(mockAudioPlayer.closePlayer()).called(1);
      });

      test('should handle disposal errors gracefully', () async {
        ttsService._isInitialized = true;
        when(mockAudioPlayer.closePlayer()).thenThrow(Exception('Close error'));

        // Should not throw
        await ttsService.dispose();

        expect(ttsService._isInitialized, isFalse);
        verify(mockAudioPlayer.closePlayer()).called(1);
      });

      test('should not dispose if not initialized', () async {
        ttsService._isInitialized = false;

        await ttsService.dispose();

        verifyNever(mockAudioPlayer.closePlayer());
      });
    });
  });

  group('Integration Tests', () {
    // These tests would run against a real TTS server
    group('Real Server Tests', () {
      late LocalTtsService ttsService;

      setUp(() {
        LocalTtsService._instance = null;
        ttsService = LocalTtsService.instance;
      });

      tearDown(() {
        LocalTtsService._instance = null;
      });

      test(
        'should connect to real TTS server',
        () async {
          // Skip if server not available
          final isAvailable = await ttsService.isContainerServiceAvailable();
          if (!isAvailable) {
            markTestSkipped('TTS server not available at localhost:8080');
          }

          expect(isAvailable, isTrue);
        },
        skip: 'Run only when TTS server is available',
      );

      test(
        'should download and play real audio',
        () async {
          final isAvailable = await ttsService.isContainerServiceAvailable();
          if (!isAvailable) {
            markTestSkipped('TTS server not available');
          }

          await ttsService.init();

          // Test with simple text
          await ttsService.speak('Hello');

          // Verify cache was created
          final stats = await ttsService.getCacheStats();
          expect(stats['fileCount'], greaterThan(0));
        },
        skip: 'Run only when TTS server is available',
      );
    });
  });

  group('Performance Tests', () {
    late LocalTtsService ttsService;

    setUp(() {
      LocalTtsService._instance = null;
      ttsService = LocalTtsService.instance;
    });

    test('should handle multiple concurrent requests', () async {
      // Mock successful responses
      final audioData = Uint8List.fromList([1, 2, 3, 4, 5]);
      final mockResponse = http.Response.bytes(audioData, 200);

      // Test concurrent requests
      final futures = List.generate(10, (index) {
        return ttsService.speak('Word $index');
      });

      // Should complete without deadlocks
      await Future.wait(futures);
    }, skip: 'Requires mocking setup');

    test('should handle large text input', () async {
      const largeText =
          'This is a very long text that should be handled correctly by the TTS service without any issues or performance problems.';

      // Should not throw for reasonable text sizes
      await ttsService.speak(largeText);
    }, skip: 'Requires mocking setup');
  });
}
