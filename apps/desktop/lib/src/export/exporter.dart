import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:document_model/document_model.dart';
import 'package:export_engine/export_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

/// Output formats (P1.9).
enum ExportFormat {
  png('PNG', 'png', 'Best for web and social; supports transparency'),
  jpg('JPG', 'jpg', 'Smallest files for photos; no transparency'),
  webp('WebP', 'webp', 'Small files for the web, with transparency'),
  svg('SVG', 'svg', 'Scalable vectors for the web and other design tools'),
  pdf('PDF', 'pdf', 'One document with every page, at print size'),
  html(
    'Website',
    'html',
    'A small website: one page per frame or page; prototype links work',
  );

  const ExportFormat(this.label, this.extension, this.hint);

  final String label;
  final String extension;
  final String hint;

  bool get isRaster =>
      this == png || this == jpg || this == webp || this == pdf;
  bool get isVector => this == svg || this == html;
  bool get supportsTransparency => this == png || this == webp || this == svg;

  /// Whether the quality slider applies.
  bool get hasQuality => this == jpg || this == webp;
}

/// Everything the user chose in the export dialog.
class ExportOptions {
  const ExportOptions({
    this.format = ExportFormat.png,
    this.scope = ExportScope.currentPage,
    this.scale = 2,
    this.transparent = false,
    this.jpegQuality = 90,
    this.vectorPdf = true,
  });

  final ExportFormat format;
  final ExportScope scope;

  /// Pixel multiplier for raster output (PDF: 1 ≈ 96 dpi, 3 ≈ 300 dpi).
  final double scale;
  final bool transparent;
  final int jpegQuality;

  /// PDF as vectors with real text (P1.9.4) instead of page images.
  final bool vectorPdf;

  ExportOptions copyWith({
    ExportFormat? format,
    ExportScope? scope,
    double? scale,
    bool? transparent,
    int? jpegQuality,
    bool? vectorPdf,
  }) => ExportOptions(
    format: format ?? this.format,
    scope: scope ?? this.scope,
    scale: scale ?? this.scale,
    transparent: transparent ?? this.transparent,
    jpegQuality: jpegQuality ?? this.jpegQuality,
    vectorPdf: vectorPdf ?? this.vectorPdf,
  );
}

/// A finished file to write.
typedef ExportedFile = ({String name, Uint8List bytes});

/// Largest side of an exported raster, in pixels.
const int maxExportSide = 16384;

/// Writes exported files and returns where they went (or `null` if the
/// user cancelled). Tests replace it.
typedef ExportSaver =
    Future<String?> Function(List<ExportedFile> files, ExportFormat format);

final exportSaverProvider = Provider<ExportSaver>((ref) => _saveWithDialogs);

Future<String?> _saveWithDialogs(
  List<ExportedFile> files,
  ExportFormat format,
) async {
  if (files.length == 1) {
    final location = await getSaveLocation(
      suggestedName: files.single.name,
      acceptedTypeGroups: [
        XTypeGroup(label: format.label, extensions: [format.extension]),
      ],
      confirmButtonText: 'Export',
    );
    if (location == null) return null;
    var path = location.path;
    if (!path.toLowerCase().endsWith('.${format.extension}')) {
      path = '$path.${format.extension}';
    }
    await File(path).writeAsBytes(files.single.bytes, flush: true);
    return path;
  }
  final folder = await getDirectoryPath(confirmButtonText: 'Export here');
  if (folder == null) return null;
  final used = <String>{};
  for (final file in files) {
    var name = file.name;
    final dot = name.lastIndexOf('.');
    for (
      var n = 2;
      used.contains(name.toLowerCase()) ||
          File('$folder${Platform.pathSeparator}$name').existsSync();
      n++
    ) {
      name = '${file.name.substring(0, dot)} ($n)${file.name.substring(dot)}';
    }
    used.add(name.toLowerCase());
    await File(
      '$folder${Platform.pathSeparator}$name',
    ).writeAsBytes(file.bytes, flush: true);
  }
  return folder;
}

/// Font file for a family, weight and style (bundled or installed), for
/// embedding in vector PDFs; `null` when none is available.
typedef PdfFontResolver =
    Future<Uint8List?> Function(
      String family, {
      required int weight,
      required bool italic,
    });

/// Reports export progress: [done] of [total] pages rendered.
typedef ExportProgress = void Function(int done, int total);

/// Produces the files for [options] (P1.9.1–P1.9.4). Pages render on the
/// UI isolate (Flutter's canvas needs it) one at a time, yielding between
/// pages so the app stays responsive; JPEG and PDF encoding run on a
/// background isolate (P1.9.5) and PNG encoding in the engine.
Future<List<ExportedFile>> buildExport(
  DesignDocument document, {
  required ExportOptions options,
  required PageId activePage,
  required Set<ObjectId> selection,
  required MediaCache media,
  ExportProgress? onProgress,
  PdfFontResolver? pdfFonts,
}) async {
  final targets = exportTargets(
    document,
    scope: options.scope,
    activePage: activePage,
    selection: selection,
  );
  if (targets.isEmpty) return const [];

  // Decode every image first so nothing exports as a placeholder.
  await media.preload([
    for (final o in document.objects.values)
      if (o.payload case ImagePayload(:final assetHash))
        (assetHash, o.style?.fill?.representative.value),
  ]);

  final format = options.format;
  final transparent = options.transparent && format.supportsTransparency;
  if (format == ExportFormat.html) {
    final site = exportHtmlSite(
      document,
      targets,
      assets: media.allBytes,
      lines: textLines,
    );
    return [
      for (final MapEntry(key: name, value: html) in site.entries)
        (name: name, bytes: Uint8List.fromList(utf8.encode(html))),
    ];
  }

  if (format == ExportFormat.pdf && options.vectorPdf) {
    return [
      await _vectorPdf(
        document,
        targets,
        options: options,
        media: media,
        fonts: pdfFonts,
        onProgress: onProgress,
      ),
    ];
  }

  if (format == ExportFormat.svg) {
    return [
      for (final target in targets)
        (
          name: exportFileName(target.name, 'svg'),
          bytes: Uint8List.fromList(
            utf8.encode(
              exportSvg(
                document,
                target,
                assets: media.allBytes,
                lines: textLines,
                transparent: transparent,
              ),
            ),
          ),
        ),
    ];
  }

  final files = <ExportedFile>[];
  final pdfPages = <PdfPageImage>[];
  for (final (done, target) in targets.indexed) {
    onProgress?.call(done, targets.length);
    // Let the frame that shows the progress paint before rendering.
    await Future<void>.delayed(Duration.zero);
    final page = document.pages.firstWhere((p) => p.id == target.pageId);
    var size = exportPixelSize(page, target, scale: options.scale);
    final longest = math.max(size.width, size.height);
    if (longest > maxExportSide) {
      final shrink = maxExportSide / longest;
      size = (
        width: math.max(1, (size.width * shrink).floor()),
        height: math.max(1, (size.height * shrink).floor()),
      );
    }
    final image = await renderRegion(
      document,
      page,
      region: target.region,
      roots: target.roots,
      background: target.includeBackground && !transparent,
      width: size.width,
      height: size.height,
      media: media,
    );
    try {
      switch (format) {
        case ExportFormat.png:
          files.add((
            name: exportFileName(target.name, 'png'),
            bytes: await imagePng(image),
          ));
        case ExportFormat.jpg:
          final pixels = (
            rgba: await imageRgba(image),
            width: size.width,
            height: size.height,
          );
          final quality = options.jpegQuality;
          files.add((
            name: exportFileName(target.name, 'jpg'),
            bytes: await Isolate.run(
              () => encodeJpeg(pixels, quality: quality),
            ),
          ));
        case ExportFormat.webp:
          final pixels = (
            rgba: await imageRgba(image),
            width: size.width,
            height: size.height,
          );
          final quality = options.jpegQuality;
          files.add((
            name: exportFileName(target.name, 'webp'),
            bytes: await Isolate.run(
              () => encodeWebp(pixels, quality: quality),
            ),
          ));
        case ExportFormat.pdf:
          final points = exportPointSize(page, target);
          pdfPages.add((
            widthPt: points.width,
            heightPt: points.height,
            pixels: (
              rgba: await imageRgba(image),
              width: size.width,
              height: size.height,
            ),
          ));
        case ExportFormat.svg || ExportFormat.html:
          break;
      }
    } finally {
      image.dispose();
    }
  }
  onProgress?.call(targets.length, targets.length);
  if (format == ExportFormat.pdf) {
    final meta = document.metadata;
    final title = meta.title;
    final author = meta.author;
    files.add((
      name: exportFileName(title, 'pdf'),
      bytes: await Isolate.run(
        () => encodeRasterPdf(pdfPages, title: title, author: author),
      ),
    ));
  }
  return files;
}

/// A PNG of the first page (or a board's first frame) whose longer side
/// is [longest] pixels, saved inside the design as its cover (P1.6.5).
/// `null` if there is nothing to draw.
Future<Uint8List?> renderCoverPng(
  DesignDocument document,
  MediaCache media, {
  int longest = 480,
}) async {
  final first = document.pages.firstOrNull;
  if (first == null) return null;
  final target =
      exportTargets(
        document,
        scope: ExportScope.currentPage,
        activePage: first.id,
      ).firstOrNull;
  if (target == null) return null;
  final region = target.region;
  if (region.width <= 0 || region.height <= 0) return null;
  final scale = longest / math.max(region.width, region.height);
  final image = await renderRegion(
    document,
    first,
    region: region,
    roots: target.roots,
    background: target.includeBackground,
    width: math.max(1, (region.width * scale).round()),
    height: math.max(1, (region.height * scale).round()),
    media: media,
  );
  try {
    return await imagePng(image);
  } finally {
    image.dispose();
  }
}

/// Renders covers on save; tests replace it (rendering needs the engine).
final coverRendererProvider =
    Provider<Future<Uint8List?> Function(DesignDocument, MediaCache)>(
      (ref) => renderCoverPng,
    );

/// A vector PDF (P1.9.4): every page goes through the SVG writer and is
/// drawn as PDF vectors with real, selectable text in embedded fonts.
/// Images the PDF writer cannot draw as they look (SVG icons, adjusted
/// photos) are rendered to PNG at the export resolution first.
Future<ExportedFile> _vectorPdf(
  DesignDocument document,
  List<ExportTarget> targets, {
  required ExportOptions options,
  required MediaCache media,
  PdfFontResolver? fonts,
  ExportProgress? onProgress,
}) async {
  final pages = <VectorPdfPage>[];
  for (final (done, target) in targets.indexed) {
    onProgress?.call(done, targets.length);
    await Future<void>.delayed(Duration.zero);
    final page = document.pages.firstWhere((p) => p.id == target.pageId);
    final pixels = exportPixelSize(page, target, scale: options.scale);
    final ppu = pixels.width / math.max(target.region.width, 1e-6);
    final overrides = <ObjectId, ({String mime, Uint8List bytes})>{};
    for (final o in _subtree(document, target.roots)) {
      if (o.payload case final ImagePayload payload
          when !payload.adjust.isNone ||
              document.assets[payload.assetHash]?.mime == 'image/svg+xml') {
        final png = await _renderImageObject(document, o, media, ppu);
        if (png != null) overrides[o.id] = (mime: 'image/png', bytes: png);
      }
    }
    final points = exportPointSize(page, target);
    pages.add((
      svg: exportSvg(
        document,
        target,
        assets: media.allBytes,
        lines: textLines,
        imageOverride: (o) => overrides[o.id],
      ),
      widthPt: points.width,
      heightPt: points.height,
    ));
  }
  onProgress?.call(targets.length, targets.length);

  // The font files the text needs, keyed like the lookup below.
  final faces = <String, Uint8List>{};
  // Text without a family is drawn in the platform's UI font on canvas.
  final defaultFamily = Platform.isWindows ? 'Segoe UI' : 'Inter';
  if (fonts != null) {
    for (final o in document.objects.values) {
      if (o.payload case TextPayload(
        :final fontFamily,
        :final fontWeight,
        :final italic,
      )) {
        final family = fontFamily ?? defaultFamily;
        final key = _faceKey(family, fontWeight, italic: italic);
        if (faces.containsKey(key)) continue;
        final bytes = await fonts(family, weight: fontWeight, italic: italic);
        if (bytes != null) faces[key] = bytes;
      }
    }
  }
  final meta = document.metadata;
  final title = meta.title;
  final author = meta.author;
  final bytes = await Isolate.run(
    () => encodeVectorPdf(
      pages,
      title: title,
      author: author,
      defaultFamily: defaultFamily,
      fonts:
          (family, {required weight, required italic}) =>
              faces[_faceKey(family, weight, italic: italic)],
    ),
  );
  return (name: exportFileName(title, 'pdf'), bytes: bytes);
}

String _faceKey(String family, int weight, {required bool italic}) =>
    '${family.toLowerCase()}|$weight|$italic';

/// [roots] and everything inside them.
Iterable<DesignObject> _subtree(
  DesignDocument document,
  List<ObjectId> roots,
) sync* {
  final stack = [...roots];
  while (stack.isNotEmpty) {
    final o = document.objects[stack.removeLast()];
    if (o == null) continue;
    yield o;
    stack.addAll(o.childIds);
  }
}

/// The whole (uncropped) image of [o] with its colour and adjustments, at
/// [ppu] pixels per page unit (at most 3000 px on its longer side).
Future<Uint8List?> _renderImageObject(
  DesignDocument document,
  DesignObject o,
  MediaCache media,
  double ppu,
) async {
  final payload = o.payload as ImagePayload;
  final t = o.transform;
  final fw = t.width / payload.crop.width;
  final fh = t.height / payload.crop.height;
  if (fw <= 0 || fh <= 0) return null;
  var scale = ppu;
  final longest = math.max(fw, fh) * scale;
  if (longest > 3000) scale *= 3000 / longest;
  final width = math.max(1, (fw * scale).round());
  final height = math.max(1, (fh * scale).round());
  final alone = DesignObject(
    id: o.id,
    type: o.type,
    pageId: const PageId('render'),
    transform: ObjectTransform(width: fw, height: fh),
    style: ObjectStyle(fill: o.style?.fill),
    payload: payload.copyWith(crop: ImagePayload.fullCrop),
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)..scale(width / fw, height / fh);
  paintObject(canvas, document, alone, media: media);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    return await imagePng(image);
  } finally {
    image.dispose();
  }
}
