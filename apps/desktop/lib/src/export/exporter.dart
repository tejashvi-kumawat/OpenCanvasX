import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:document_model/document_model.dart';
import 'package:export_engine/export_engine.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:renderer/renderer.dart';

/// Output formats (P1.9).
enum ExportFormat {
  png('PNG', 'png', 'Best for web and social; supports transparency'),
  jpg('JPG', 'jpg', 'Smallest files for photos; no transparency'),
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

  bool get isRaster => this == png || this == jpg || this == pdf;
  bool get isVector => this == svg || this == html;
  bool get supportsTransparency => this == png || this == svg;
}

/// Everything the user chose in the export dialog.
class ExportOptions {
  const ExportOptions({
    this.format = ExportFormat.png,
    this.scope = ExportScope.currentPage,
    this.scale = 2,
    this.transparent = false,
    this.jpegQuality = 90,
  });

  final ExportFormat format;
  final ExportScope scope;

  /// Pixel multiplier for raster output (PDF: 1 ≈ 96 dpi, 3 ≈ 300 dpi).
  final double scale;
  final bool transparent;
  final int jpegQuality;

  ExportOptions copyWith({
    ExportFormat? format,
    ExportScope? scope,
    double? scale,
    bool? transparent,
    int? jpegQuality,
  }) => ExportOptions(
    format: format ?? this.format,
    scope: scope ?? this.scope,
    scale: scale ?? this.scale,
    transparent: transparent ?? this.transparent,
    jpegQuality: jpegQuality ?? this.jpegQuality,
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

/// Produces the files for [options] (P1.9.1–P1.9.4). Rendering happens on
/// the UI isolate (Flutter's canvas); encoding is quick for typical sizes.
/// Background workers (P1.9.5) come later.
Future<List<ExportedFile>> buildExport(
  DesignDocument document, {
  required ExportOptions options,
  required PageId activePage,
  required Set<ObjectId> selection,
  required MediaCache media,
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
  for (final target in targets) {
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
          final rgba = await imageRgba(image);
          files.add((
            name: exportFileName(target.name, 'jpg'),
            bytes: encodeJpeg((
              rgba: rgba,
              width: size.width,
              height: size.height,
            ), quality: options.jpegQuality),
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
  if (format == ExportFormat.pdf) {
    final meta = document.metadata;
    files.add((
      name: exportFileName(meta.title, 'pdf'),
      bytes: await encodeRasterPdf(
        pdfPages,
        title: meta.title,
        author: meta.author,
      ),
    ));
  }
  return files;
}
