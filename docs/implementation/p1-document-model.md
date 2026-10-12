# Phase 1.1 document model (in progress)

Engineering log for checklist section P1.1. Normative design: [document-model.md](../architecture/document-model.md), [ADR-0003](../adr/0003-global-object-map.md).

## P1.1.1 Object model

- `packages/document_model/lib/src/`: `ids.dart`, `design_object.dart`, `transform.dart`, `style.dart`, `color.dart`, `payload.dart`, `object_type.dart`, `object_graph.dart`, `model_issue.dart`.
- Pure Dart (no Flutter), so it is testable with `dart test` and usable from isolates.
- New dependency: `meta` (BSD-3-Clause) for `@immutable`, required by the `very_good_analysis` lint set when overriding `==`.
- Not yet: serialization (P1.1.4), polygon/star types (P1.3.2), rich text (P1.5), gradients (P1.7.3).

## P1.1.2 Page model

- `lib/src/page.dart` (`DesignPage`, `PageInsets`, `Guide`, `PageBackground`), `lib/src/units.dart` (`LengthUnit`), `lib/src/page_graph.dart` (`validatePages`).
- Pages own the back-to-front order of their root objects (`objectIds`), per ADR-0003.
- Not yet: gradient backgrounds (P1.7.3), size presets (P1.2.3).

## P1.1.3 Units and DPI

- `lib/src/units.dart`: `convertLength`, `LengthUnit.inchesPerUnit`, `LengthUnit.fromSymbol`, top-level `defaultDpi` (96).
- `DesignPage.sizeIn(unit)` and `DesignPage.pixelSizeAt(exportDpi)` (whole pixels, minimum 1×1) for the inspector and raster export (P1.9.1).
- Rule recorded in document-model.md: all lengths on a page use the page's unit.

## P1.1.4 Serialization and migrations

- `document_model`: `DesignDocument` (+ `DocumentMetadata`, `AssetInfo`, `DocumentId`) with `validate()`; `document_json.dart` (`encodeManifest`, `encodeDocumentBody`, `decodeDocument`, `currentFormatVersion` 1.0.0, `currentSchemaVersion` 1); `migration.dart` (`SchemaMigrator`, `UnsupportedVersionException`).
- `storage`: `project_archive.dart` (`encodeProject`, `decodeProject`, `ArchiveLimits`, `ProjectContents`, `projectFileExtension`, `sha256Hex`).
- Encoding rules and opening limits are recorded in [file-format.md](../architecture/file-format.md).
- New dependencies: `archive` (MIT) for ZIP, `crypto` (BSD-3-Clause) for SHA-256.
- Note: `package:archive` writes every entry as "made by MS-DOS" and normalises `\` to `/` on write only; tests patch raw bytes to simulate hostile ZIPs from other tools.

## P1.1.5 Save, open, autosave

- `storage/lib/src/project_file.dart`: `writeProjectFile` (atomic + verified), `readProjectFile`, `saveProject`, `openProject` (crash recovery, `newerAutosaveAvailable`), `Autosaver` (debounced, non-overlapping), `autosavePathFor`.
- Behaviour table in [storage-architecture.md](../architecture/storage-architecture.md#autosave).
- UI wiring (dialogs, "restore unsaved changes?" prompt) lands with the app shell (P1.10).

## Commands

```bash
cd packages/document_model   # or packages/storage
dart analyze
dart test
```
