import 'package:document_model/document_model.dart';
import 'package:flutter/rendering.dart';

import 'document_painter.dart';

/// Paints one page scaled to fill the painter's size — for page strips,
/// home-screen cards and other previews. Content is clipped to the page.
///
/// Give it a box with the page's aspect ratio (see [DesignPage.width] /
/// [DesignPage.height]); otherwise the page is centred and letterboxed.
class PageThumbnailPainter extends CustomPainter {
  PageThumbnailPainter({required this.document, required this.page});

  final DesignDocument document;
  final DesignPage page;

  @override
  void paint(Canvas canvas, Size size) {
    if (page.width <= 0 || page.height <= 0 || size.isEmpty) return;
    final scale =
        (size.width / page.width) < (size.height / page.height)
            ? size.width / page.width
            : size.height / page.height;
    final dx = (size.width - page.width * scale) / 2;
    final dy = (size.height - page.height * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale)
      ..clipRect(Rect.fromLTWH(0, 0, page.width, page.height));
    paintPageBackground(canvas, page);
    paintPageContent(canvas, document, page);
    canvas.restore();
  }

  @override
  bool shouldRepaint(PageThumbnailPainter oldDelegate) =>
      !identical(oldDelegate.document, document) || oldDelegate.page != page;
}
