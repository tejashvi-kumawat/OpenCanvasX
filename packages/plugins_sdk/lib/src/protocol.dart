import 'dart:convert';
import 'dart:typed_data';

import 'package:asset_engine/asset_engine.dart';
import 'package:crypto/crypto.dart';
import 'package:design_engine/design_engine.dart';
import 'package:document_model/document_model.dart';

import 'manifest.dart';

/// Most operations one plugin run may return.
const int maxPluginOperations = 2000;

/// Largest coordinate or size a plugin may use (page units).
const double maxPluginCoordinate = 1000000;

/// The JSON request sent to a plugin on stdin (API 1). Only what the
/// plugin's approved permissions allow is included.
Map<String, Object?> buildPluginRequest({
  required PluginManifest manifest,
  required String command,
  required Map<String, Object?> inputs,
  required DesignDocument document,
  required PageId pageId,
  required Set<ObjectId> selection,
}) {
  final page = document.pages.firstWhere((p) => p.id == pageId);
  final perms = manifest.permissions;
  final canRead =
      perms.contains(PluginPermission.readSelection) ||
      perms.contains(PluginPermission.readDocument);
  return {
    'api': pluginApiVersion,
    'command': command,
    'inputs': inputs,
    'page': {
      'id': page.id.value,
      'width': page.width,
      'height': page.height,
      'unit': page.unit.symbol,
      'board': page.isBoard,
    },
    if (canRead)
      'selection': [
        for (final id in pageObjectsInOrder(document, page))
          if (selection.contains(id)) _summary(document, id),
      ],
    if (perms.contains(PluginPermission.readDocument))
      'document': encodeDocumentBody(document),
  };
}

Map<String, Object?> _summary(DesignDocument document, ObjectId id) {
  final o = document.objects[id]!;
  final b = worldBounds(document, id);
  final payload = o.payload;
  return {
    'id': id.value,
    'type': o.type.name,
    if (o.name != null) 'name': o.name,
    if (b != null) ...{
      'x': b.left,
      'y': b.top,
      'width': b.width,
      'height': b.height,
    },
    'rotation': o.transform.rotation,
    if (o.style?.fill?.representative case final c?) 'fill': _hex(c),
    if (payload is TextPayload) 'text': payload.text,
  };
}

/// What applying a plugin's response produced.
typedef PluginEffect =
    ({
      Change change,
      Map<String, Uint8List> assets,
      List<String> messages,
      List<ObjectId> created,
    });

/// Turns a plugin's `{"operations": [...]}` response into one undoable
/// [Change] on [pageId] (P6.1.4). Every operation is validated against the
/// approved [permissions] and limits; any invalid operation rejects the
/// whole response with a [FormatException] (nothing is applied).
PluginEffect applyPluginResponse(
  DesignDocument document,
  PageId pageId,
  Object? response, {
  required Set<PluginPermission> permissions,
  required Point2D Function(TextPayload text) measure,
  ObjectId Function()? newId,
}) {
  if (response is! Map<String, Object?>) {
    throw const FormatException('plugin output must be a JSON object');
  }
  final ops = response['operations'] ?? const [];
  if (ops is! List) throw const FormatException('"operations" must be a list');
  if (ops.length > maxPluginOperations) {
    throw const FormatException('too many operations');
  }
  final makeId = newId ?? ObjectId.generate;
  final canWrite = permissions.contains(PluginPermission.writeDocument);
  var current = document;
  final messages = <String>[];
  final assets = <String, Uint8List>{};
  final created = <ObjectId>[];
  final objects = <ObjectId, DesignObject?>{};
  List<DesignPage>? pages;
  final assetInfos = <String, AssetInfo?>{};

  void apply(Change c) {
    current = c.applyTo(current).$1;
    objects.addAll(c.objects);
    if (c.pages != null) pages = c.pages;
    assetInfos.addAll(c.assets);
  }

  for (final (i, raw) in ops.indexed) {
    if (raw is! Map<String, Object?>) {
      throw FormatException('operation $i is not an object');
    }
    final op = _Op(raw, i);
    final kind = op.string('op');
    if (kind == 'notify') {
      final text = op.string('message');
      messages.add(text.length > 300 ? text.substring(0, 300) : text);
      continue;
    }
    if (!canWrite) {
      throw FormatException(
        'operation $i ($kind) needs the write_document permission',
      );
    }
    switch (kind) {
      case 'create_shape':
        final type = switch (op.string('shape')) {
          'rect' => ObjectType.rect,
          'rounded_rect' => ObjectType.roundedRect,
          'ellipse' => ObjectType.ellipse,
          'polygon' => ObjectType.polygon,
          'star' => ObjectType.star,
          'line' => ObjectType.line,
          'arrow' => ObjectType.arrow,
          final other => throw FormatException('operation $i: shape "$other"'),
        };
        final isLine = type == ObjectType.line || type == ObjectType.arrow;
        final fill = op.optColor('fill');
        final stroke = op.optColor('stroke');
        final shape = DesignObject(
          id: makeId(),
          type: type,
          pageId: pageId,
          name: op.optString('name'),
          opacity: op.optNumber('opacity', min: 0, max: 1) ?? 1,
          transform: ObjectTransform(
            x: op.number('x'),
            y: op.number('y'),
            width: op.number('width', min: 0),
            height: isLine ? 0 : op.number('height', min: 0),
            rotation: op.optNumber('rotation', min: -360, max: 360) ?? 0,
          ),
          style: ObjectStyle(
            fill: isLine || fill == null ? null : SolidFill(fill),
            stroke:
                stroke == null && !isLine
                    ? null
                    : Stroke(
                      color: stroke ?? ArgbColor.black,
                      width:
                          op.optNumber('stroke_width', min: 0, max: 1000) ?? 2,
                    ),
            cornerRadius: op.optNumber('radius', min: 0) ?? 0,
          ),
          payload: switch (type) {
            ObjectType.polygon => PolygonPayload(
              sides: (op.optNumber('sides', min: 3, max: 64) ?? 6).round(),
            ),
            ObjectType.star => StarPayload(
              points: (op.optNumber('points', min: 3, max: 64) ?? 5).round(),
            ),
            _ => const NoPayload(),
          },
        );
        apply(insertObjects(current, pageId, [shape]));
        created.add(shape.id);
      case 'create_text':
        final text = op.string('text', maxLength: 20000);
        final width = op.optNumber('width', min: 1);
        var payload = TextPayload(
          text,
          fontSize: op.optNumber('size', min: 0.1, max: 10000) ?? 24,
          fontWeight: _weight(
            op.optNumber('weight', min: 100, max: 900) ?? 400,
          ),
          fontFamily: op.optString('font'),
          italic: raw['italic'] == true,
          align: switch (op.optString('align')) {
            'center' => TextAlignment.center,
            'right' => TextAlignment.right,
            'justify' => TextAlignment.justify,
            _ => TextAlignment.left,
          },
          sizing: width == null ? TextSizing.autoWidth : TextSizing.autoHeight,
        );
        final size = measure(payload);
        payload = payload.copyWith();
        final object = DesignObject(
          id: makeId(),
          type: ObjectType.text,
          pageId: pageId,
          name: op.optString('name'),
          transform: ObjectTransform(
            x: op.number('x'),
            y: op.number('y'),
            width: width ?? size.x,
            height: size.y,
          ),
          style: ObjectStyle(
            fill: SolidFill(op.optColor('color') ?? ArgbColor(0xFF16181D)),
          ),
          payload: payload,
        );
        apply(insertObjects(current, pageId, [object]));
        created.add(object.id);
      case 'create_svg':
        final svg = op.string('svg', maxLength: 1024 * 1024);
        final bytes = Uint8List.fromList(utf8.encode(svg));
        final check = checkSvg(bytes);
        if (!check.isOk) {
          throw FormatException('operation $i: ${check.error}');
        }
        final hash = sha256.convert(bytes).toString();
        assets[hash] = bytes;
        final image = newImage(
          id: makeId(),
          pageId: pageId,
          assetHash: hash,
          width: op.number('width', min: 0.001),
          height: op.number('height', min: 0.001),
          center: Point2D(
            op.number('x') + op.number('width') / 2,
            op.number('y') + op.number('height') / 2,
          ),
          name: op.optString('name'),
        );
        final insert = insertObjects(current, pageId, [image]);
        apply(
          Change(
            label: insert.label,
            objects: insert.objects,
            pages: insert.pages,
            assets: {
              if (!current.assets.containsKey(hash))
                hash: AssetInfo(
                  mime: 'image/svg+xml',
                  byteLength: bytes.length,
                ),
            },
          ),
        );
        created.add(image.id);
      case 'update':
        final id = ObjectId(op.string('id'));
        final o = current.objects[id];
        if (o == null || rootOf(current, id)?.pageId != pageId) {
          throw FormatException('operation $i: unknown object ${id.value}');
        }
        var t = o.transform;
        t = t.copyWith(
          x: op.optNumber('x') ?? t.x,
          y: op.optNumber('y') ?? t.y,
          width: op.optNumber('width', min: 0) ?? t.width,
          height: op.optNumber('height', min: 0) ?? t.height,
          rotation: op.optNumber('rotation', min: -360, max: 360) ?? t.rotation,
        );
        final fill = op.optColor('fill');
        final text =
            raw.containsKey('text')
                ? op.string('text', maxLength: 20000)
                : null;
        final payload = o.payload;
        apply(
          updateObjects(current, [
            o.copyWith(
              name: op.optString('name') ?? o.name,
              transform: t,
              opacity: op.optNumber('opacity', min: 0, max: 1) ?? o.opacity,
              hidden: raw['hidden'] is bool ? raw['hidden']! as bool : o.hidden,
              locked: raw['locked'] is bool ? raw['locked']! as bool : o.locked,
              style:
                  fill == null
                      ? o.style
                      : ObjectStyle(
                        fill: SolidFill(fill),
                        stroke: o.style?.stroke,
                        cornerRadius: o.style?.cornerRadius ?? 0,
                      ),
              payload:
                  text != null && payload is TextPayload
                      ? payload.copyWith(text: text)
                      : payload,
            ),
          ], label: 'Plugin'),
        );
      case 'delete':
        final id = ObjectId(op.string('id'));
        if (current.objects[id] == null ||
            rootOf(current, id)?.pageId != pageId) {
          throw FormatException('operation $i: unknown object ${id.value}');
        }
        apply(deleteObjects(current, [id]));
      default:
        throw FormatException('operation $i: unknown op "$kind"');
    }
  }
  // Keep only page-level changes for this page and the final objects.
  final finalObjects = {for (final id in objects.keys) id: current.objects[id]};
  return (
    change: Change(
      label: 'Plugin',
      objects: finalObjects,
      pages: pages,
      assets: assetInfos,
    ),
    assets: assets,
    messages: messages,
    created: [
      for (final id in created)
        if (current.objects.containsKey(id)) id,
    ],
  );
}

int _weight(double v) => ((v / 100).round() * 100).clamp(100, 900);

String _hex(ArgbColor c) =>
    '#${(c.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Typed access to one operation with bounds checks.
class _Op {
  _Op(this.json, this.index);

  final Map<String, Object?> json;
  final int index;

  Never _bad(String key, String why) =>
      throw FormatException('operation $index: "$key" $why');

  String string(String key, {int maxLength = 1000}) {
    final v = json[key];
    if (v is! String) _bad(key, 'must be text');
    if (v.length > maxLength) _bad(key, 'is too long');
    return v;
  }

  String? optString(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String || v.length > 200) _bad(key, 'must be short text');
    return v.trim().isEmpty ? null : v;
  }

  double number(
    String key, {
    double min = -maxPluginCoordinate,
    double max = maxPluginCoordinate,
  }) {
    final v = optNumber(key, min: min, max: max);
    if (v == null) _bad(key, 'is required');
    return v;
  }

  double? optNumber(
    String key, {
    double min = -maxPluginCoordinate,
    double max = maxPluginCoordinate,
  }) {
    final v = json[key];
    if (v == null) return null;
    if (v is! num || !v.isFinite) _bad(key, 'must be a number');
    if (v < min || v > max) _bad(key, 'is out of range');
    return v.toDouble();
  }

  ArgbColor? optColor(String key) {
    final v = json[key];
    if (v == null) return null;
    if (v is! String) _bad(key, 'must be a colour like "#3256F0"');
    final m = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(v);
    if (m == null) _bad(key, 'must be a colour like "#3256F0"');
    final rgb = int.parse(m.group(1)!, radix: 16);
    final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
    return ArgbColor((a << 24) | rgb);
  }
}
