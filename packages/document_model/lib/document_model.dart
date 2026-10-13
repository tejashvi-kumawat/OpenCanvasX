/// OpenCanvasX — `document_model` package: the in-memory design document.
///
/// See docs/architecture/document-model.md and ADR-0003.
library;

export 'src/color.dart';
export 'src/color_matrix.dart';
export 'src/design_object.dart';
export 'src/document.dart';
export 'src/document_json.dart';
export 'src/geometry.dart';
export 'src/ids.dart';
export 'src/migration.dart';
export 'src/model_issue.dart';
export 'src/object_graph.dart';
export 'src/object_type.dart';
export 'src/page.dart';
export 'src/page_graph.dart';
export 'src/payload.dart';
export 'src/presets.dart';
export 'src/prototype.dart';
export 'src/style.dart';
export 'src/text_runs.dart';
export 'src/transform.dart';
export 'src/units.dart';

/// Package version.
String packageVersion() => '0.0.1';
