import 'package:meta/meta.dart';

import 'ids.dart';
import 'object_type.dart';
import 'payload.dart';
import 'style.dart';
import 'transform.dart';
import 'validation.dart';

/// One node in a document's layer tree.
///
/// Objects live in a single global map keyed by [id] (ADR-0003). Root objects
/// set [pageId]; nested objects set [parentId]. Exactly one of the two is set.
@immutable
final class DesignObject {
  factory DesignObject({
    required ObjectId id,
    required ObjectType type,
    required ObjectTransform transform,
    PageId? pageId,
    ObjectId? parentId,
    Iterable<ObjectId> childIds = const [],
    String? name,
    double opacity = 1,
    ObjectBlendMode blendMode = ObjectBlendMode.normal,
    bool locked = false,
    bool hidden = false,
    String? styleId,
    ObjectStyle? style,
    ObjectPayload payload = const NoPayload(),
  }) {
    if ((pageId == null) == (parentId == null)) {
      throw ArgumentError(
        'Exactly one of pageId (root object) or parentId (nested object) '
        'must be set',
      );
    }
    if (parentId == id) {
      throw ArgumentError.value(parentId, 'parentId', 'must not be own id');
    }
    final children = List<ObjectId>.unmodifiable(childIds);
    if (children.isNotEmpty && !type.isContainer) {
      throw ArgumentError.value(
        type,
        'type',
        'only groups and frames have children',
      );
    }
    if (children.contains(id)) {
      throw ArgumentError.value(id, 'childIds', 'must not contain own id');
    }
    if (children.toSet().length != children.length) {
      throw ArgumentError.value(children, 'childIds', 'contains duplicates');
    }
    checkUnitInterval(opacity, 'opacity');
    if (!payload.fits(type)) {
      throw ArgumentError.value(
        payload,
        'payload',
        'does not match object type ${type.name}',
      );
    }
    return DesignObject._(
      id: id,
      type: type,
      transform: transform,
      pageId: pageId,
      parentId: parentId,
      childIds: children,
      name: name,
      opacity: opacity,
      blendMode: blendMode,
      locked: locked,
      hidden: hidden,
      styleId: styleId,
      style: style,
      payload: payload,
    );
  }

  const DesignObject._({
    required this.id,
    required this.type,
    required this.transform,
    required this.pageId,
    required this.parentId,
    required this.childIds,
    required this.name,
    required this.opacity,
    required this.blendMode,
    required this.locked,
    required this.hidden,
    required this.styleId,
    required this.style,
    required this.payload,
  });

  final ObjectId id;
  final ObjectType type;
  final ObjectTransform transform;

  /// Page this root object sits on; `null` for nested objects.
  final PageId? pageId;

  /// Group containing this object; `null` for root objects.
  final ObjectId? parentId;

  /// Children of a group or frame, back-to-front (index 0 is drawn first).
  final List<ObjectId> childIds;

  /// User-facing layer name; `null` means the UI shows a default label.
  final String? name;

  final double opacity;
  final ObjectBlendMode blendMode;
  final bool locked;
  final bool hidden;

  /// Shared style this object uses; [style] fields override it.
  final String? styleId;
  final ObjectStyle? style;

  final ObjectPayload payload;

  bool get isRoot => parentId == null;

  /// Returns a copy with the given fields replaced.
  ///
  /// Nullable fields can be cleared by passing `null` explicitly, e.g.
  /// `copyWith(pageId: null, parentId: groupId)` to move into a group.
  DesignObject copyWith({
    ObjectType? type,
    ObjectTransform? transform,
    Object? pageId = _unset,
    Object? parentId = _unset,
    Iterable<ObjectId>? childIds,
    Object? name = _unset,
    double? opacity,
    ObjectBlendMode? blendMode,
    bool? locked,
    bool? hidden,
    Object? styleId = _unset,
    Object? style = _unset,
    ObjectPayload? payload,
  }) {
    return DesignObject(
      id: id,
      type: type ?? this.type,
      transform: transform ?? this.transform,
      pageId: pageId == _unset ? this.pageId : pageId as PageId?,
      parentId: parentId == _unset ? this.parentId : parentId as ObjectId?,
      childIds: childIds ?? this.childIds,
      name: name == _unset ? this.name : name as String?,
      opacity: opacity ?? this.opacity,
      blendMode: blendMode ?? this.blendMode,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      styleId: styleId == _unset ? this.styleId : styleId as String?,
      style: style == _unset ? this.style : style as ObjectStyle?,
      payload: payload ?? this.payload,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DesignObject &&
      other.id == id &&
      other.type == type &&
      other.transform == transform &&
      other.pageId == pageId &&
      other.parentId == parentId &&
      listEquals(other.childIds, childIds) &&
      other.name == name &&
      other.opacity == opacity &&
      other.blendMode == blendMode &&
      other.locked == locked &&
      other.hidden == hidden &&
      other.styleId == styleId &&
      other.style == style &&
      other.payload == payload;

  @override
  int get hashCode => Object.hash(
    id,
    type,
    transform,
    pageId,
    parentId,
    Object.hashAll(childIds),
    name,
    opacity,
    blendMode,
    locked,
    hidden,
    styleId,
    style,
    payload,
  );

  @override
  String toString() => 'DesignObject(${type.name} ${id.value})';
}

const Object _unset = Object();
