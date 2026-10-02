# Asset architecture

Assets are binary media (photos, icons, SVGs, patterns, audio, video) referenced by hash from the document. Package: `packages/asset_engine`.

## Metadata model

Every cataloged asset should carry:

| Field | Purpose |
|-------|---------|
| `id` | Internal catalog id (may equal hash) |
| `sha256` | Content address |
| `mime` | Type |
| `width`, `height` | If raster/vector known |
| `source` | URL, user upload, bundled pack id |
| `author` | Attribution |
| `license` | SPDX or custom enum |
| `license_url` | Link to license text |
| `attribution_required` | bool |
| `tags`, `categories` | Search |

Bundled and community assets **must** have license fields before redistribution.

## Import validation

Treat all imports as hostile:

- Size caps (configurable)
- SVG: strip scripts, external entities, `javascript:` URLs
- Raster: decode headers only first; full decode in sandboxed isolate
- Archive expansion limits if importing zip packs

Align with [input-validation-policy.md](../security/input-validation-policy.md).

## Library UI

Panels search local index (SQLite FTS + tags). Drag-drop onto canvas creates `image` or `svg` object with asset hash reference.

## Collaboration

Peers exchange bytes by hash: if receiver already has hash, skip transfer; else encrypted chunked upload. See [sync-spec.md](../protocol/sync-spec.md).

## User uploads

Stored in project asset store; license assumed user-owned unless user tags otherwise.

## Related

- [storage-architecture.md](storage-architecture.md)
- [file-format.md](file-format.md)
