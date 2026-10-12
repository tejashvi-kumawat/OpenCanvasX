/// Upgrades a decoded `document.json` map from one schema version to the
/// next. Receives a mutable copy; returns the upgraded map.
typedef SchemaMigration =
    Map<String, Object?> Function(Map<String, Object?> document);

/// Thrown when a file was written by a newer OpenCanvasX than this build
/// supports (file-format.md "Migration", step 2).
final class UnsupportedVersionException implements Exception {
  const UnsupportedVersionException(this.found, this.supported);

  final Object found;
  final Object supported;

  @override
  String toString() =>
      'This file needs a newer version of OpenCanvasX '
      '(file version $found, this build supports up to $supported).';
}

/// Runs sequential `v → v+1` migrations up to [currentVersion].
final class SchemaMigrator {
  SchemaMigrator({
    required this.currentVersion,
    Map<int, SchemaMigration> steps = const {},
  }) : _steps = Map.unmodifiable(steps) {
    if (currentVersion < 1) {
      throw ArgumentError.value(
        currentVersion,
        'currentVersion',
        'must be >= 1',
      );
    }
  }

  final int currentVersion;

  /// `steps[v]` upgrades a version `v` document to `v + 1`.
  final Map<int, SchemaMigration> _steps;

  Map<String, Object?> migrate(Map<String, Object?> document) {
    final found = document['schema_version'];
    if (found is! int || found < 1) {
      throw FormatException('schema_version must be a positive integer', found);
    }
    if (found > currentVersion) {
      throw UnsupportedVersionException(found, currentVersion);
    }
    var version = found;
    var current = document;
    while (version < currentVersion) {
      final step = _steps[version];
      if (step == null) {
        throw StateError('No migration from schema version $version');
      }
      current = step(Map.of(current));
      version++;
      current['schema_version'] = version;
    }
    return current;
  }
}
