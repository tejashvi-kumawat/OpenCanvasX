import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// One page of a vector PDF: the page's SVG (from `exportSvg`) and its
/// physical size in points.
typedef VectorPdfPage = ({String svg, double widthPt, double heightPt});

/// TrueType/OpenType bytes for a family, weight (100–900) and style, or
/// `null` to fall back to the built-in Helvetica.
typedef PdfFontLookup =
    Uint8List? Function(
      String family, {
      required int weight,
      required bool italic,
    });

/// A vector PDF (P1.9.4): shapes, paths, gradients and clipping stay
/// vectors and text stays selectable text in embedded fonts, as far as the
/// `pdf` package's SVG support goes (no SVG filters: callers pass images
/// that need them pre-rendered). Pages have the design's physical size.
/// Text without a family uses [defaultFamily] (the canvas's UI font).
Future<Uint8List> encodeVectorPdf(
  List<VectorPdfPage> pages, {
  String? title,
  String? author,
  PdfFontLookup? fonts,
  String? defaultFamily,
}) async {
  final doc = pw.Document(
    title: title,
    author: author,
    creator: 'OpenCanvasX',
    producer: 'OpenCanvasX',
  );
  final cache = <String, pw.Font?>{};

  pw.Font? lookup(String family, String style, String weight) {
    final name = firstFontFamily(family) ?? defaultFamily;
    if (name == null || fonts == null) return null;
    final w = parseFontWeight(weight);
    final italic = style == 'italic' || style == 'oblique';
    final key = '$name|$w|$italic';
    return cache.putIfAbsent(key, () {
      final bytes = fonts(name, weight: w, italic: italic);
      if (bytes == null) return null;
      try {
        return pw.Font.ttf(ByteData.sublistView(bytes));
      } on Object {
        return null; // Not a font the PDF writer can embed.
      }
    });
  }

  for (final page in pages) {
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(page.widthPt, page.heightPt),
        build:
            (_) => pw.SvgImage(
              svg: page.svg,
              fit: pw.BoxFit.fill,
              customFontLookup: lookup,
            ),
      ),
    );
  }
  return doc.save();
}

/// The first family in a CSS `font-family` list, without quotes, or
/// `null` for generic families only.
String? firstFontFamily(String list) {
  for (final part in list.split(',')) {
    final name = part.trim().replaceAll(RegExp('^["\']|["\']\$'), '').trim();
    if (name.isEmpty) continue;
    const generic = {
      'serif',
      'sans-serif',
      'monospace',
      'cursive',
      'fantasy',
      'system-ui',
    };
    if (generic.contains(name.toLowerCase())) continue;
    return name;
  }
  return null;
}

/// CSS font-weight to 100–900.
int parseFontWeight(String weight) => switch (weight.trim().toLowerCase()) {
  'bold' || 'bolder' => 700,
  'normal' || '' => 400,
  'lighter' => 300,
  final w => (int.tryParse(w) ?? 400).clamp(100, 900),
};
