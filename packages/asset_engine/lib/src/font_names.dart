import 'dart:io';
import 'dart:typed_data';

// Font family names from TrueType/OpenType files (P1.5.5), read straight
// from the `name` table without loading whole files. Collections (.ttc)
// report the families of every face.

/// Reads [length] bytes at [offset]; returns fewer at the end of data.
typedef ByteReader = Uint8List Function(int offset, int length);

const _maxNameTable = 512 * 1024;

int _u16(Uint8List b, int o) => (b[o] << 8) | b[o + 1];
int _u32(Uint8List b, int o) =>
    (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];

/// Family names in the font read by [read] (preferring the typographic
/// family, name ID 16, over the legacy one, ID 1), or an empty list if it
/// is not a font this can read.
List<String> fontFamilyNamesFrom(ByteReader read) {
  final head = read(0, 12);
  if (head.length < 12) return const [];
  final tag = String.fromCharCodes(head.sublist(0, 4));
  if (tag == 'ttcf') {
    final count = _u32(head, 8);
    if (count <= 0 || count > 64) return const [];
    final offsets = read(12, count * 4);
    final names = <String>{};
    for (var i = 0; i + 4 <= offsets.length; i++) {
      final at = _u32(offsets, i * 4);
      names.addAll(_familyAt(read, at));
      if (i >= count - 1) break;
    }
    return names.toList();
  }
  return _familyAt(read, 0);
}

/// Convenience for in-memory font data.
List<String> fontFamilyNames(Uint8List bytes) =>
    fontFamilyNamesFrom((offset, length) {
      if (offset >= bytes.length) return Uint8List(0);
      final end = (offset + length).clamp(0, bytes.length);
      return Uint8List.sublistView(bytes, offset, end);
    });

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

List<String> _familyAt(ByteReader read, int offset) {
  final header = read(offset, 12);
  if (header.length < 12) return const [];
  final version = _u32(header, 0);
  // TrueType (0x00010000, 'true') or CFF OpenType ('OTTO').
  if (version != 0x00010000 && version != 0x74727565 && version != 0x4F54544F) {
    return const [];
  }
  final tables = _u16(header, 4);
  if (tables <= 0 || tables > 200) return const [];
  final directory = read(offset + 12, tables * 16);
  for (var i = 0; i + 16 <= directory.length; i += 16) {
    if (String.fromCharCodes(directory.sublist(i, i + 4)) != 'name') continue;
    final at = _u32(directory, i + 8);
    final length = _u32(directory, i + 12);
    if (length <= 6 || length > _maxNameTable) return const [];
    return _parseNameTable(read(at, length));
  }
  return const [];
}

List<String> _parseNameTable(Uint8List t) {
  if (t.length < 6) return const [];
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
    if (nameId != 1 && nameId != 16) continue;
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
  final family = best[16]?.$2 ?? best[1]?.$2;
  return family == null ? const [] : [family];
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

/// Installed font families, sorted and without duplicates. Unreadable
/// files are skipped. Slow for big font folders: run off the UI isolate.
List<String> discoverSystemFontFamilies({List<String>? directories}) {
  final families = <String>{};
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
        families.addAll(fontFamilyNamesOfFile(entity.path));
      }
    } on FileSystemException {
      // A folder we may not read; keep what we found.
    }
  }
  final list =
      families.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return list;
}
