import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:math';

/// Advanced OCR helper that preserves worksheet layout and outputs proper Markdown
class WorksheetOcrHelper {
  /// Main entry point: converts TextRecognitionResult to Markdown
  static String processToMarkdown(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return "No text found in the image";
    }

    // Step 1: Extract all text lines with their positions
    List<TextLineData> allLines = _extractTextLines(recognizedText);

    if (allLines.isEmpty) {
      return "No text elements found in the image";
    }

    // Step 2: Sort lines by top then left
    allLines.sort((a, b) {
      int topComparison = a.top.compareTo(b.top);
      if (topComparison == 0) {
        return a.left.compareTo(b.left);
      }
      return topComparison;
    });

    // Step 3: Group lines into rows based on Y-gap and median line height
    double medianLineHeight = _calculateMedianLineHeight(allLines);
    List<List<TextLineData>> rows = _groupLinesIntoRows(
      allLines,
      medianLineHeight,
    );

    // Step 4: Process each row for column detection and Markdown output
    return _generateMarkdown(rows);
  }

  /// Extract text lines with position data
  static List<TextLineData> _extractTextLines(RecognizedText recognizedText) {
    List<TextLineData> lines = [];

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
          lines.add(
            TextLineData(
              text: lineText,
              left: line.boundingBox.left.toDouble(),
              top: line.boundingBox.top.toDouble(),
              right: line.boundingBox.right.toDouble(),
              bottom: line.boundingBox.bottom.toDouble(),
              height: (line.boundingBox.bottom - line.boundingBox.top)
                  .toDouble(),
            ),
          );
        }
      }
    }

    return lines;
  }

  /// Calculate median line height for grouping threshold
  static double _calculateMedianLineHeight(List<TextLineData> lines) {
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

  /// Group lines into rows based on Y-gap relative to median line height
  static List<List<TextLineData>> _groupLinesIntoRows(
    List<TextLineData> lines,
    double medianLineHeight,
  ) {
    List<List<TextLineData>> rows = [];
    List<TextLineData> currentRow = [];
    double? lastRowBottom;

    double gapThreshold = 0.6 * medianLineHeight;

    for (TextLineData line in lines) {
      bool shouldStartNewRow = false;

      // Always start new row for numbered/bulleted items
      if (_isNumberedItem(line.text)) {
        shouldStartNewRow = true;
      }
      // Normal gap-based grouping for non-numbered items
      else if (lastRowBottom != null &&
          (line.top - lastRowBottom) > gapThreshold) {
        shouldStartNewRow = true;
      }

      if (shouldStartNewRow && currentRow.isNotEmpty) {
        // Sort current row by left position
        currentRow.sort((a, b) => a.left.compareTo(b.left));
        rows.add(List.from(currentRow));
        currentRow = [];
      }

      currentRow.add(line);
      lastRowBottom = max(lastRowBottom ?? 0, line.bottom);
    }

    // Add final row
    if (currentRow.isNotEmpty) {
      currentRow.sort((a, b) => a.left.compareTo(b.left));
      rows.add(currentRow);
    }

    // Process rows to split any that contain multiple numbered items
    return _splitMixedNumberedRows(rows);
  }

  /// Split rows that contain multiple numbered items into separate rows
  static List<List<TextLineData>> _splitMixedNumberedRows(
    List<List<TextLineData>> rows,
  ) {
    List<List<TextLineData>> splitRows = [];

    for (List<TextLineData> row in rows) {
      if (row.length <= 1) {
        splitRows.add(row);
        continue;
      }

      // Check if this row contains multiple numbered items
      List<TextLineData> numberedItems = row
          .where((line) => _isNumberedItem(line.text))
          .toList();

      if (numberedItems.length > 1) {
        // Split each numbered item into its own row
        for (TextLineData numberedItem in numberedItems) {
          splitRows.add([numberedItem]);
        }

        // Add non-numbered items as a separate row if any exist
        List<TextLineData> nonNumberedItems = row
            .where((line) => !_isNumberedItem(line.text))
            .toList();
        if (nonNumberedItems.isNotEmpty) {
          splitRows.add(nonNumberedItems);
        }
      } else {
        // Normal row with at most one numbered item
        splitRows.add(row);
      }
    }

    return splitRows;
  }

  /// Generate Markdown from processed rows
  static String _generateMarkdown(List<List<TextLineData>> rows) {
    StringBuffer markdown = StringBuffer();
    bool inTable = false;

    for (List<TextLineData> row in rows) {
      if (row.isEmpty) continue;

      // Check if this row contains numbered items - always treat as single column
      bool hasNumberedItems = row.any((line) => _isNumberedItem(line.text));

      if (hasNumberedItems) {
        // Numbered items always get their own line, no table formatting
        inTable = false;
        for (TextLineData line in row) {
          String lineText = _cleanText(line.text);
          if (_isNumberedItem(lineText)) {
            // Preserve numbering as separate lines
            markdown.writeln(lineText);
          } else if (lineText.isNotEmpty) {
            // Non-numbered content in the same row
            markdown.writeln(lineText);
          }
        }
      } else {
        // Detect if this row has columns (only for non-numbered content)
        List<List<TextLineData>> columns = _detectRowColumns(row);

        if (columns.length > 1) {
          // Multi-column row - create table
          if (!inTable) {
            // First table row - add header separator
            markdown.writeln('| ${columns.map((_) => '---').join(' | ')} |');
            inTable = true;
          }

          markdown.write('| ');
          for (List<TextLineData> column in columns) {
            String columnText = column
                .map((line) => line.text)
                .join(' ')
                .trim();
            columnText = _cleanText(columnText);
            markdown.write('$columnText | ');
          }
          markdown.writeln();
        } else {
          // Single column row
          inTable = false;
          String rowText = row.map((line) => line.text).join(' ').trim();
          rowText = _cleanText(rowText);

          if (_isSectionHeader(rowText)) {
            // Section headers
            markdown.writeln('\n### $rowText\n');
          } else {
            // Regular text
            markdown.writeln(rowText);
          }
        }
      }
    }

    return markdown.toString().trim();
  }

  /// Detect columns in a row based on horizontal gaps and page positioning
  static List<List<TextLineData>> _detectRowColumns(List<TextLineData> row) {
    if (row.length <= 1) return [row];

    // Calculate page width and mid-point
    double leftMost = row.map((line) => line.left).reduce(min);
    double rightMost = row.map((line) => line.right).reduce(max);
    double pageWidth = rightMost - leftMost;
    double midX = leftMost + (pageWidth / 2);

    // Check for big horizontal gap (≥ 20px)
    List<List<TextLineData>> columns = [];
    List<TextLineData> currentColumn = [row.first];

    for (int i = 1; i < row.length; i++) {
      TextLineData current = row[i];
      TextLineData previous = row[i - 1];

      double gap = current.left - previous.right;

      if (gap >= 20.0) {
        // Big gap found - start new column
        columns.add(List.from(currentColumn));
        currentColumn = [current];
      } else {
        currentColumn.add(current);
      }
    }

    // Add final column
    columns.add(currentColumn);

    // Check for text clustering on both sides of page mid-X
    if (columns.length == 1) {
      List<TextLineData> leftSide = [];
      List<TextLineData> rightSide = [];

      for (TextLineData line in row) {
        if (line.right < midX) {
          leftSide.add(line);
        } else if (line.left > midX) {
          rightSide.add(line);
        } else {
          // Line spans across middle - keep in single column
          return [row];
        }
      }

      if (leftSide.isNotEmpty && rightSide.isNotEmpty) {
        return [leftSide, rightSide];
      }
    }

    return columns.length > 1 ? columns : [row];
  }

  /// Clean text by collapsing stray spaces
  static String _cleanText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Check if text is a numbered item (1., 2., I., II., a.), etc.)
  static bool _isNumberedItem(String text) {
    return RegExp(
      r'^\s*([0-9]+[\.\)]|[IVXivx]+[\.\)]|[a-zA-Z][\.\)]|\([0-9]+\)|\([a-zA-Z]\)|•|‣|▪|▫|◦|∙)',
    ).hasMatch(text);
  }

  /// Check if text is a section header
  static bool _isSectionHeader(String text) {
    String cleaned = text.toLowerCase().trim();
    return cleaned.contains('fill in') ||
        cleaned.contains('match') ||
        cleaned.contains('answer') ||
        cleaned.contains('question') ||
        cleaned.startsWith('###') ||
        text.length < 50 && text.endsWith(':');
  }
}

/// Data class to hold text line information
class TextLineData {
  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;
  final double height;

  TextLineData({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.height,
  });

  @override
  String toString() => 'TextLineData(text: "$text", left: $left, top: $top)';
}
