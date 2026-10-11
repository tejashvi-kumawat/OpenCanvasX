# Phase 1.1 document model (in progress)

Engineering log for checklist section P1.1. Normative design: [document-model.md](../architecture/document-model.md), [ADR-0003](../adr/0003-global-object-map.md).

## P1.1.1 Object model

- `packages/document_model/lib/src/`: `ids.dart`, `design_object.dart`, `transform.dart`, `style.dart`, `color.dart`, `payload.dart`, `object_type.dart`, `object_graph.dart`, `model_issue.dart`.
- Pure Dart (no Flutter), so it is testable with `dart test` and usable from isolates.
- New dependency: `meta` (BSD-3-Clause) for `@immutable`, required by the `very_good_analysis` lint set when overriding `==`.
- Not yet: serialization (P1.1.4), polygon/star types (P1.3.2), rich text (P1.5), gradients (P1.7.3).

## Commands

```bash
cd packages/document_model
dart analyze
dart test
```
