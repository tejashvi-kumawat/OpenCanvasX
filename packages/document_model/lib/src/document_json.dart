import 'color.dart';
import 'design_object.dart';
import 'geometry.dart';
import 'document.dart';
import 'ids.dart';
import 'migration.dart';
import 'object_type.dart';
import 'page.dart';
import 'prototype.dart';
import 'payload.dart';
import 'style.dart';
import 'text_runs.dart';
import 'transform.dart';
import 'units.dart';

/// Container spec version written to `manifest.json`.
const String currentFormatVersion = '1.0.0';

/// Schema version written to `document.json`.
const int currentSchemaVersion = 2;

/// Migrations for `document.json`. When the schema changes, bump
/// [currentSchemaVersion] and add a `previousVersion: upgrade` step.
final SchemaMigrator documentMigrator = SchemaMigrator(
  currentVersion: currentSchemaVersion,
  steps: {
    // 2 adds boards (`pages[].kind`) and frames; version 1 files need no
    // changes, but older builds must refuse version 2 files.
    1: (document) => document,
  },
);

/// `manifest.json` content for [document] (file-format.md).
Map<String, Object?> encodeManifest(
  DesignDocument document, {
  String? appVersion,
}) {
  final meta = document.metadata;
  return {
    'format_version': currentFormatVersion,
    'document_id': document.id.value,
    'title': meta.title,
    if (meta.author case final author?) 'author': author,
    if (appVersion != null) 'app_version_saved': appVersion,
    if (meta.createdAt case final created?)
      'created_at': created.toUtc().toIso8601String(),
    if (meta.modifiedAt case final modified?)
      'modified_at': modified.toUtc().toIso8601String(),
  };
}

/// `document.json` content for [document], at [currentSchemaVersion].
Map<String, Object?> encodeDocumentBody(DesignDocument document) => {
  'schema_version': currentSchemaVersion,
  'pages': [for (final page in document.pages) _encodePage(page)],
  'objects': {
    for (final MapEntry(:key, :value) in document.objects.entries)
      key.value: _encodeObject(value),
  },
  'styles': {
    for (final MapEntry(:key, :value) in document.styles.entries)
      key: _encodeStyle(value),
  },
  'asset_index': {
    for (final MapEntry(:key, :value) in document.assets.entries)
      key: {
        'mime': value.mime,
        'byte_length': value.byteLength,
        if (value.licenseRef case final license?) 'license_ref': license,
      },
  },
};

/// Rebuilds a document from decoded `manifest.json` and `document.json`.
///
/// Older schemas are migrated first. Throws [UnsupportedVersionException]
/// for files from a newer app and [FormatException] (with a JSON path) for
/// malformed content. Cross-references are not checked here: call
/// [DesignDocument.validate] on the result.
DesignDocument decodeDocument({
  required Object? manifest,
  required Object? body,
  SchemaMigrator? migrator,
}) {
  final m = _Json.root(manifest, 'manifest');
  final formatVersion = m.string('format_version');
  final major = int.tryParse(formatVersion.split('.').first);
  if (major == null) {
    throw FormatException(
      'manifest.format_version is not a version',
      formatVersion,
    );
  }
  if (major > int.parse(currentFormatVersion.split('.').first)) {
    throw UnsupportedVersionException(formatVersion, currentFormatVersion);
  }

  final rawBody = _Json.root(body, 'document').map;
  final migrated = (migrator ?? documentMigrator).migrate(
    Map<String, Object?>.of(rawBody),
  );
  final d = _Json(migrated, 'document');

  return DesignDocument(
    id: DocumentId(m.string('document_id')),
    metadata: DocumentMetadata(
      title: m.string('title'),
      author: m.optString('author'),
      createdAt: m.optDate('created_at'),
      modifiedAt: m.optDate('modified_at'),
    ),
    pages: [
      for (final (i, page) in d.list('pages').indexed)
        _decodePage(_Json.root(page, 'document.pages[$i]')),
    ],
    objects: {
      for (final MapEntry(:key, :value) in d.object('objects').map.entries)
        ObjectId(key): _decodeObject(
          ObjectId(key),
          _Json.root(value, 'document.objects.$key'),
        ),
    },
    styles: {
      for (final MapEntry(:key, :value) in d.optObject('styles').entries)
        key: _decodeStyle(_Json.root(value, 'document.styles.$key')),
    },
    assets: {
      for (final MapEntry(:key, :value) in d.optObject('asset_index').entries)
        key: _decodeAsset(_Json.root(value, 'document.asset_index.$key')),
    },
  );
}

// ---------------------------------------------------------------- encoding

Map<String, Object?> _encodePage(DesignPage page) => {
  'id': page.id.value,
  if (page.kind != PageKind.fixed) 'kind': page.kind.name,
  'name': page.name,
  'width': page.width,
  'height': page.height,
  'unit': page.unit.symbol,
  'dpi': page.dpi,
  'background': switch (page.background) {
    TransparentBackground() => {'type': 'transparent'},
    SolidBackground(:final color) => {
      'type': 'solid',
      'color': _encodeColor(color),
    },
    ImageBackground(:final assetHash) => {'type': 'image', 'asset': assetHash},
  },
  'bleed': _encodeInsets(page.bleed),
  'margins': _encodeInsets(page.margins),
  'guides': [
    for (final guide in page.guides)
      {'axis': guide.axis.name, 'position': guide.position},
  ],
  'object_ids': [for (final id in page.objectIds) id.value],
  if (page.links.isNotEmpty)
    'links': [
      for (final l in page.links)
        {
          'source': l.source.value,
          'target': l.target.value,
          'transition': _snake(l.transition.name),
        },
    ],
};

Map<String, Object?> _encodeInsets(PageInsets i) => {
  'top': i.top,
  'right': i.right,
  'bottom': i.bottom,
  'left': i.left,
};

Map<String, Object?> _encodeObject(DesignObject o) {
  final t = o.transform;
  return {
    'type': _snake(o.type.name),
    if (o.pageId case final pageId?) 'page_id': pageId.value,
    if (o.parentId case final parentId?) 'parent_id': parentId.value,
    if (o.childIds.isNotEmpty)
      'child_ids': [for (final c in o.childIds) c.value],
    if (o.name case final name?) 'name': name,
    'transform': {
      'x': t.x,
      'y': t.y,
      'width': t.width,
      'height': t.height,
      'rotation': t.rotation,
      'scale_x': t.scaleX,
      'scale_y': t.scaleY,
      'anchor_x': t.anchorX,
      'anchor_y': t.anchorY,
    },
    'opacity': o.opacity,
    'blend_mode': _snake(o.blendMode.name),
    'locked': o.locked,
    'hidden': o.hidden,
    if (o.styleId case final styleId?) 'style_id': styleId,
    if (o.style case final style?) 'style': _encodeStyle(style),
    if (o.payload is! NoPayload) 'payload': _encodePayload(o.payload),
  };
}

Map<String, Object?> _encodeStyle(ObjectStyle s) => {
  if (s.fill case final fill?) 'fill': _encodeFill(fill),
  if (s.stroke case final stroke?)
    'stroke': {
      'color': _encodeColor(stroke.color),
      'width': stroke.width,
      if (stroke.dash != StrokeDash.solid) 'dash': stroke.dash.name,
    },
  'corner_radius': s.cornerRadius,
};

Map<String, Object?> _encodePayload(ObjectPayload p) => switch (p) {
  NoPayload() => const {},
  final TextPayload t => {
    'text': t.text,
    if (t.fontFamily case final family?) 'font_family': family,
    'font_size': t.fontSize,
    'font_weight': t.fontWeight,
    if (t.italic) 'italic': true,
    'align': t.align.name,
    'line_height': t.lineHeight,
    'letter_spacing': t.letterSpacing,
    'sizing': _snake(t.sizing.name),
    if (t.runs.isNotEmpty)
      'runs': [
        for (final r in t.runs)
          {
            'start': r.start,
            'end': r.end,
            if (r.fontWeight != null) 'font_weight': r.fontWeight,
            if (r.italic != null) 'italic': r.italic,
            if (r.underline != null) 'underline': r.underline,
            if (r.strikethrough != null) 'strikethrough': r.strikethrough,
            if (r.color != null) 'color': _encodeColor(r.color!),
            if (r.fontSize != null) 'font_size': r.fontSize,
            if (r.fontFamily != null) 'font_family': r.fontFamily,
          },
      ],
  },
  FramePayload(:final clipContent, :final component) => {
    'clip_content': clipContent,
    if (component) 'component': true,
  },
  InstancePayload(:final componentId) => {'component': componentId.value},
  PolygonPayload(:final sides) => {'sides': sides},
  StarPayload(:final points, :final innerRatio) => {
    'points': points,
    'inner_ratio': innerRatio,
  },
  ImagePayload(:final assetHash, :final adjust, :final crop) => {
    'asset': assetHash,
    if (crop != ImagePayload.fullCrop)
      'crop': [crop.left, crop.top, crop.right, crop.bottom],
    if (!adjust.isNone)
      'adjust': {
        for (final MapEntry(:key, :value) in adjust.toMap().entries)
          if (value != 0) key: value,
      },
  },
  MaskPayload() => {'mask': true},
  PathPayload(:final segments, :final viewWidth, :final viewHeight) => {
    'segments': [for (final s in segments) _encodeSegment(s)],
    if (viewWidth != null) 'view_width': viewWidth,
    if (viewHeight != null) 'view_height': viewHeight,
  },
};

List<Object> _encodeSegment(PathSegment s) => switch (s) {
  MoveTo(:final x, :final y) => ['M', x, y],
  LineTo(:final x, :final y) => ['L', x, y],
  QuadTo(:final cx, :final cy, :final x, :final y) => ['Q', cx, cy, x, y],
  CubicTo(:final c1x, :final c1y, :final c2x, :final c2y, :final x, :final y) =>
    ['C', c1x, c1y, c2x, c2y, x, y],
  ClosePath() => ['Z'],
};

/// CSS-style `#rrggbbaa`, lowercase.
String _encodeColor(ArgbColor c) {
  String hex(int v) => v.toRadixString(16).padLeft(2, '0');
  return '#${hex(c.red)}${hex(c.green)}${hex(c.blue)}${hex(c.alpha)}';
}

// ---------------------------------------------------------------- decoding

DesignPage _decodePage(_Json j) => j.guard(() {
  final unitSymbol = j.string('unit');
  return DesignPage(
    id: PageId(j.string('id')),
    kind:
        j.has('kind')
            ? _enumByName(PageKind.values, j, 'kind')
            : PageKind.fixed,
    name: j.optString('name') ?? '',
    width: j.number('width'),
    height: j.number('height'),
    unit:
        LengthUnit.fromSymbol(unitSymbol) ??
        (throw j.error('unit', 'unknown unit "$unitSymbol"')),
    dpi: j.optNumber('dpi') ?? defaultDpi,
    background: _decodeBackground(j.child('background')),
    bleed: _decodeInsets(j.child('bleed')),
    margins: _decodeInsets(j.child('margins')),
    guides: [
      for (final (i, g) in j.optList('guides').indexed)
        _decodeGuide(_Json.root(g, '${j.path}.guides[$i]')),
    ],
    objectIds: [
      for (final (i, id) in j.optList('object_ids').indexed)
        ObjectId(_asString(id, '${j.path}.object_ids[$i]')),
    ],
    links: [
      for (final (i, raw) in j.optList('links').indexed)
        () {
          final l = _Json.root(raw, '${j.path}.links[$i]');
          return l.guard(
            () => PrototypeLink(
              source: ObjectId(l.string('source')),
              target: ObjectId(l.string('target')),
              transition:
                  l.has('transition')
                      ? _enumByName(PrototypeTransition.values, l, 'transition')
                      : PrototypeTransition.dissolve,
            ),
          );
        }(),
    ],
  );
});

PageBackground _decodeBackground(_Json? j) {
  if (j == null) return const SolidBackground(ArgbColor.white);
  return j.guard(
    () => switch (j.string('type')) {
      'transparent' => const TransparentBackground(),
      'solid' => SolidBackground(_decodeColor(j, 'color')),
      'image' => ImageBackground(j.string('asset')),
      final other => throw j.error('type', 'unknown background "$other"'),
    },
  );
}

PageInsets _decodeInsets(_Json? j) {
  if (j == null) return PageInsets.zero;
  return j.guard(
    () => PageInsets(
      top: j.optNumber('top') ?? 0,
      right: j.optNumber('right') ?? 0,
      bottom: j.optNumber('bottom') ?? 0,
      left: j.optNumber('left') ?? 0,
    ),
  );
}

Guide _decodeGuide(_Json j) => j.guard(
  () => Guide(
    _enumByName(GuideAxis.values, j, 'axis', snake: false),
    j.number('position'),
  ),
);

DesignObject _decodeObject(ObjectId id, _Json j) => j.guard(() {
  final type = _enumByName(ObjectType.values, j, 'type');
  final t = j.object('transform');
  final pageId = j.optString('page_id');
  final parentId = j.optString('parent_id');
  final style = j.child('style');
  return DesignObject(
    id: id,
    type: type,
    transform: t.guard(
      () => ObjectTransform(
        x: t.optNumber('x') ?? 0,
        y: t.optNumber('y') ?? 0,
        width: t.number('width'),
        height: t.number('height'),
        rotation: t.optNumber('rotation') ?? 0,
        scaleX: t.optNumber('scale_x') ?? 1,
        scaleY: t.optNumber('scale_y') ?? 1,
        anchorX: t.optNumber('anchor_x') ?? 0.5,
        anchorY: t.optNumber('anchor_y') ?? 0.5,
      ),
    ),
    pageId: pageId == null ? null : PageId(pageId),
    parentId: parentId == null ? null : ObjectId(parentId),
    childIds: [
      for (final (i, c) in j.optList('child_ids').indexed)
        ObjectId(_asString(c, '${j.path}.child_ids[$i]')),
    ],
    name: j.optString('name'),
    opacity: j.optNumber('opacity') ?? 1,
    blendMode:
        j.has('blend_mode')
            ? _enumByName(ObjectBlendMode.values, j, 'blend_mode')
            : ObjectBlendMode.normal,
    locked: j.optBool('locked') ?? false,
    hidden: j.optBool('hidden') ?? false,
    styleId: j.optString('style_id'),
    style: style == null ? null : _decodeStyle(style),
    payload: _decodePayload(type, j),
  );
});

ObjectStyle _decodeStyle(_Json j) => j.guard(() {
  final fill = j.child('fill');
  final stroke = j.child('stroke');
  return ObjectStyle(
    fill: fill == null ? null : _decodeFill(fill),
    stroke: stroke?.guard(
      () => Stroke(
        color: _decodeColor(stroke, 'color'),
        width: stroke.optNumber('width') ?? 1,
        dash:
            stroke.has('dash')
                ? _enumByName(StrokeDash.values, stroke, 'dash')
                : StrokeDash.solid,
      ),
    ),
    cornerRadius: j.optNumber('corner_radius') ?? 0,
  );
});

Fill _decodeFill(_Json j) => j.guard(
  () => switch (j.string('type')) {
    'solid' => SolidFill(_decodeColor(j, 'color')),
    'linear' => LinearGradientFill(
      _decodeStops(j),
      angle: j.optNumber('angle') ?? 90,
    ),
    'radial' => RadialGradientFill(
      _decodeStops(j),
      centerX: j.optNumber('center_x') ?? 0.5,
      centerY: j.optNumber('center_y') ?? 0.5,
      radius: j.optNumber('radius') ?? 0.5,
    ),
    final other => throw j.error('type', 'unknown fill "$other"'),
  },
);

List<GradientStop> _decodeStops(_Json j) => [
  for (final (i, raw) in j.list('stops').indexed)
    () {
      final stop = _Json.root(raw, '${j.path}.stops[$i]');
      return stop.guard(
        () => GradientStop(stop.number('offset'), _decodeColor(stop, 'color')),
      );
    }(),
];

Map<String, Object?> _encodeFill(Fill fill) => switch (fill) {
  SolidFill(:final color) => {'type': 'solid', 'color': _encodeColor(color)},
  LinearGradientFill(:final stops, :final angle) => {
    'type': 'linear',
    'angle': angle,
    'stops': _encodeStops(stops),
  },
  RadialGradientFill(
    :final stops,
    :final centerX,
    :final centerY,
    :final radius,
  ) =>
    {
      'type': 'radial',
      'center_x': centerX,
      'center_y': centerY,
      'radius': radius,
      'stops': _encodeStops(stops),
    },
};

List<Map<String, Object?>> _encodeStops(List<GradientStop> stops) => [
  for (final s in stops) {'offset': s.offset, 'color': _encodeColor(s.color)},
];

ObjectPayload _decodePayload(ObjectType type, _Json object) {
  switch (type) {
    case ObjectType.text:
      final p = object.object('payload');
      return p.guard(
        () => TextPayload(
          p.string('text'),
          fontFamily: p.optString('font_family'),
          fontSize: p.optNumber('font_size') ?? 24,
          fontWeight: p.has('font_weight') ? p.integer('font_weight') : 400,
          italic: p.optBool('italic') ?? false,
          align:
              p.has('align')
                  ? _enumByName(TextAlignment.values, p, 'align')
                  : TextAlignment.left,
          lineHeight: p.optNumber('line_height') ?? 1.2,
          letterSpacing: p.optNumber('letter_spacing') ?? 0,
          sizing:
              p.has('sizing')
                  ? _enumByName(TextSizing.values, p, 'sizing')
                  : TextSizing.autoWidth,
          runs: [
            for (final (i, raw) in p.optList('runs').indexed)
              _decodeRun(_Json.root(raw, '${p.path}.runs[$i]')),
          ],
        ),
      );
    case ObjectType.frame:
      final p = object.child('payload');
      return FramePayload(
        clipContent: p?.optBool('clip_content') ?? true,
        component: p?.optBool('component') ?? false,
      );
    case ObjectType.instance:
      final p = object.object('payload');
      return p.guard(() => InstancePayload(ObjectId(p.string('component'))));
    case ObjectType.polygon:
      final p = object.object('payload');
      return p.guard(() => PolygonPayload(sides: p.integer('sides')));
    case ObjectType.star:
      final p = object.object('payload');
      return p.guard(
        () => StarPayload(
          points: p.integer('points'),
          innerRatio: p.optNumber('inner_ratio') ?? 0.5,
        ),
      );
    case ObjectType.image:
      final p = object.object('payload');
      return p.guard(() {
        final adjust = p.child('adjust');
        final crop = [
          for (final v in p.optList('crop'))
            if (v is num) v.toDouble(),
        ];
        return ImagePayload(
          p.string('asset'),
          crop:
              crop.length != 4
                  ? ImagePayload.fullCrop
                  : Rect2D.fromLTRB(crop[0], crop[1], crop[2], crop[3]),
          adjust:
              adjust == null
                  ? ImageAdjustments.none
                  : adjust.guard(
                    () => ImageAdjustments.fromMap({
                      for (final key in ImageAdjustments.none.toMap().keys)
                        if (adjust.optNumber(key) case final v?) key: v,
                    }),
                  ),
        );
      });
    case ObjectType.group:
      final p = object.child('payload');
      return (p?.optBool('mask') ?? false)
          ? const MaskPayload()
          : const NoPayload();
    case ObjectType.path:
      final p = object.object('payload');
      return p.guard(
        () => PathPayload(
          [
            for (final (i, s) in p.list('segments').indexed)
              _decodeSegment(s, '${p.path}.segments[$i]'),
          ],
          viewWidth: p.optNumber('view_width'),
          viewHeight: p.optNumber('view_height'),
        ),
      );
    case ObjectType.rect ||
        ObjectType.roundedRect ||
        ObjectType.ellipse ||
        ObjectType.line ||
        ObjectType.arrow:
      return const NoPayload();
  }
}

PathSegment _decodeSegment(Object? raw, String path) {
  if (raw is! List<Object?> || raw.isEmpty || raw.first is! String) {
    throw FormatException('$path: expected ["CMD", numbers...]', raw);
  }
  final command = raw.first! as String;
  final args = <double>[];
  for (final (i, v) in raw.skip(1).indexed) {
    if (v is! num) {
      throw FormatException('$path[${i + 1}]: expected a number', v);
    }
    args.add(v.toDouble());
  }
  const arity = {'M': 2, 'L': 2, 'Q': 4, 'C': 6, 'Z': 0};
  final expected = arity[command];
  if (expected == null) {
    throw FormatException('$path: unknown path command', command);
  }
  if (args.length != expected) {
    throw FormatException('$path: $command takes $expected numbers', raw);
  }
  try {
    return switch (command) {
      'M' => MoveTo(args[0], args[1]),
      'L' => LineTo(args[0], args[1]),
      'Q' => QuadTo(args[0], args[1], args[2], args[3]),
      'C' => CubicTo(args[0], args[1], args[2], args[3], args[4], args[5]),
      _ => const ClosePath(),
    };
    // Model constructors reject bad values with ArgumentError (ADR-0003);
    // for file input that becomes a FormatException with the JSON path.
    // ignore: avoid_catching_errors
  } on ArgumentError catch (e) {
    throw FormatException('$path: ${e.message}', raw);
  }
}

AssetInfo _decodeAsset(_Json j) => j.guard(
  () => AssetInfo(
    mime: j.string('mime'),
    byteLength: j.integer('byte_length'),
    licenseRef: j.optString('license_ref'),
  ),
);

final _cssColor = RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$');

TextRun _decodeRun(_Json r) => r.guard(
  () => TextRun(
    r.integer('start'),
    r.integer('end'),
    fontWeight: r.has('font_weight') ? r.integer('font_weight') : null,
    italic: r.optBool('italic'),
    underline: r.optBool('underline'),
    strikethrough: r.optBool('strikethrough'),
    color: r.has('color') ? _decodeColor(r, 'color') : null,
    fontSize: r.optNumber('font_size'),
    fontFamily: r.optString('font_family'),
  ),
);

ArgbColor _decodeColor(_Json j, String key) {
  final raw = j.string(key);
  final match = _cssColor.firstMatch(raw);
  if (match == null) throw j.error(key, 'expected #rrggbb or #rrggbbaa');
  final rgb = int.parse(match[1]!, radix: 16);
  final alpha = match[2] == null ? 0xFF : int.parse(match[2]!, radix: 16);
  return ArgbColor((alpha << 24) | rgb);
}

T _enumByName<T extends Enum>(
  List<T> values,
  _Json j,
  String key, {
  bool snake = true,
}) {
  final raw = j.string(key);
  for (final value in values) {
    if ((snake ? _snake(value.name) : value.name) == raw) return value;
  }
  throw j.error(key, 'unknown value "$raw"');
}

final _upper = RegExp('[A-Z]');

/// `roundedRect` → `rounded_rect`.
String _snake(String camel) =>
    camel.replaceAllMapped(_upper, (m) => '_${m[0]!.toLowerCase()}');

String _asString(Object? v, String path) =>
    v is String ? v : throw FormatException('$path: expected a string', v);

/// Typed access to a JSON object with path-aware error messages.
final class _Json {
  _Json(this.map, this.path);

  factory _Json.root(Object? value, String path) {
    if (value is Map<String, Object?>) return _Json(value, path);
    if (value is Map && value.keys.every((k) => k is String)) {
      return _Json(Map<String, Object?>.from(value), path);
    }
    throw FormatException('$path: expected an object', value);
  }

  final Map<String, Object?> map;
  final String path;

  FormatException error(String key, String message) =>
      FormatException('$path.$key: $message', map[key]);

  /// Turns model validation errors into a [FormatException] at [path].
  T guard<T>(T Function() build) {
    try {
      return build();
      // See _decodeSegment: model ArgumentErrors become FormatExceptions.
      // ignore: avoid_catching_errors
    } on ArgumentError catch (e) {
      final name = e.name == null ? '' : '${e.name} ';
      throw FormatException('$path: $name${e.message}');
    }
  }

  bool has(String key) => map[key] != null;

  String string(String key) => switch (map[key]) {
    final String v => v,
    _ => throw error(key, 'expected a string'),
  };

  String? optString(String key) => has(key) ? string(key) : null;

  double number(String key) => switch (map[key]) {
    final num v => v.toDouble(),
    _ => throw error(key, 'expected a number'),
  };

  double? optNumber(String key) => has(key) ? number(key) : null;

  int integer(String key) => switch (map[key]) {
    final int v => v,
    _ => throw error(key, 'expected an integer'),
  };

  bool? optBool(String key) => switch (map[key]) {
    null => null,
    final bool v => v,
    _ => throw error(key, 'expected true or false'),
  };

  DateTime? optDate(String key) {
    final raw = optString(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw) ?? (throw error(key, 'expected ISO 8601'));
  }

  List<Object?> list(String key) => switch (map[key]) {
    final List<Object?> v => v,
    _ => throw error(key, 'expected a list'),
  };

  List<Object?> optList(String key) => has(key) ? list(key) : const [];

  _Json object(String key) => _Json.root(map[key], '$path.$key');

  _Json? child(String key) => has(key) ? object(key) : null;

  Map<String, Object?> optObject(String key) => child(key)?.map ?? const {};
}
