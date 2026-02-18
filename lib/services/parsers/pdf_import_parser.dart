import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../features/portfolio/domain/entities/portfolio_entities.dart';
import 'base_parser.dart';
import 'generic_parser.dart';
import 'parser_factory.dart';

/// Generic PDF parser that extracts tabular text and reuses CSV parsing logic.
class PdfImportParser {
  static Portfolio parse(Uint8List bytes, {String? brokerId}) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();

    final rows = _extractRows(text);
    if (rows.isEmpty) {
      throw const FormatException('Empty PDF file');
    }

    final csvContent = const ListToCsvConverter().convert(rows);

    if (brokerId != null && brokerId.trim().isNotEmpty) {
      try {
        return BrokerParserFactory.parseWithBroker(csvContent, brokerId);
      } catch (_) {
        // Fallback to generic parsing below.
      }
    } else {
      try {
        return BrokerParserFactory.autoParseCSV(csvContent);
      } catch (_) {
        // Fallback to generic parsing below.
      }
    }

    final portfolio = GenericCSVParser().parse(csvContent);
    final normalizedPositions = BaseBrokerParser.normalizeAndDeduplicatePositions(
      portfolio.positions,
    );
    return portfolio.copyWith(positions: normalizedPositions);
  }

  static List<List<String>> _extractRows(String text) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return [];
    }

    final delimiter = _detectDelimiter(lines);
    if (delimiter != null) {
      return lines
          .map((line) => line
              .split(delimiter)
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toList())
          .where((row) => row.length > 1)
          .toList();
    }

    return lines
        .map((line) => line
            .split(RegExp(r'\s{2,}|\t'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList())
        .where((row) => row.length > 1)
        .toList();
  }

  static String? _detectDelimiter(List<String> lines) {
    if (lines.any((line) => line.contains('\t'))) {
      return '\t';
    }

    int countLinesWithDelimiter(String delimiter) {
      return lines.where((line) => line.split(delimiter).length >= 3).length;
    }

    final commaLines = countLinesWithDelimiter(',');
    final semicolonLines = countLinesWithDelimiter(';');

    if (commaLines >= 2 || semicolonLines >= 2) {
      return commaLines >= semicolonLines ? ',' : ';';
    }

    return null;
  }
}
