import 'package:meta/meta.dart';

import 'design_object.dart';
import 'ids.dart';
import 'model_issue.dart';
import 'object_graph.dart';
import 'page.dart';
import 'page_graph.dart';
import 'payload.dart';
import 'style.dart';
import 'validation.dart';

/// Descriptive fields stored in the project manifest.
@immutable
final class DocumentMetadata {
  const DocumentMetadata({
    required this.title,
    this.author,
    this.createdAt,
    this.modifiedAt,
  });

  final String title;

  /// Display name only; never an account id or contact detail.
  final String? author;
  final DateTime? createdAt;
  final DateTime? modifiedAt;

  DocumentMetadata copyWith({String? title, DateTime? modifiedAt}) =>
      DocumentMetadata(
        title: title ?? this.title,
        author: author,
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
      );

  @override
  bool operator ==(Object other) =>
      other is DocumentMetadata &&
      other.title == title &&
      other.author == author &&
      other.createdAt == createdAt &&
      other.modifiedAt == modifiedAt;

  @override
  int get hashCode => Object.hash(title, author, createdAt, modifiedAt);
}

/// Entry in the document's asset index; bytes live in the project container.
@immutable
final class AssetInfo {
  factory AssetInfo({
    required String mime,
    required int byteLength,
    String? licenseRef,
  }) {
    if (mime.isEmpty) {
      throw ArgumentError.value(mime, 'mime', 'must not be empty');
    }
    RangeError.checkNotNegative(byteLength, 'byteLength');
    return AssetInfo._(mime, byteLength, licenseRef);
  }

  const AssetInfo._(this.mime, this.byteLength, this.licenseRef);

  final String mime;
  final int byteLength;
  final String? licenseRef;

  @override
  bool operator ==(Object other) =>
      other is AssetInfo &&
      other.mime == mime &&
      other.byteLength == byteLength &&
      other.licenseRef == licenseRef;

  @override
  int get hashCode => Object.hash(mime, byteLength, licenseRef);
}

/// The whole design: pages, the global object map, shared styles and the
/// asset index (document-model.md "Top-level document").
///
/// Construction only copies the collections; call [validate] to check the
/// cross-references, e.g. after opening an untrusted file.
@immutable
final class DesignDocument {
  DesignDocument({
    required this.id,
    required this.metadata,
    required Iterable<DesignPage> pages,
    Map<ObjectId, DesignObject> objects = const {},
    Map<String, ObjectStyle> styles = const {},
    Map<String, AssetInfo> assets = const {},
  }) : pages = List.unmodifiable(pages),
       objects = Map.unmodifiable(objects),
       styles = Map.unmodifiable(styles),
       assets = Map.unmodifiable(assets);

  final DocumentId id;
  final DocumentMetadata metadata;

  /// Pages in document order.
  final List<DesignPage> pages;

  /// Global object map (ADR-0003).
  final Map<ObjectId, DesignObject> objects;

  /// Named shared styles referenced by `DesignObject.styleId`.
  final Map<String, ObjectStyle> styles;

  /// SHA-256 hex → asset entry.
  final Map<String, AssetInfo> assets;

  /// Every cross-reference problem in the document; empty when consistent.
  List<ModelIssue> validate() {
    final issues = <ModelIssue>[
      if (pages.isEmpty) ModelIssue(id.value, 'document has no pages'),
      ...validatePages(pages, objects),
      ...validateObjectGraph(objects),
    ];
    for (final hash in assets.keys) {
      if (!isSha256Hex(hash)) {
        issues.add(ModelIssue(hash, 'asset key is not a SHA-256 hex digest'));
      }
    }
    for (final object in objects.values) {
      final styleId = object.styleId;
      if (styleId != null && !styles.containsKey(styleId)) {
        issues.add(
          ModelIssue(object.id.value, 'style $styleId does not exist'),
        );
      }
      final payload = object.payload;
      if (payload is ImagePayload && !assets.containsKey(payload.assetHash)) {
        issues.add(
          ModelIssue(
            object.id.value,
            'asset ${payload.assetHash} is not in the asset index',
          ),
        );
      }
    }
    for (final page in pages) {
      final background = page.background;
      if (background is ImageBackground &&
          !assets.containsKey(background.assetHash)) {
        issues.add(
          ModelIssue(
            page.id.value,
            'asset ${background.assetHash} is not in the asset index',
          ),
        );
      }
    }
    return issues;
  }

  @override
  bool operator ==(Object other) =>
      other is DesignDocument &&
      other.id == id &&
      other.metadata == metadata &&
      listEquals(other.pages, pages) &&
      mapEquals(other.objects, objects) &&
      mapEquals(other.styles, styles) &&
      mapEquals(other.assets, assets);

  @override
  int get hashCode => Object.hash(
    id,
    metadata,
    Object.hashAll(pages),
    objects.length,
    styles.length,
    assets.length,
  );

  @override
  String toString() =>
      'DesignDocument(${id.value}, ${pages.length} pages, '
      '${objects.length} objects)';
}
