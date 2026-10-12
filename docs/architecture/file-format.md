# `.opencanvasx` file format

The native project format is **open, documented, and versioned**. Files use extension `.opencanvasx`. Human editing is possible (unzip + JSON); the app is the primary editor.

## Container

Default: **ZIP** archive with UTF-8 JSON members and binary asset blobs.

Optional developer mode: loose folder with same layout (for git-friendly workflows).

```
manifest.json
document.json
fonts.json
assets/sha256/<hex>    # raw bytes, immutable
meta/thumbnails/       # optional cache
snapshots/             # optional named checkpoints
```

Do **not** store API keys, passwords, private keys, or raw BYOK tokens in any member file.

## `manifest.json`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `format_version` | string | yes | Semver of container spec (start `1.0.0`) |
| `document_id` | string | yes | UUID |
| `title` | string | yes | Display name |
| `app_version_saved` | string | no | App build that last saved |
| `created_at` | string | no | ISO 8601 |
| `modified_at` | string | no | ISO 8601 |

## `document.json`

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Migration counter (start `1`) |
| `pages` | array | Page records |
| `objects` | object | id → object |
| `styles` | object | id → style |
| `asset_index` | object | hash → `{ mime, byte_length, license_ref? }` |

Collaboration state is **not** required in the file for single-user save. Optional `collaboration_hint.json` may list public session metadata only (no secrets).

## Object encoding

Same logical model as [document-model.md](document-model.md). JSON keys are **snake_case** everywhere ([ADR-0004](../adr/0004-rename-to-opencanvasx.md)); never mix styles.

Binary-heavy fields (compressed path data, large text) may move to sidecar files referenced by id in a future schema version.

## Assets

- Referenced by **SHA-256** of raw bytes.
- Deduplicated: one file per hash under `assets/sha256/`.
- Missing asset on open: block export of that object and show repair UI (relink or placeholder).

## Fonts

`fonts.json` lists families used in the document and whether they were embedded (only when license permits). Binaries, if embedded, live under `assets/` like any other blob.

## Migration

1. On open: if `schema_version` < current, run sequential migrators `v → v+1`.
2. If `schema_version` > supported: fail with clear message (forward incompatibility).
3. Migrators live in `document_model` with tests per step.
4. Save always writes latest supported schema.

## Version history and sync

- **Local snapshots**: copies under project `snapshots/` or user backup dir ([storage-architecture.md](storage-architecture.md)).
- **External sync** (Syncthing, Git, WebDAV): user-managed; app detects divergent copies and offers keep-both, never silent overwrite.

## Security

Treat files from others as untrusted: size limits, schema validation, no code execution from JSON. Templates use the same container format with stricter schema (declarative only).

## Related

- [document-model.md](document-model.md)
- [asset-architecture.md](asset-architecture.md)
