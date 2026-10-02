# Document model

The document model is the **single in-memory source of truth** while the app is open. Save/export/collaboration all project from this structure. Implementation lives in `packages/document_model`.

## Design goals

- Stable **object ids** (UUIDs) for the lifetime of an object.
- **Tree + order**: layer hierarchy and z-order are explicit.
- **Serializable** to `.designstudio` with forward-compatible schema versions.
- **Command-friendly**: every user edit maps to reversible commands for undo.
- **CRDT-ready**: geometric and structural edits decompose into operations (Phase 4).

## Top-level document

| Field | Purpose |
|-------|---------|
| `document_id` | Stable id for the design (independent of file path) |
| `schema_version` | Integer for migration |
| `metadata` | Title, author display name, created/modified hints |
| `pages` | Ordered list of pages |
| `objects` | Map of id → object (flat store; tree via `parent_id`) |
| `styles` | Shared fills, strokes, text styles |
| `assets` | Map of hash → asset reference (bytes on disk) |

Pages may share a global object map or partition by page — **pick one in Phase 1 and document in an ADR**. Recommendation: one global map with `page_id` on root-level objects for simpler multi-page drag.

## Page

| Field | Purpose |
|-------|---------|
| `id` | Page id |
| `name` | User label (e.g. "Slide 3") |
| `width`, `height` | In document units |
| `unit` | `px`, `pt`, `mm`, `cm`, `in` |
| `dpi` | Conversion for export |
| `background` | Solid, gradient, image ref, or transparent |
| `bleed`, `margins`, `guides` | Print/layout aids |

Supports **fixed page** mode first; infinite canvas (whiteboard) extends page bounds and pan limits later.

## Object types (phased)

**Phase 1:** `text`, `rect`, `rounded_rect`, `ellipse`, `line`, `arrow`, `path`, `image`, `group`.

**Later:** `chart`, `table`, `frame`, `component`, `svg`, `video`, `audio`, `qr`, `barcode`, `embedded_document`.

Each object carries:

| Field | Purpose |
|-------|---------|
| `type` | Discriminator |
| `parent_id` | Layer tree parent (`null` = page root) |
| `child_ids` | Optional ordered children (groups) |
| `transform` | See below |
| `opacity` | 0–1 |
| `blend_mode` | Normal, multiply, … |
| `locked`, `hidden` | UI state |
| `style_id` or inline `style` | Visual appearance |
| `payload` | Type-specific (text content, image hash, path data) |

## Transform

Stored as:

- Position `x`, `y` (parent space)
- Size `width`, `height`
- Rotation (degrees)
- Scale `scale_x`, `scale_y` (default 1)
- Skew optional (post-MVP)
- **Anchor** `(anchor_x, anchor_y)` in 0–1 local space

Apply order for rendering and export must match: **translate → rotate → scale → skew** around anchor. `design_engine` and `renderer` share one module for matrix composition.

## Text

Rich text is a structured tree (paragraphs, spans) with character and paragraph attributes. Font resolution uses `typography` (local fonts, fallbacks). OpenType features optional later.

## Vector geometry

Paths use SVG-compatible segment lists (m/l/c/q/z). Boolean ops and offset path are document mutations producing new path objects (Post-MVP).

## Styles

Named styles enable brand kits and templates. Objects may reference `style_id` and override fields. Style records hold fill, stroke, corner radius, shadow, text defaults.

## Selection and hit-testing

`design_engine` maintains ephemeral selection state (not serialized). Hit order: topmost visible unlocked object in z-order.

## Undo / redo

Command stack holds inverse operations. Checkpoints (named snapshots) are full document clones or serialized snapshots in `storage` — not the same as undo stack.

## Collaboration mapping

Local commands generate **operations** with new ids:

- `ObjectCreated`, `ObjectUpdated`, `ObjectDeleted`, `ParentChanged`, `PageAdded`, …
- Text edits use a dedicated text CRDT or op stream (decision in [crdt-spec.md](../protocol/crdt-spec.md)).

The document model applies remote ops through the same validation paths as local commands.

## Related

- [file-format.md](file-format.md) — on-disk encoding
- [rendering-architecture.md](rendering-architecture.md) — how objects become pixels
- [export-architecture.md](export-architecture.md) — export walk of the tree
