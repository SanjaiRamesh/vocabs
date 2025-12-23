import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ra/services/ocr_text_processor.dart';

void main() {
  group('OCR Text Processor Tests', () {
    test('should process simple numbered list', () {
      // Mock data simulating OCR results for:
      // 1. First question here
      // 2. Second question
      // a) Sub item

      final mockBlocks = [
        TextBlock(
          text: '1. First question here',
          lines: [
            TextLine(
              text: '1. First question here',
              elements: [
                TextElement(
                  text: '1.',
                  boundingBox: Rect.fromLTWH(10, 10, 20, 15),
                ),
                TextElement(
                  text: 'First',
                  boundingBox: Rect.fromLTWH(35, 10, 30, 15),
                ),
                TextElement(
                  text: 'question',
                  boundingBox: Rect.fromLTWH(70, 10, 50, 15),
                ),
                TextElement(
                  text: 'here',
                  boundingBox: Rect.fromLTWH(125, 10, 30, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 10, 145, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 10, 145, 15),
        ),
        TextBlock(
          text: '2. Second question',
          lines: [
            TextLine(
              text: '2. Second question',
              elements: [
                TextElement(
                  text: '2.',
                  boundingBox: Rect.fromLTWH(10, 30, 20, 15),
                ),
                TextElement(
                  text: 'Second',
                  boundingBox: Rect.fromLTWH(35, 30, 40, 15),
                ),
                TextElement(
                  text: 'question',
                  boundingBox: Rect.fromLTWH(80, 30, 50, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 30, 120, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 30, 120, 15),
        ),
        TextBlock(
          text: 'a) Sub item',
          lines: [
            TextLine(
              text: 'a) Sub item',
              elements: [
                TextElement(
                  text: 'a)',
                  boundingBox: Rect.fromLTWH(10, 50, 25, 15),
                ),
                TextElement(
                  text: 'Sub',
                  boundingBox: Rect.fromLTWH(40, 50, 25, 15),
                ),
                TextElement(
                  text: 'item',
                  boundingBox: Rect.fromLTWH(70, 50, 30, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 50, 90, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 50, 90, 15),
        ),
      ];

      final recognizedText = RecognizedText(text: '', blocks: mockBlocks);
      final result = OcrTextProcessor.extractReadingItems(recognizedText);

      expect(result.length, equals(3));
      expect(result[0], equals('1. First question here'));
      expect(result[1], equals('2. Second question'));
      expect(result[2], equals('a) Sub item'));
    });

    test('should merge continuation lines', () {
      // Mock data for:
      // 1. This is a long question
      //    that continues on next line

      final mockBlocks = [
        TextBlock(
          text: '1. This is a long question',
          lines: [
            TextLine(
              text: '1. This is a long question',
              elements: [
                TextElement(
                  text: '1.',
                  boundingBox: Rect.fromLTWH(10, 10, 20, 15),
                ),
                TextElement(
                  text: 'This',
                  boundingBox: Rect.fromLTWH(35, 10, 30, 15),
                ),
                TextElement(
                  text: 'is',
                  boundingBox: Rect.fromLTWH(70, 10, 20, 15),
                ),
                TextElement(
                  text: 'a',
                  boundingBox: Rect.fromLTWH(95, 10, 15, 15),
                ),
                TextElement(
                  text: 'long',
                  boundingBox: Rect.fromLTWH(115, 10, 30, 15),
                ),
                TextElement(
                  text: 'question',
                  boundingBox: Rect.fromLTWH(150, 10, 50, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 10, 190, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 10, 190, 15),
        ),
        TextBlock(
          text: 'that continues on next line',
          lines: [
            TextLine(
              text: 'that continues on next line',
              elements: [
                TextElement(
                  text: 'that',
                  boundingBox: Rect.fromLTWH(10, 20, 30, 15),
                ),
                TextElement(
                  text: 'continues',
                  boundingBox: Rect.fromLTWH(45, 20, 60, 15),
                ),
                TextElement(
                  text: 'on',
                  boundingBox: Rect.fromLTWH(110, 20, 20, 15),
                ),
                TextElement(
                  text: 'next',
                  boundingBox: Rect.fromLTWH(135, 20, 30, 15),
                ),
                TextElement(
                  text: 'line',
                  boundingBox: Rect.fromLTWH(170, 20, 30, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 20, 190, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 20, 190, 15),
        ),
      ];

      final recognizedText = RecognizedText(text: '', blocks: mockBlocks);
      final result = OcrTextProcessor.extractReadingItems(recognizedText);

      expect(result.length, equals(1));
      expect(
        result[0],
        equals('1. This is a long question that continues on next line'),
      );
    });

    test('should remove junk and clean whitespace', () {
      // Mock data with extra spaces and junk
      final mockBlocks = [
        TextBlock(
          text: '1.   Extra   spaces   here',
          lines: [
            TextLine(
              text: '1.   Extra   spaces   here',
              elements: [
                TextElement(
                  text: '1.',
                  boundingBox: Rect.fromLTWH(10, 10, 20, 15),
                ),
                TextElement(
                  text: 'Extra',
                  boundingBox: Rect.fromLTWH(50, 10, 30, 15),
                ),
                TextElement(
                  text: 'spaces',
                  boundingBox: Rect.fromLTWH(100, 10, 40, 15),
                ),
                TextElement(
                  text: 'here',
                  boundingBox: Rect.fromLTWH(160, 10, 30, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 10, 180, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 10, 180, 15),
        ),
        TextBlock(
          text: '| | |',
          lines: [
            TextLine(
              text: '| | |',
              elements: [
                TextElement(
                  text: '|',
                  boundingBox: Rect.fromLTWH(10, 30, 10, 15),
                ),
                TextElement(
                  text: '|',
                  boundingBox: Rect.fromLTWH(25, 30, 10, 15),
                ),
                TextElement(
                  text: '|',
                  boundingBox: Rect.fromLTWH(40, 30, 10, 15),
                ),
              ],
              boundingBox: Rect.fromLTWH(10, 30, 40, 15),
            ),
          ],
          boundingBox: Rect.fromLTWH(10, 30, 40, 15),
        ),
      ];

      final recognizedText = RecognizedText(text: '', blocks: mockBlocks);
      final result = OcrTextProcessor.extractReadingItems(recognizedText);

      expect(result.length, equals(1));
      expect(result[0], equals('1. Extra spaces here'));
    });
  });
}
