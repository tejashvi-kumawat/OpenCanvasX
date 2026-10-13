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
| `author` | string | no | Display name only (`DocumentMetadata.author`) |
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

Encoding rules (schema version 1, implemented in `document_model/lib/src/document_json.dart`):

| Value | Encoding | Example |
|-------|----------|---------|
| Enum values | snake_case names | `"type": "rounded_rect"`, `"blend_mode": "color_dodge"` |
| Units | `LengthUnit.symbol` | `"unit": "in"` |
| Colours | CSS hex `#rrggbbaa` (writer); `#rrggbb` also accepted as opaque | `"#11223380"` |
| Page `background` | `{ "type": "solid", "color" }`, `{ "type": "transparent" }`, `{ "type": "image", "asset" }` | |
| Insets | `{ "top", "right", "bottom", "left" }` | |
| Object `transform` | `{ x, y, width, height, rotation, scale_x, scale_y, anchor_x, anchor_y }` | |
| Object `payload` | text `{ "text" }`, image `{ "asset" }`, path `{ "segments": [["M",x,y], ["L",x,y], ["Q",cx,cy,x,y], ["C",c1x,c1y,c2x,c2y,x,y], ["Z"]] }`; omitted for shapes and groups | |
| Object id | key in `objects`; not repeated inside the object | |
| Text payload | `{ text, font_family?, font_size, font_weight, italic?, align, line_height, letter_spacing, sizing }`; `align` ∈ left/center/right/justify, `sizing` ∈ auto_width/auto_height/fixed | `"sizing": "auto_height"` |
| Polygon / star payload | `{ "sides" }` / `{ "points", "inner_ratio" }` | `{"points": 5, "inner_ratio": 0.5}` |
| Stroke | `{ color, width, dash? }`; `dash` ∈ dashed/dotted, omitted for solid | |
| Page kind | `kind: "board"` for unbounded boards; omitted for fixed pages (schema 2) | `"kind": "board"` |
| Frame payload | `{ clip_content, component? }` (schema 2); `component: true` marks a main component | `{"clip_content": true}` |
| Image payload | `{ asset, adjust?, crop? }`; `crop` is `[left, top, right, bottom]` as fractions of the image (omitted when the whole image shows; P1.6.3); `adjust` holds non-zero values of brightness, contrast, saturation, exposure, temperature, tint (−100…100), hue (−180…180), grayscale, sepia, blur (0…100) | `{"asset": "…", "adjust": {"saturation": -100}}` |
| Mask group | group payload `{ mask: true }`: the first child clips the others | |
| Instance payload | `{ component }` — id of a component frame; drawn scaled to the instance box | `{"component": "card"}` |
| Fill | `{type: "solid", color}`, `{type: "linear", angle, stops: [{offset, color}]}` (angle in degrees, 0 = left→right) or `{type: "radial", center_x, center_y, radius, stops}` (fractions of the box) | `{"type":"linear","angle":90,"stops":[{"offset":0,"color":"#ff0000ff"},{"offset":1,"color":"#0000ffff"}]}` |
| Prototype links | `pages[].links: [{source, target, transition}]`; `transition` ∈ instant, dissolve, slide_left, slide_right, slide_up; one link per source | `{"source": "btn", "target": "frame2", "transition": "dissolve"}` |
| Path payload | `{ segments, view_width?, view_height? }`; segments `["M",x,y]`, `["L",x,y]`, `["Q",cx,cy,x,y]`, `["C",c1x,c1y,c2x,c2y,x,y]`, `["Z"]`; with a view box the path is scaled from it to the object's box | `{"segments": [["M",0,0],["L",10,0]], "view_width": 10, "view_height": 1}` |

Optional fields fall back to the model defaults (opacity `1`, anchor `0.5`, dpi `96`, white background, …). Unknown keys are ignored so minor additions stay readable by older builds; anything that changes meaning bumps `schema_version`.

## Assets

- Referenced by **SHA-256** of raw bytes.
- Deduplicated: one file per hash under `assets/sha256/`.
- Missing asset on open: block export of that object and show repair UI (relink or placeholder).
- On open, every present asset is re-hashed and its length checked against `asset_index`; a mismatch rejects the file as corrupt or modified.
- On save, only assets listed in `asset_index` are written, and bytes must hash to their key.

## Fonts

`fonts.json` lists families used in the document (written as `{ "families": [] }` until fonts land in P1.5) and whether they were embedded (only when license permits). Binaries, if embedded, live under `assets/` like any other blob.

## Migration

Implemented by `SchemaMigrator` (`document_model/lib/src/migration.dart`); `documentMigrator` holds the registered steps.

1. On open: if `schema_version` < current, run sequential migrators `v → v+1`.
2. If `schema_version` > supported: fail with clear message (forward incompatibility).
3. Migrators live in `document_model` with tests per step.
4. Save always writes latest supported schema.

## Version history and sync

- **Local snapshots**: copies under project `snapshots/` or user backup dir ([storage-architecture.md](storage-architecture.md)).
- **External sync** (Syncthing, Git, WebDAV): user-managed; app detects divergent copies and offers keep-both, never silent overwrite.

## Security

Treat files from others as untrusted: size limits, schema validation, no code execution from JSON.

Opening (`storage/lib/src/project_archive.dart`, `decodeProject`) enforces, with defaults in `ArchiveLimits`:

| Check | Default |
|-------|---------|
| File size | 1 GiB |
| Number of ZIP entries | 20,000 |
| Declared uncompressed size per entry | 512 MiB (actual size must match) |
| Total declared uncompressed size | 2 GiB |
| `manifest.json` / `document.json` size | 64 MiB each |
| Entry name | relative, `/`-separated, no `..`, `.`, `\`, `:`, at most 8 segments |
| Symbolic links | rejected |
| Duplicate entry names | rejected |

Malformed content raises `FormatException` naming the JSON path (e.g. `document.objects.<id>.transform`); a newer `format_version` major or `schema_version` raises `UnsupportedVersionException` with a "needs a newer version of OpenCanvasX" message. Broken cross-references (missing parent, unknown style, missing asset bytes) are returned for repair UI instead of failing the open. Templates use the same container format with stricter schema (declarative only).

## Related

- [document-model.md](document-model.md)
- [asset-architecture.md](asset-architecture.md)
