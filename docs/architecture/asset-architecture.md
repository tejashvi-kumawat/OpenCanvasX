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

## Bundled packs (P2.1.7)

Packs ship in the Flutter package `packages/asset_packs` (Flutter can only bundle files inside a package): `assets/packs/index.json` lists them; each `assets/packs/<id>/` holds `pack.json`, `LICENSE` and `svg/`. `pack.json` carries the licence fields above at pack level (`license`, `license_url`, `author`, `source`, `attribution_required`, `attribution`, `redistribution`, `modification`, `recolorable`) and per item `id`, `name`, `file`, `sha256`, `mime`, `tags`, `category`, optional `style`. `asset_engine`'s `AssetPack.fromJson` rejects packs with missing licence metadata, missing attribution text, non-redistributable terms or unsafe paths (P2.1.5); a test hashes and validates the bundled files.

`scripts/asset_packs/build_packs.py fetch` downloads pinned upstream archives into `.cache/asset_packs` (git-ignored); `curate` validates every SVG (no scripts, handlers, external references, entities, foreign content) and writes the packs. Current packs: Lucide (ISC), Tabler (MIT), Phosphor (MIT; regular/fill/duotone), Twemoji (CC-BY 4.0, attribution shown). The same script curates 20 OFL Google Fonts families into `assets/fonts/` once fetched. Recolourable packs draw in `currentColor`; a placed icon's fill colour becomes its `currentColor`.

Excluded on licence grounds: unDraw, Blush, Unsplash, Pexels, Pixabay, Freepik, DrawKit, Icons8, Reshot (no-redistribution or no-competing-service clauses); OpenMoji pending a share-alike decision.

## Import validation

Treat all imports as hostile (implemented in `asset_engine` `checkMedia`: type from magic bytes, never the file name; size from headers only; 50 MB / 5 MB SVG / 16384 px caps):

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
