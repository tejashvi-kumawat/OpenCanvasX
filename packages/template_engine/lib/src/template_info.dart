import 'package:meta/meta.dart';

/// Template gallery groups (P2.2.6–P2.2.8).
const templateCategories = <String, String>{
  'social': 'Social media',
  'story': 'Stories',
  'video': 'Video thumbnails',
  'presentation': 'Presentations',
  'print': 'Posters and flyers',
  'business': 'Business cards',
  'document': 'Resumes and documents',
  'event': 'Invitations and certificates',
  'web': 'Websites and apps',
};

/// One template in a repository `index.json` (template-architecture.md
/// "Template metadata").
@immutable
final class TemplateInfo {
  const TemplateInfo({
    required this.id,
    required this.name,
    required this.category,
    required this.file,
    required this.width,
    required this.height,
    required this.unit,
    required this.pages,
    required this.license,
    required this.licenseUrl,
    required this.author,
    this.version = '1.0.0',
    this.tags = const [],
    this.board = false,
  });

  /// Parses one `index.json` entry. Entries without licence metadata or
  /// with unsafe paths are rejected (P2.2.5) with a [FormatException].
  factory TemplateInfo.fromJson(Map<String, Object?> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('template index: missing "$key"');
      }
      return value;
    }

    num number(String key) {
      final value = json[key];
      if (value is! num || value <= 0 || !value.isFinite) {
        throw FormatException('template index: bad "$key"');
      }
      return value;
    }

    final id = text('id');
    if (!RegExp(r'^[a-z0-9_-]+$').hasMatch(id)) {
      throw FormatException('template index: bad id "$id"');
    }
    final file = text('file');
    if (file.contains('..') ||
        file.startsWith('/') ||
        file.contains(r'\') ||
        !file.endsWith('.opencanvasx')) {
      throw FormatException('template index: unsafe file "$file"');
    }
    final tags = json['tags'];
    return TemplateInfo(
      id: id,
      name: text('name'),
      category: text('category'),
      file: file,
      width: number('width').toDouble(),
      height: number('height').toDouble(),
      unit: text('unit'),
      pages: number('pages').toInt(),
      license: text('license'),
      licenseUrl: text('license_url'),
      author: text('author'),
      version: json['version'] is String ? json['version']! as String : '1.0.0',
      tags: [
        if (tags is List)
          for (final t in tags)
            if (t is String) t.toLowerCase(),
      ],
      board: json['board'] == true,
    );
  }

  final String id;
  final String name;

  /// Key of [templateCategories].
  final String category;

  /// Path of the `.opencanvasx` file inside the repository.
  final String file;
  final double width;
  final double height;
  final String unit;
  final int pages;
  final String license;
  final String licenseUrl;
  final String author;
  final String version;
  final List<String> tags;

  /// Whether the template is a board of frames rather than pages.
  final bool board;

  String get categoryLabel => templateCategories[category] ?? category;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'file': file,
    'width': width,
    'height': height,
    'unit': unit,
    'pages': pages,
    'license': license,
    'license_url': licenseUrl,
    'author': author,
    'version': version,
    'tags': tags,
    if (board) 'board': true,
  };

  /// Whether [query] matches the name, category or tags.
  bool matches(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'));
    final haystack =
        '${name.toLowerCase()} ${categoryLabel.toLowerCase()} '
        '${tags.join(' ')}';
    return words.every((w) => w.isEmpty || haystack.contains(w));
  }

  @override
  bool operator ==(Object other) => other is TemplateInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Parses a repository `index.json` (`{"templates": [...]}`).
List<TemplateInfo> parseTemplateIndex(Map<String, Object?> json) {
  final list = json['templates'];
  if (list is! List) throw const FormatException('template index: no list');
  final seen = <String>{};
  return [
    for (final entry in list)
      if (entry is Map<String, Object?>)
        if (TemplateInfo.fromJson(entry) case final info when seen.add(info.id))
          info,
  ];
}
