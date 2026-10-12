# Rendering architecture

Rendering turns the **document model** into pixels on screen and into vector/raster pipelines for export. Primary implementation: `packages/renderer`, driven by Flutter/Skia.

## Principles

- **Vector-first** where the model is vector (paths, text, shapes). Rasterize images and effects deliberately.
- **Incremental redraw**: only dirty regions after edits.
- **Same geometry for screen and export** unless export explicitly chooses rasterization (e.g. PNG at DPI).

## Scene graph

Build each frame:

1. Resolve page visibility and viewport (pan/zoom).
2. Walk layer tree depth-first; apply transforms cumulatively.
3. Expand component instances if present (later).
4. Produce ordered **draw commands** (fill path, stroke path, draw image, clip, opacity, blend).

Masks and clips push a stack; blend modes apply per object or group.

## Viewport and tiles

For large pages or zoomed views:

- Partition page space into **tiles** (e.g. 512×512 document units).
- Assign objects to tiles by bounds overlap.
- Cache rasterized tile content keyed by `(page_id, zoom_bucket, tile_x, tile_y, content_hash)`.

Invalidate tiles when any overlapping object changes.

## Images

- Decode asynchronously; show low-res placeholder until ready.
- Mipmap or downscaled cache for zoomed-out views.
- GPU textures where backend allows.

## Text

Shape text through Skia/harfbuzz stack (Flutter paragraph API or lower-level binding). Missing glyphs use fallback chain from `typography`.

## Performance tactics

| Technique | When |
|-----------|------|
| Object culling | Off-screen objects skip draw |
| Layer isolation | Cache static groups to texture until edited |
| Thumbnail decimation | Pages panel uses reduced preview |
| Background isolate | Heavy decode/export off UI thread |

## GPU vs CPU

Prefer GPU path for transformed images and large fills. CPU fallback must remain correct on software-only backends.

## Export coupling

Export reuses scene traversal with a different **backend**:

- SVG backend emits DOM elements.
- PDF backend emits vector operators (via chosen PDF library).
- Raster backend allocates bitmap at target DPI.

See [export-architecture.md](export-architecture.md).

## Implementation status (Phase 1)

- `packages/renderer` (Flutter package): `paintPageBackground`, `paintPageContent` and `paintObject` draw any page in page units using `localToParent` matrices from `document_model` — the same matrices `design_engine` uses for hit-testing, so screen and export geometry agree. Opacity and blend modes use layers; shared styles resolve through `effectiveStyle`.
- `PageThumbnailPainter` draws a page scaled into any box (home cards, page strip).
- The editor canvas (`apps/desktop/lib/src/editor/canvas_view.dart`) lays pages out vertically in **workspace pixels at 96 per inch**, so mm/in pages appear at physical size at 100 % zoom; `screen = workspace × zoom + pan`. Off-screen pages are culled.
- Text renders as plain paragraphs and images as placeholders until P1.5 / P1.6. Tiles, caches and background isolates (P3.10) are not implemented yet.

## Related

- [performance-budget.md](performance-budget.md)
- [document-model.md](document-model.md)
