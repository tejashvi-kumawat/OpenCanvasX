import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';

/// Straight (non-premultiplied) RGBA pixels as produced by
/// `ui.Image.toByteData(format: rawStraightRgba)`.
typedef RgbaPixels = ({Uint8List rgba, int width, int height});

/// JPEG (P1.9.2). JPEG has no transparency, so pixels are composited over
/// [background] (opaque white by default). [quality] is 1–100.
Uint8List encodeJpeg(
  RgbaPixels pixels, {
  int quality = 90,
  int background = 0xFFFFFFFF,
}) {
  final image = _flatten(pixels, background);
  return img.encodeJpg(image, quality: quality.clamp(1, 100));
}

/// WebP is not encodable in pure Dart; PNG is used for lossless export.
Uint8List encodePng(RgbaPixels pixels) {
  final image = img.Image.fromBytes(
    width: pixels.width,
    height: pixels.height,
    bytes: pixels.rgba.buffer,
    bytesOffset: pixels.rgba.offsetInBytes,
    numChannels: 4,
  );
  return img.encodePng(image);
}

img.Image _flatten(RgbaPixels pixels, int background) {
  final out = img.Image(width: pixels.width, height: pixels.height);
  final br = (background >> 16) & 0xFF;
  final bg = (background >> 8) & 0xFF;
  final bb = background & 0xFF;
  final src = pixels.rgba;
  var i = 0;
  for (var y = 0; y < pixels.height; y++) {
    for (var x = 0; x < pixels.width; x++, i += 4) {
      final a = src[i + 3];
      out.setPixelRgb(
        x,
        y,
        (src[i] * a + br * (255 - a)) ~/ 255,
        (src[i + 1] * a + bg * (255 - a)) ~/ 255,
        (src[i + 2] * a + bb * (255 - a)) ~/ 255,
      );
    }
  }
  return out;
}

/// One page of a PDF: its size in points and a rendered image of it.
typedef PdfPageImage = ({double widthPt, double heightPt, RgbaPixels pixels});

/// A multi-page PDF (P1.9.4) whose pages have the design's physical size,
/// each carrying its rendering at the export resolution. Title, author
/// and creator go into the document information.
Future<Uint8List> encodeRasterPdf(
  List<PdfPageImage> pages, {
  String? title,
  String? author,
}) async {
  final pdf = PdfDocument();
  PdfInfo(
    pdf,
    title: title,
    author: author,
    creator: 'OpenCanvasX',
    producer: 'OpenCanvasX',
  );
  for (final page in pages) {
    final format = PdfPageFormat(page.widthPt, page.heightPt);
    final pdfPage = PdfPage(pdf, pageFormat: format);
    final flattened = _flatten(page.pixels, 0xFFFFFFFF);
    final image = PdfImage(
      pdf,
      image: flattened.getBytes(order: img.ChannelOrder.rgba),
      width: flattened.width,
      height: flattened.height,
      alpha: false,
    );
    pdfPage.getGraphics().drawImage(image, 0, 0, page.widthPt, page.heightPt);
  }
  return Uint8List.fromList(await pdf.save());
}
