import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:ui';

/// Processes OCR results into clean reading practice items
class OcrTextProcessor {
  /// Converts RecognizedText to a List<String> for reading practice
  static List<String> processForReading(RecognizedText result) {
    if (result.blocks.isEmpty) return [];

    // Step 1: Reconstruct true lines from OCR elements
    List<_ReconstructedLine> lines = _reconstructLines(result);

    // Step 2: Sort lines by reading order (top then left)
    lines.sort((a, b) {
      int topCompare = a.top.compareTo(b.top);
      return topCompare != 0 ? topCompare : a.left.compareTo(b.left);
    });

    // Step 3: Calculate median line height for grouping
    double medianHeight = _calculateMedianHeight(lines);

    // Step 4: Group lines into reading items
    List<String> items = _groupIntoItems(lines, medianHeight);

    // Step 5: Clean up and return
    return _cleanItems(items);
  }

  /// Reconstructs complete lines from OCR blocks and elements
  static List<_ReconstructedLine> _reconstructLines(RecognizedText result) {
    List<_ReconstructedLine> lines = [];

    for (TextBlock block in result.blocks) {
      for (TextLine line in block.lines) {
        // Sort elements within line by left position
        List<TextElement> sortedElements = List.from(line.elements)
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

        // Join elements to form complete line text
        String text = sortedElements.map((e) => e.text).join(' ');

        // Calculate line bounds
        Rect bounds = line.boundingBox;
        double centerX = bounds.left + (bounds.width / 2);

        lines.add(
          _ReconstructedLine(
            text: text.trim(),
            left: bounds.left.toDouble(),
            right: bounds.right.toDouble(),
            top: bounds.top.toDouble(),
            bottom: bounds.bottom.toDouble(),
            height: bounds.height.toDouble(),
            centerX: centerX,
          ),
        );
      }
    }

    return lines;
  }

  /// Calculates median line height for grouping threshold
  static double _calculateMedianHeight(List<_ReconstructedLine> lines) {
    if (lines.isEmpty) return 20.0;

    List<double> heights = lines.map((l) => l.height).toList()..sort();
    int middle = heights.length ~/ 2;

    if (heights.length % 2 == 0) {
      return (heights[middle - 1] + heights[middle]) / 2;
    } else {
      return heights[middle];
    }
  }

  /// Groups lines into reading items based on markers and proximity
  static List<String> _groupIntoItems(
    List<_ReconstructedLine> lines,
    double medianHeight,
  ) {
    if (lines.isEmpty) return [];

    List<String> items = [];
    String currentItem = '';
    double? lastBottom;

    for (int i = 0; i < lines.length; i++) {
      _ReconstructedLine line = lines[i];

      // Check if this line starts a new item (has marker)
      bool startsNewItem = _hasMarker(line.text);

      // Check if this line should continue previous item (close proximity, no marker)
      bool shouldContinue = false;
      if (!startsNewItem && lastBottom != null && currentItem.isNotEmpty) {
        double gap = line.top - lastBottom;
        shouldContinue = gap <= (0.4 * medianHeight);
      }

      if (startsNewItem || !shouldContinue) {
        // Start new item
        if (currentItem.isNotEmpty) {
          items.add(currentItem);
        }
        currentItem = line.text;
      } else {
        // Continue current item
        currentItem += ' ${line.text}';
      }

      lastBottom = line.bottom;
    }

    // Add the final item
    if (currentItem.isNotEmpty) {
      items.add(currentItem);
    }

    return items;
  }

  /// Checks if text starts with a list marker
  static bool _hasMarker(String text) {
    if (text.isEmpty) return false;

    // Regex pattern for various markers:
    // - Numbers with dot: 1., 2., 10.
    // - Letters with dot/parenthesis: a), b., A), A.
    // - Roman numerals: I., II., i., ii.
    // - Numbers in parentheses: (1), (2)
    // - Letters in parentheses: (a), (b)
    RegExp markerPattern = RegExp(
      r'^\s*([0-9]+[\.\)]|[IVXivx]+[\.\)]|[a-zA-Z][\.\)\:]|\([0-9]+\)|\([a-zA-Z]\))',
    );

    return markerPattern.hasMatch(text);
  }

  /// Cleans up items by removing junk and normalizing whitespace
  static List<String> _cleanItems(List<String> items) {
    return items
        .map((item) => _cleanText(item))
        .where((item) => item.isNotEmpty && !_isJunk(item))
        .toList();
  }

  /// Cleans individual text item
  static String _cleanText(String text) {
    // Remove table separators and stray pipes
    text = text.replaceAll(RegExp(r'\|+'), ' ');
    text = text.replaceAll(RegExp(r'[-=]{3,}'), ' ');

    // Normalize whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');

    return text.trim();
  }

  /// Checks if text is junk (orphan digits, single letters, etc.)
  static bool _isJunk(String text) {
    if (text.length <= 2) {
      // Single digit or letter with punctuation only
      return RegExp(r'^[0-9a-zA-Z][\.\)\:]?$').hasMatch(text);
    }

    // Empty or only punctuation
    return RegExp(r'^[\s\.\-\|\(\)\:]*$').hasMatch(text);
  }
}

/// Internal class to represent a reconstructed OCR line
class _ReconstructedLine {
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double height;
  final double centerX;

  _ReconstructedLine({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.height,
    required this.centerX,
  });

  @override
  String toString() {
    return 'Line(text: "$text", top: $top, left: $left)';
  }
}
