# Extensibility APIs

Stable surfaces for core, plugins, and (eventually) scripting. Version each API independently of app marketing version.

## Document model API

- Read/write through **commands** (not public mutable graph) to keep undo/collab consistent.
- Query: object by id, selection, page list, bounds.
- Events: `DocumentChanged`, `SelectionChanged` (streams for UI).

## Renderer API

- Register custom **object renderers** for plugin types (later).
- Hooks: `paintObject`, `hitTest` for extension types.

## Importer / exporter API

```text
bool canImport(String mime, String ext);
ImportResult import(bytes|path, ImportContext ctx);
ExportResult export(Document doc, ExportOptions opts);
```

Register in plugin manifest.

## AI provider API

Implement `AiProvider` (see [ai-architecture.md](ai-architecture.md)); register in settings.

## Asset / template provider API

- `listAssets()`, `resolve(hash|url)` for remote repos.
- `listTemplates()`, `fetchTemplate(id)` for repository indices.

## Collaboration protocol API

Phase 4+: expose session join, op submission, presence for advanced integrations (e.g. custom relay). Binary protocol specs live under `protocols/` and [../protocol/](../protocol/protocol-layers.md).

## Stability policy

- Breaking API changes bump major plugin API version.
- Document model schema bumps follow [file-format.md](file-format.md) migration rules.
- Deprecations supported for at least one minor release with console/log warning.

## Related

- [plugin-architecture.md](plugin-architecture.md)
- [overview.md](overview.md)
