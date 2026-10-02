# Architecture overview

Open Design Studio is a **local-first desktop application**: the canonical design lives in files on disk, edited through a Flutter UI, with optional P2P collaboration and optional BYOK AI. No vendor cloud is required for core editing.

## Layered structure

```
┌─────────────────────────────────────────────────────────┐
│  apps/desktop (Flutter UI, panels, commands, shortcuts) │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  Application services (orchestration, undo, selection)    │
│  packages/design_engine                                   │
└───────────────────────────┬─────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
 document_model        renderer           template_engine
 asset_engine          typography         export_engine / pdf_engine
 media_engine          search             storage
        │                   │                   │
        └───────────────────┼───────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
 collaboration         ai_engine / agents    plugins_sdk
 crdt                  identity              crypto_engine
 networking
        │
        ▼
 rust/ods_native (hot paths, future: crypto, decode, CRDT helpers)
        │
        ▼
 OS: filesystem, SQLite, secure enclave, GPU
```

## Engine responsibilities

| Layer | Package(s) | Role |
|-------|------------|------|
| Document truth | `document_model` | Pages, objects, styles, IDs, serialization |
| Editing | `design_engine` | Tools, transforms, snapping, command stack |
| Drawing | `renderer` | Scene graph → display list → GPU/Skia |
| Files | `storage` | Project index, asset blobs, snapshots |
| Templates & brand | `template_engine` | Template format, apply, resize rules |
| Media library | `asset_engine` | Metadata, license fields, import validation |
| Export | `export_engine`, `pdf_engine` | PNG, SVG, PDF pipelines |
| Collab | `collaboration`, `crdt`, `crypto_engine`, `networking`, `identity` | Sessions, ops, E2E crypto |
| AI | `ai_engine`, `agents` | Providers, tools, sandbox |
| Extensions | `plugins_sdk` | Third-party importers, exporters, tools |

## Data flow (single-user edit)

1. UI dispatches a **command** (e.g. move selection).
2. `design_engine` validates and applies it to the **in-memory document** (`document_model`).
3. `renderer` marks dirty regions and repaints.
4. **Autosave** serializes to `.designstudio` via `document_model` + `storage`.
5. **Export** walks the same document through `export_engine` without mutating source.

Collaboration adds an **operation log** merged by `crdt` instead of replacing step 4 with a server sync. See [protocol docs](../protocol/protocol-layers.md).

## Repository layout

Monorepo root (this project: `OpenCanvasX/`):

- `apps/desktop` — Flutter shell
- `packages/*` — Dart libraries above
- `rust/ods_native` — Rust FFI surface
- `protocols/` — machine-readable protocol artifacts (Phase 4+)
- `docs/architecture/` — **this folder** (hand-maintained)

## Related documents

- [tech-stack-decision.md](tech-stack-decision.md)
- [document-model.md](document-model.md)
- [file-format.md](file-format.md)
- [performance-budget.md](performance-budget.md)
