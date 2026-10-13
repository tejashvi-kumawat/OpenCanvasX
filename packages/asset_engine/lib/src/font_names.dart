import 'dart:io';
import 'dart:typed_data';

// Font family names from TrueType/OpenType files (P1.5.5), read straight
// from the `name` table without loading whole files. Collections (.ttc)
// report the families of every face.

/// Reads [length] bytes at [offset]; returns fewer at the end of data.
typedef ByteReader = Uint8List Function(int offset, int length);

/// One face of a font file: its family, weight (100–900), whether it is
/// italic, and where it lives (with the face index for collections).
typedef FontFace =
    ({String family, int weight, bool italic, String path, int index});

const _maxNameTable = 512 * 1024;

int _u16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];
int _u32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

/// Family names in the font read by [read] (preferring the typographic
/// family, name ID 16, over the legacy one, ID 1), or an empty list if it
/// is not a font this can read.
List<String> fontFamilyNamesFrom(ByteReader read) =>
    {for (final f in _facesFrom(read)) f.$1}.toList();

/// (family, weight, italic) of every face in the font read by [read].
List<(String, int, bool)> _facesFrom(ByteReader read) {
  final head = read(0, 12);
  if (head.length < 12) return const [];
  final tag = String.fromCharCodes(head.sublist(0, 4));
  if (tag == 'ttcf') {
    final count = _u32(head, 8);
    if (count <= 0 || count > 64) return const [];
    final offsets = read(12, count * 4);
    return [
      for (var i = 0; i + 4 <= offsets.length && i < count * 4; i += 4)
        ...?_faceAt(read, _u32(offsets, i)).let((f) => f == null ? null : [f]),
    ];
  }
  final face = _faceAt(read, 0);
  return face == null ? const [] : [face];
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

/// Convenience for in-memory font data.
List<String> fontFamilyNames(Uint8List bytes) =>
    fontFamilyNamesFrom((offset, length) {
      if (offset >= bytes.length) return Uint8List(0);
      final end = (offset + length).clamp(0, bytes.length);
      return Uint8List.sublistView(bytes, offset, end);
    });

/// Faces of the font file at [path], reading only what is needed.
List<FontFace> fontFacesOfFile(String path) {
  final file = File(path).openSync();
  try {
    final size = file.lengthSync();
    final faces = _facesFrom((offset, length) {
      if (offset >= size) return Uint8List(0);
      file.setPositionSync(offset);
      return file.readSync(length.clamp(0, size - offset));
    });
    return [
      for (final (i, (family, weight, italic)) in faces.indexed)
        (family: family, weight: weight, italic: italic, path: path, index: i),
    ];
  } on Object {
    return const [];
  } finally {
    file.closeSync();
  }
}

/// Family names of the font file at [path], reading only what is needed.
List<String> fontFamilyNamesOfFile(String path) {
  final file = File(path).openSync();
  try {
    final size = file.lengthSync();
    return fontFamilyNamesFrom((offset, length) {
      if (offset >= size) return Uint8List(0);
      file.setPositionSync(offset);
      return file.readSync(length.clamp(0, size - offset));
    });
  } on Object {
    return const [];
  } finally {
    file.closeSync();
  }
}

(String, int, bool)? _faceAt(ByteReader read, int offset) {
  final header = read(offset, 12);
  if (header.length < 12) return null;
  final version = _u32(header, 0);
  // TrueType (0x00010000, 'true') or CFF OpenType ('OTTO').
  if (version != 0x00010000 && version != 0x74727565 && version != 0x4F54544F) {
    return null;
  }
  final tables = _u16(header, 4);
  if (tables <= 0 || tables > 200) return null;
  final directory = read(offset + 12, tables * 16);
  String? family;
  var subfamily = '';
  var weight = 400;
  bool? italic;
  for (var i = 0; i + 16 <= directory.length; i += 16) {
    final tag = String.fromCharCodes(directory.sublist(i, i + 4));
    final at = _u32(directory, i + 8);
    final length = _u32(directory, i + 12);
    if (tag == 'name' && length > 6 && length <= _maxNameTable) {
      final names = _parseNameTable(read(at, length));
      family = names.family;
      subfamily = names.subfamily ?? '';
    } else if (tag == 'OS/2' && length >= 64) {
      final os2 = read(at, 64);
      if (os2.length >= 64) {
        weight = _u16(os2, 4).clamp(1, 1000);
        italic = (_u16(os2, 62) & 1) != 0;
      }
    }
  }
  if (family == null) return null;
  final sub = subfamily.toLowerCase();
  return (
    family,
    weight,
    italic ?? (sub.contains('italic') || sub.contains('oblique')),
  );
}

({String? family, String? subfamily}) _parseNameTable(Uint8List t) {
  if (t.length < 6) return (family: null, subfamily: null);
  final count = _u16(t, 2);
  final storage = _u16(t, 4);
  // Best match per name ID: Windows Unicode English first, then any
  // Windows Unicode, then Mac Roman.
  final best = <int, (int, String)>{};
  for (var i = 0; i < count; i++) {
    final r = 6 + i * 12;
    if (r + 12 > t.length) break;
    final platform = _u16(t, r);
    final encoding = _u16(t, r + 2);
    final language = _u16(t, r + 4);
    final nameId = _u16(t, r + 6);
    if (nameId != 1 && nameId != 2 && nameId != 16 && nameId != 17) continue;
    final length = _u16(t, r + 8);
    final start = storage + _u16(t, r + 10);
    if (start + length > t.length) continue;
    final raw = t.sublist(start, start + length);
    String? text;
    var rank = 0;
    if (platform == 3 && (encoding == 1 || encoding == 10)) {
      final units = <int>[
        for (var j = 0; j + 1 < raw.length; j += 2) (raw[j] << 8) | raw[j + 1],
      ];
      text = String.fromCharCodes(units);
      rank = language == 0x0409 ? 3 : 2;
    } else if (platform == 1 && encoding == 0) {
      text = String.fromCharCodes(raw);
      rank = 1;
    } else if (platform == 0) {
      final units = <int>[
        for (var j = 0; j + 1 < raw.length; j += 2) (raw[j] << 8) | raw[j + 1],
      ];
      text = String.fromCharCodes(units);
      rank = 2;
    }
    final clean = text?.replaceAll('\u0000', '').trim();
    if (clean == null || clean.isEmpty) continue;
    final current = best[nameId];
    if (current == null || rank > current.$1) best[nameId] = (rank, clean);
  }
  return (
    family: best[16]?.$2 ?? best[1]?.$2,
    subfamily: best[17]?.$2 ?? best[2]?.$2,
  );
}

/// Folders where the operating system and the user keep fonts.
List<String> systemFontDirectories() {
  final env = Platform.environment;
  if (Platform.isWindows) {
    final windir = env['WINDIR'] ?? r'C:\Windows';
    final local = env['LOCALAPPDATA'];
    return [
      '$windir\\Fonts',
      if (local != null) '$local\\Microsoft\\Windows\\Fonts',
    ];
  }
  final home = env['HOME'];
  if (Platform.isMacOS) {
    return [
      '/System/Library/Fonts',
      '/Library/Fonts',
      if (home != null) '$home/Library/Fonts',
    ];
  }
  return [
    '/usr/share/fonts',
    '/usr/local/share/fonts',
    if (home != null) '$home/.local/share/fonts',
    if (home != null) '$home/.fonts',
  ];
}

/// Installed font faces. Unreadable files are skipped. Slow for big font
/// folders: run off the UI isolate.
List<FontFace> discoverSystemFontFaces({List<String>? directories}) {
  final faces = <FontFace>[];
  for (final dir in directories ?? systemFontDirectories()) {
    final d = Directory(dir);
    if (!d.existsSync()) continue;
    try {
      for (final entity in d.listSync(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final name = entity.path.toLowerCase();
        if (!(name.endsWith('.ttf') ||
            name.endsWith('.otf') ||
            name.endsWith('.ttc') ||
            name.endsWith('.otc'))) {
          continue;
        }
        faces.addAll(fontFacesOfFile(entity.path));
      }
    } on FileSystemException {
      // A folder we may not read; keep what we found.
    }
  }
  return faces;
}

/// Sorted, distinct family names of [faces].
List<String> familiesOf(Iterable<FontFace> faces) =>
    {for (final f in faces) f.family}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

/// Installed font families, sorted and without duplicates.
List<String> discoverSystemFontFamilies({List<String>? directories}) =>
    familiesOf(discoverSystemFontFaces(directories: directories));

/// The face of [family] closest to [weight] and [italic] (italic match
/// first, then the nearest weight), or `null` if [faces] has none.
FontFace? bestFace(
  Iterable<FontFace> faces,
  String family, {
  int weight = 400,
  bool italic = false,
}) {
  final lower = family.toLowerCase();
  FontFace? best;
  var bestScore = 1 << 30;
  for (final f in faces) {
    if (f.family.toLowerCase() != lower) continue;
    final score = (f.italic == italic ? 0 : 10000) + (f.weight - weight).abs();
    if (score < bestScore) {
      best = f;
      bestScore = score;
    }
  }
  return best;
}
