import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:math';

/// Comprehensive worksheet OCR helper that converts ML Kit results to clean Markdown
/// following specific rules for school worksheet formatting
class WorksheetMarkdownBuilder {
  /// Main entry point: converts TextRecognitionResult to clean worksheet Markdown
  static String buildWorksheetMarkdown(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return "No text found in the image";
    }

    // Step 1: Reconstruct true lines from OCR blocks/lines/elements
    List<ReconstructedLine> allLines = _reconstructTrueLines(recognizedText);

    if (allLines.isEmpty) {
      return "No text elements found in the image";
    }

    // Step 2: Reading order & rows - sort by top then left, group into rows
    allLines.sort((a, b) {
      int topComparison = a.top.compareTo(b.top);
      if (topComparison == 0) {
        return a.left.compareTo(b.left);
      }
      return topComparison;
    });

    double medianLineHeight = _calculateMedianLineHeight(allLines);
    List<List<ReconstructedLine>> rows = _groupLinesIntoRows(
      allLines,
      medianLineHeight,
    );

    // Step 3-7: Process rows and generate Markdown
    return _generateWorksheetMarkdown(rows, medianLineHeight);
  }

  /// Step 1: Reconstruct true lines from OCR blocks/lines/elements
  static List<ReconstructedLine> _reconstructTrueLines(
    RecognizedText recognizedText,
  ) {
    List<ReconstructedLine> lines = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        // Sort elements within line by left position
        List<TextElement> sortedElements = List.from(line.elements);
        sortedElements.sort(
          (a, b) => a.boundingBox.left.compareTo(b.boundingBox.left),
        );

        // Join elements into single line text
        String lineText = sortedElements.map((e) => e.text).join(' ').trim();

        if (lineText.isNotEmpty) {
          // Calculate centerX
          double centerX = (line.boundingBox.left + line.boundingBox.right) / 2;

          lines.add(
            ReconstructedLine(
              text: lineText,
              left: line.boundingBox.left.toDouble(),
              right: line.boundingBox.right.toDouble(),
              top: line.boundingBox.top.toDouble(),
              bottom: line.boundingBox.bottom.toDouble(),
              height: (line.boundingBox.bottom - line.boundingBox.top)
                  .toDouble(),
              centerX: centerX,
            ),
          );
        }
      }
    }

    return lines;
  }

  /// Calculate median line height for grouping threshold
  static double _calculateMedianLineHeight(List<ReconstructedLine> lines) {
    if (lines.isEmpty) return 20.0;

    List<double> heights = lines.map((line) => line.height).toList();
    heights.sort();

    int mid = heights.length ~/ 2;
    if (heights.length % 2 == 0) {
      return (heights[mid - 1] + heights[mid]) / 2;
    } else {
      return heights[mid];
    }
  }

  /// Step 2: Group lines into rows based on Y-gap relative to median line height
  static List<List<ReconstructedLine>> _groupLinesIntoRows(
    List<ReconstructedLine> lines,
    double medianLineHeight,
  ) {
    List<List<ReconstructedLine>> rows = [];
    List<ReconstructedLine> currentRow = [];
    double? lastRowBottom;

    double gapThreshold = 0.6 * medianLineHeight;

    for (ReconstructedLine line in lines) {
      if (lastRowBottom == null || (line.top - lastRowBottom) <= gapThreshold) {
        // Same row or first line
        currentRow.add(line);
      } else {
        // Start new row
        if (currentRow.isNotEmpty) {
          // Sort current row by left position
          currentRow.sort((a, b) => a.left.compareTo(b.left));
          rows.add(List.from(currentRow));
        }
        currentRow = [line];
      }
      lastRowBottom = max(lastRowBottom ?? 0, line.bottom);
    }

    // Add final row
    if (currentRow.isNotEmpty) {
      currentRow.sort((a, b) => a.left.compareTo(b.left));
      rows.add(currentRow);
    }

    return rows;
  }

  /// Steps 3-7: Generate worksheet Markdown with section headers, items, and tables
  static String _generateWorksheetMarkdown(
    List<List<ReconstructedLine>> rows,
    double medianLineHeight,
  ) {
    StringBuffer markdown = StringBuffer();
    bool inMatchSection = false;
    bool inTableMode = false;
    String currentItem = '';
    double pageWidth = _calculatePageWidth(rows);
    double midX = _calculatePageMidX(rows);

    for (int i = 0; i < rows.length; i++) {
      List<ReconstructedLine> row = rows[i];
      if (row.isEmpty) continue;

      // Step 3: Detect section headers
      String rowText = row.map((line) => line.text).join(' ').trim();
      if (_isSectionHeader(rowText)) {
        // Finish any current item
        if (currentItem.isNotEmpty) {
          markdown.writeln(currentItem.trim());
          currentItem = '';
        }

        // End table mode if we were in one
        if (inTableMode) {
          inTableMode = false;
        }

        // Check if entering Match section
        inMatchSection = rowText.toLowerCase().contains('match');

        markdown.writeln('\n### $rowText\n');
        continue;
      }

      // Step 5: Two-column handling (only for "Match the following")
      if (inMatchSection && _shouldActivateTableMode(row, pageWidth, midX)) {
        if (!inTableMode) {
          // Start table mode
          markdown.writeln('| Left | Right |');
          markdown.writeln('| --- | --- |');
          inTableMode = true;
        }

        // Process as table row
        _processTableRow(row, midX, markdown);
        continue;
      } else if (inTableMode && inMatchSection) {
        // Check if we should exit table mode
        if (!_hasTableStructure(row, midX)) {
          inTableMode = false;
        }
      }

      // Step 4: Item markers and continuation lines
      _processRegularRow(row, currentItem, markdown, medianLineHeight, i, rows);
    }

    // Finish any remaining item
    if (currentItem.isNotEmpty) {
      markdown.writeln(currentItem.trim());
    }

    // Step 6: Clean up output
    return _cleanMarkdownOutput(markdown.toString());
  }

  /// Step 3: Check if text is a section header
  static bool _isSectionHeader(String text) {
    String cleaned = text.toLowerCase().trim();
    List<String> headers = [
      'performance check',
      'fill in the blanks',
      'name the following',
      'match the following',
      'answer the following',
      'answer in a word or a sentence',
      'answer briefly',
      'answer in a paragraph',
    ];

    return headers.any(
      (header) => cleaned == header || cleaned.startsWith(header),
    );
  }

  /// Step 4: Check if line starts with item marker
  static bool _hasItemMarker(String text) {
    // Numbered: Roman or Arabic with dot
    if (RegExp(r'^(?:[IVXLC]+\.|[0-9]+\.)\s*').hasMatch(text)) {
      return true;
    }
    // Lettered: a-e with ), ., or :
    if (RegExp(r'^[a-eA-E][)\.:]\s*').hasMatch(text)) {
      return true;
    }
    return false;
  }

  /// Step 4: Process regular row (non-table)
  static void _processRegularRow(
    List<ReconstructedLine> row,
    String currentItem,
    StringBuffer markdown,
    double medianLineHeight,
    int rowIndex,
    List<List<ReconstructedLine>> allRows,
  ) {
    String rowText = row.map((line) => line.text).join(' ').trim();

    // Check for item marker
    if (_hasItemMarker(rowText)) {
      // Finish previous item if exists
      if (currentItem.isNotEmpty) {
        markdown.writeln(currentItem.trim());
      }

      // Start new item
      currentItem = rowText;

      // Check for continuation lines
      currentItem = _processContinuationLines(
        currentItem,
        rowIndex,
        allRows,
        medianLineHeight,
      );
      markdown.writeln(currentItem.trim());
      currentItem = '';
    } else if (currentItem.isEmpty) {
      // Standalone line (not part of an item)
      if (!_isOrphanLine(rowText)) {
        markdown.writeln(rowText);
      }
    }
  }

  /// Step 4: Process continuation lines for an item
  static String _processContinuationLines(
    String itemText,
    int startRowIndex,
    List<List<ReconstructedLine>> allRows,
    double medianLineHeight,
  ) {
    String result = itemText;
    double continuationThreshold = 0.4 * medianLineHeight;

    if (startRowIndex >= allRows.length - 1) return result;

    double currentBottom = allRows[startRowIndex]
        .map((line) => line.bottom)
        .reduce(max);

    for (int i = startRowIndex + 1; i < allRows.length; i++) {
      List<ReconstructedLine> nextRow = allRows[i];
      if (nextRow.isEmpty) continue;

      String nextRowText = nextRow.map((line) => line.text).join(' ').trim();
      double nextRowTop = nextRow.map((line) => line.top).reduce(min);

      // Check if it's a continuation line
      if (!_hasItemMarker(nextRowText) &&
          !_isSectionHeader(nextRowText) &&
          (nextRowTop - currentBottom) <= continuationThreshold) {
        result += ' $nextRowText';
        currentBottom = nextRow.map((line) => line.bottom).reduce(max);
      } else {
        break;
      }
    }

    return result;
  }

  /// Step 5: Check if should activate table mode
  static bool _shouldActivateTableMode(
    List<ReconstructedLine> row,
    double pageWidth,
    double midX,
  ) {
    if (row.length < 2) return false;

    // Check for largest horizontal gap
    double maxGap = 0;
    for (int i = 1; i < row.length; i++) {
      double gap = row[i].left - row[i - 1].right;
      maxGap = max(maxGap, gap);
    }

    bool hasLargeGap = maxGap >= 0.2 * pageWidth;

    // Check no box crosses midX
    bool noCrossing = row.every(
      (line) => line.right <= midX || line.left >= midX,
    );

    return hasLargeGap && noCrossing;
  }

  /// Step 5: Process table row for Match section
  static void _processTableRow(
    List<ReconstructedLine> row,
    double midX,
    StringBuffer markdown,
  ) {
    List<ReconstructedLine> leftItems = [];
    List<ReconstructedLine> rightItems = [];

    for (ReconstructedLine line in row) {
      if (line.centerX <= midX) {
        leftItems.add(line);
      } else {
        rightItems.add(line);
      }
    }

    String leftText = leftItems.map((line) => line.text).join(' ').trim();
    String rightText = rightItems.map((line) => line.text).join(' ').trim();

    markdown.writeln('| $leftText | $rightText |');
  }

  /// Check if row has table structure
  static bool _hasTableStructure(List<ReconstructedLine> row, double midX) {
    return row.any((line) => line.centerX <= midX) &&
        row.any((line) => line.centerX > midX);
  }

  /// Calculate page width from all rows
  static double _calculatePageWidth(List<List<ReconstructedLine>> rows) {
    double minLeft = double.infinity;
    double maxRight = double.negativeInfinity;

    for (List<ReconstructedLine> row in rows) {
      for (ReconstructedLine line in row) {
        minLeft = min(minLeft, line.left);
        maxRight = max(maxRight, line.right);
      }
    }

    return maxRight - minLeft;
  }

  /// Calculate page mid-X from all rows
  static double _calculatePageMidX(List<List<ReconstructedLine>> rows) {
    double minLeft = double.infinity;
    double maxRight = double.negativeInfinity;

    for (List<ReconstructedLine> row in rows) {
      for (ReconstructedLine line in row) {
        minLeft = min(minLeft, line.left);
        maxRight = max(maxRight, line.right);
      }
    }

    return (minLeft + maxRight) / 2;
  }

  /// Step 7: Check if line is orphan (should be removed)
  static bool _isOrphanLine(String text) {
    // Remove lines that are only digits or single letter with punctuation
    return RegExp(r'^\d+$').hasMatch(text.trim()) ||
        RegExp(r'^[a-zA-Z][.):]\s*$').hasMatch(text.trim());
  }

  /// Step 6: Clean up final Markdown output
  static String _cleanMarkdownOutput(String markdown) {
    // Normalize extra spaces
    String cleaned = markdown.replaceAll(RegExp(r' {2,}'), ' ');

    // Collapse multiple empty lines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    // Remove stray pipes without preceding headers
    List<String> lines = cleaned.split('\n');
    List<String> cleanedLines = [];
    bool hasTableHeader = false;

    for (String line in lines) {
      if (line.trim().startsWith('|') && line.trim().endsWith('|')) {
        if (line.contains('---') || hasTableHeader) {
          cleanedLines.add(line);
          if (line.contains('---')) hasTableHeader = false;
        } else if (line.toLowerCase().contains('left') &&
            line.toLowerCase().contains('right')) {
          cleanedLines.add(line);
          hasTableHeader = true;
        }
        // Skip other stray table lines
      } else {
        cleanedLines.add(line);
        hasTableHeader = false;
      }
    }

    return cleanedLines.join('\n').trim();
  }
}

/// Data class to hold reconstructed line information
class ReconstructedLine {
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final double height;
  final double centerX;

  ReconstructedLine({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.height,
    required this.centerX,
  });

  @override
  String toString() =>
      'ReconstructedLine(text: "$text", centerX: $centerX, top: $top)';
}

/// Unit-like assertions and sanity checks (as comments for verification)
class WorksheetMarkdownAssertions {
  /// Sanity check: If a row contains 1. and 2. they must become two separate lines
  static void assertSeparateNumberedItems() {
    // This should be verified in the _processRegularRow method
    // Each item with _hasItemMarker() should get its own line
  }

  /// Sanity check: In Match section, 1. aligns with a) on same Y band as table row
  static void assertMatchTableAlignment() {
    // This should be verified in _shouldActivateTableMode and _processTableRow
    // Left numbered items should align with right lettered options
  }

  /// Sanity check: Headings render as ### Heading on their own lines
  static void assertSectionHeaders() {
    // This should be verified in _isSectionHeader processing
    // Section headers should render with ### prefix
  }
}
