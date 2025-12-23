import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class EnhancedOcrHelper {
  static const double COLUMN_GAP_THRESHOLD =
      100.0; // Minimum gap to consider as separate columns
  static const double LINE_HEIGHT_THRESHOLD =
      20.0; // Maximum height difference to consider as same row

  /// Enhanced OCR processing that preserves page layout and generates Markdown
  static String processOcrResult(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return "No text found in the image";
    }

    // Extract all text elements with their positions
    List<TextElement> allElements = _extractTextElements(recognizedText);

    if (allElements.isEmpty) {
      return "No text elements found in the image";
    }

    // Sort elements by position (top-to-bottom, left-to-right)
    allElements.sort((a, b) {
      int topComparison = a.boundingBox.top
          .toDouble()
          .compareTo(b.boundingBox.top.toDouble())
          .toInt();
      if (topComparison.abs() <= LINE_HEIGHT_THRESHOLD) {
        return a.boundingBox.left
            .toDouble()
            .compareTo(b.boundingBox.left.toDouble())
            .toInt();
      }
      return topComparison;
    });

    // Group elements into rows
    List<List<TextElement>> rows = _groupIntoRows(allElements);

    // Convert rows to Markdown
    return _convertToMarkdown(rows);
  }

  /// Extract all text elements with their bounding boxes
  static List<TextElement> _extractTextElements(RecognizedText recognizedText) {
    List<TextElement> elements = [];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        for (TextElement element in line.elements) {
          elements.add(element);
        }
      }
    }

    return elements;
  }

  /// Group text elements into rows based on vertical position
  static List<List<TextElement>> _groupIntoRows(List<TextElement> elements) {
    List<List<TextElement>> rows = [];
    List<TextElement> currentRow = [];
    double? currentRowTop;

    for (TextElement element in elements) {
      double elementTop = element.boundingBox.top.toDouble();

      if (currentRowTop == null ||
          (elementTop - currentRowTop).abs() <= LINE_HEIGHT_THRESHOLD) {
        // Same row
        currentRow.add(element);
        currentRowTop ??= elementTop;
      } else {
        // New row
        if (currentRow.isNotEmpty) {
          currentRow.sort(
            (a, b) => a.boundingBox.left.toDouble().compareTo(
              b.boundingBox.left.toDouble(),
            ),
          );
          rows.add(List.from(currentRow));
        }
        currentRow = [element];
        currentRowTop = elementTop;
      }
    }

    // Add the last row
    if (currentRow.isNotEmpty) {
      currentRow.sort(
        (a, b) => a.boundingBox.left.toDouble().compareTo(
          b.boundingBox.left.toDouble(),
        ),
      );
      rows.add(currentRow);
    }

    return rows;
  }

  /// Convert rows to Markdown format
  static String _convertToMarkdown(List<List<TextElement>> rows) {
    StringBuffer markdown = StringBuffer();

    for (List<TextElement> row in rows) {
      if (row.isEmpty) continue;

      // Check if this row has multiple columns (significant gap between elements)
      List<List<TextElement>> columns = _detectColumns(row);

      if (columns.length > 1) {
        // Multiple columns - create table row
        markdown.write('| ');
        for (List<TextElement> column in columns) {
          String columnText = column.map((e) => e.text).join(' ').trim();
          markdown.write('$columnText | ');
        }
        markdown.writeln();

        // Add table header separator if this is the first table row
        if (!markdown.toString().contains('|---')) {
          markdown.write('| ');
          for (int i = 0; i < columns.length; i++) {
            markdown.write('--- | ');
          }
          markdown.writeln();
        }
      } else {
        // Single column - plain text
        String lineText = row.map((e) => e.text).join(' ').trim();

        // Preserve numbering and formatting
        if (_isNumberedItem(lineText)) {
          markdown.writeln(lineText);
        } else if (_isSectionHeader(lineText)) {
          markdown.writeln('\n### $lineText\n');
        } else {
          markdown.writeln(lineText);
        }
      }
    }

    return markdown.toString().trim();
  }

  /// Detect columns in a row based on horizontal gaps
  static List<List<TextElement>> _detectColumns(List<TextElement> row) {
    if (row.length <= 1) return [row];

    List<List<TextElement>> columns = [];
    List<TextElement> currentColumn = [row.first];

    for (int i = 1; i < row.length; i++) {
      TextElement current = row[i];
      TextElement previous = row[i - 1];

      double gap =
          current.boundingBox.left.toDouble() -
          previous.boundingBox.right.toDouble();

      if (gap > COLUMN_GAP_THRESHOLD) {
        // Start new column
        columns.add(List.from(currentColumn));
        currentColumn = [current];
      } else {
        // Same column
        currentColumn.add(current);
      }
    }

    // Add the last column
    columns.add(currentColumn);

    return columns;
  }

  /// Check if text is a numbered item
  static bool _isNumberedItem(String text) {
    return RegExp(r'^\s*\d+\.').hasMatch(text) ||
        RegExp(r'^\s*[a-zA-Z]\)').hasMatch(text) ||
        RegExp(r'^\s*[ivxlcdm]+\.', caseSensitive: false).hasMatch(text);
  }

  /// Check if text is a section header
  static bool _isSectionHeader(String text) {
    String lower = text.toLowerCase();
    return lower.contains('match') ||
        lower.contains('fill') ||
        lower.contains('complete') ||
        lower.contains('question') ||
        text.length < 50 && text.endsWith(':');
  }

  /// Alternative method: Simple line-by-line preservation
  static String processOcrSimple(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return "No text found in the image";
    }

    List<TextLine> allLines = [];

    // Collect all lines from all blocks
    for (TextBlock block in recognizedText.blocks) {
      allLines.addAll(block.lines);
    }

    // Sort lines by position (top-to-bottom, left-to-right)
    allLines.sort((a, b) {
      int topComparison = a.boundingBox.top
          .toDouble()
          .compareTo(b.boundingBox.top.toDouble())
          .toInt();
      if (topComparison.abs() <= LINE_HEIGHT_THRESHOLD) {
        return a.boundingBox.left
            .toDouble()
            .compareTo(b.boundingBox.left.toDouble())
            .toInt();
      }
      return topComparison;
    });

    // Group lines that are on the same horizontal level
    List<List<TextLine>> groupedLines = [];
    List<TextLine> currentGroup = [];
    double? currentTop;

    for (TextLine line in allLines) {
      double lineTop = line.boundingBox.top.toDouble();

      if (currentTop == null ||
          (lineTop - currentTop).abs() <= LINE_HEIGHT_THRESHOLD) {
        currentGroup.add(line);
        currentTop ??= lineTop;
      } else {
        if (currentGroup.isNotEmpty) {
          currentGroup.sort(
            (a, b) => a.boundingBox.left
                .toDouble()
                .compareTo(b.boundingBox.left.toDouble())
                .toInt(),
          );
          groupedLines.add(List.from(currentGroup));
        }
        currentGroup = [line];
        currentTop = lineTop;
      }
    }

    // Add the last group
    if (currentGroup.isNotEmpty) {
      currentGroup.sort(
        (a, b) => a.boundingBox.left
            .toDouble()
            .compareTo(b.boundingBox.left.toDouble())
            .toInt(),
      );
      groupedLines.add(currentGroup);
    }

    // Convert to text
    StringBuffer result = StringBuffer();
    for (List<TextLine> group in groupedLines) {
      if (group.length == 1) {
        result.writeln(group.first.text);
      } else {
        // Multiple lines on same level - check for columns
        double firstLineRight = group.first.boundingBox.right.toDouble();
        bool hasColumnGap = false;

        for (int i = 1; i < group.length; i++) {
          double gap = group[i].boundingBox.left - firstLineRight;
          if (gap > COLUMN_GAP_THRESHOLD) {
            hasColumnGap = true;
            break;
          }
        }

        if (hasColumnGap) {
          // Format as columns
          result.write(group.map((line) => line.text.padRight(30)).join(' | '));
          result.writeln();
        } else {
          // Same line
          result.writeln(group.map((line) => line.text).join(' '));
        }
      }
    }

    return result.toString().trim();
  }

  /// Generate HTML table format
  static String processOcrToHtml(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return "<p>No text found in the image</p>";
    }

    List<TextElement> allElements = _extractTextElements(recognizedText);
    if (allElements.isEmpty) {
      return "<p>No text elements found in the image</p>";
    }

    allElements.sort((a, b) {
      int topComparison = a.boundingBox.top.compareTo(b.boundingBox.top);
      if (topComparison.abs() <= LINE_HEIGHT_THRESHOLD) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return topComparison;
    });

    List<List<TextElement>> rows = _groupIntoRows(allElements);

    StringBuffer html = StringBuffer();
    html.writeln('<table border="1" cellpadding="5" cellspacing="0">');

    for (List<TextElement> row in rows) {
      if (row.isEmpty) continue;

      List<List<TextElement>> columns = _detectColumns(row);

      if (columns.length > 1) {
        html.writeln('  <tr>');
        for (List<TextElement> column in columns) {
          String columnText = column.map((e) => e.text).join(' ').trim();
          html.writeln('    <td>$columnText</td>');
        }
        html.writeln('  </tr>');
      } else {
        String lineText = row.map((e) => e.text).join(' ').trim();
        html.writeln('  <tr><td colspan="2">$lineText</td></tr>');
      }
    }

    html.writeln('</table>');
    return html.toString();
  }
}
