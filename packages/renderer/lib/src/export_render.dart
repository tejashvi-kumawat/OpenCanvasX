import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:document_model/document_model.dart';

import 'document_painter.dart';
import 'media_cache.dart';

/// Renders [region] (page units) of [page] into a [width] × [height]
/// image for export (P1.9.1): [roots] are drawn with their parents'
/// transforms; the page background is drawn when [background] is set
/// (boards fill the region with their colour). Wait for
/// [MediaCache.preload] first so images are not placeholders.
Future<ui.Image> renderRegion(
  DesignDocument document,
  DesignPage page, {
  required Rect2D region,
  required List<ObjectId> roots,
  required bool background,
  required int width,
  required int height,
  MediaCache? media,
}) {
  final recorder = ui.PictureRecorder();
  final canvas =
      ui.Canvas(recorder)
        ..scale(width / region.width, height / region.height)
        ..translate(-region.left, -region.top)
        ..clipRect(
          ui.Rect.fromLTWH(
            region.left,
            region.top,
            region.width,
            region.height,
          ),
        );
  if (background) {
    if (page.isBoard) {
      if (page.background case SolidBackground(:final color)) {
        canvas.drawRect(
          ui.Rect.fromLTWH(
            region.left,
            region.top,
            region.width,
            region.height,
          ),
          ui.Paint()..color = toUiColor(color),
        );
      }
    } else {
      paintPageBackground(canvas, page);
    }
  }
  for (final id in roots) {
    final object = document.objects[id];
    if (object == null) continue;
    canvas
      ..save()
      ..transform(toUiMatrix(_parentMatrix(document, object)));
    paintObject(canvas, document, object, media: media);
    canvas.restore();
  }
  return recorder.endRecording().toImage(width, height);
}

/// Straight RGBA bytes of [image].
Future<Uint8List> imageRgba(ui.Image image) async {
  final data = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return data!.buffer.asUint8List();
}

/// PNG bytes of [image].
Future<Uint8List> imagePng(ui.Image image) async {
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// The lines a text object shows on the canvas, using the same layout as
/// drawing (so SVG export wraps where the canvas wraps).
List<String> textLines(DesignObject object) {
  final payload = object.payload;
  if (payload is! TextPayload) return const [];
  if (payload.text.isEmpty) return const [''];
  final paragraph = layoutText(
    payload,
    width:
        payload.sizing == TextSizing.autoWidth ? null : object.transform.width,
  );
  final lines = <String>[];
  var offset = 0;
  final text = payload.text;
  while (offset < text.length) {
    final range = paragraph.getLineBoundary(ui.TextPosition(offset: offset));
    if (range.end <= offset) break;
    lines.add(text.substring(range.start, range.end).replaceAll('\n', ''));
    offset = range.end;
    // Skip the newline that ended this line.
    if (offset < text.length && text[offset] == '\n') offset++;
  }
  // A trailing newline starts an empty last line.
  if (text.endsWith('\n')) lines.add('');
  paragraph.dispose();
  return lines;
}

Affine2D _parentMatrix(DesignDocument document, DesignObject object) {
  var matrix = Affine2D.identity;
  var parentId = object.parentId;
  var guard = 0;
  while (parentId != null && guard++ < 64) {
    final parent = document.objects[parentId];
    if (parent == null) break;
    matrix = localToParent(parent.transform) * matrix;
    parentId = parent.parentId;
  }
  return matrix;
}
