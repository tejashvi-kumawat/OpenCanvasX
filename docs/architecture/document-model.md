# Document model

The document model is the **single in-memory source of truth** while the app is open. Save/export/collaboration all project from this structure. Implementation lives in `packages/document_model`.

## Design goals

- Stable **object ids** (UUIDs) for the lifetime of an object.
- **Tree + order**: layer hierarchy and z-order are explicit.
- **Serializable** to `.opencanvasx` with forward-compatible schema versions.
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

**Decided in [ADR-0003](../adr/0003-global-object-map.md):** one global object map. Root-level objects carry `page_id`; nested objects carry only `parent_id`. Exactly one of the two is set on every object.

## Page

| Field | Purpose |
|-------|---------|
| `id` | Page id (UUID v4) |
| `name` | User label (e.g. "Slide 3"); empty = UI shows page position |
| `width`, `height` | In `unit`; must be > 0 |
| `unit` | `px`, `pt`, `mm`, `cm`, `in` (default `px`) |
| `dpi` | Conversion for export; default 96 (CSS reference pixel) |
| `background` | Solid (default white), gradient (P1.7.3), image ref, or transparent |
| `bleed`, `margins` | Per-edge insets ≥ 0; margins must fit inside the page |
| `guides` | Vertical (fixed x) or horizontal (fixed y) lines; may sit outside the page |
| `object_ids` | Root objects on this page, back-to-front ([ADR-0003](../adr/0003-global-object-map.md)) |

**Units:** every length on a page — page size, insets, guides and the transforms of objects on it — is expressed in the page's `unit`. Physical units convert with fixed ratios (1 in = 72 pt = 25.4 mm = 2.54 cm); `px` converts through the page `dpi`. Raster export size is the page size in inches × export DPI, rounded to whole pixels.

Supports **fixed page** mode first; infinite canvas (whiteboard) extends page bounds and pan limits later.

## Object types (phased)

**Phase 1:** `text`, `rect`, `rounded_rect`, `ellipse`, `line`, `arrow`, `path`, `image`, `group`.

**Later:** `chart`, `table`, `frame`, `component`, `svg`, `video`, `audio`, `qr`, `barcode`, `embedded_document`.

Each object carries:

| Field | Purpose |
|-------|---------|
| `id` | Stable UUID v4 |
| `type` | Discriminator |
| `page_id` | Page of a root object (`null` when nested) |
| `parent_id` | Layer tree parent (`null` = page root) |
| `child_ids` | Ordered children, groups only, back-to-front (index 0 drawn first) |
| `name` | Optional user layer name (`null` = UI default label) |
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
- **Anchor** `(anchor_x, anchor_y)` in 0–1 local space (default `0.5, 0.5`, the centre)
- **Flip** is a negative `scale_x` / `scale_y`; zero scale is invalid
- `width` and `height` may be `0` (e.g. a horizontal line) but never negative

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

Command stack holds inverse operations — implemented as data-level `Change`s whose application yields their own inverse ([ADR-0006](../adr/0006-invertible-changes-for-undo.md), `design_engine`). Checkpoints (named snapshots) are full document clones or serialized snapshots in `storage` — not the same as undo stack.

## Collaboration mapping

Local commands generate **operations** with new ids:

- `ObjectCreated`, `ObjectUpdated`, `ObjectDeleted`, `ParentChanged`, `PageAdded`, …
- Text edits use a dedicated text CRDT or op stream (decision in [crdt-spec.md](../protocol/crdt-spec.md)).

The document model applies remote ops through the same validation paths as local commands.

## Implementation (`packages/document_model`)

| Concept | Dart type | Since |
|---------|-----------|-------|
| Object / page ids | `ObjectId`, `PageId` (extension types over `String`; `.generate()` makes UUID v4) | P1.1.1 |
| Object | `DesignObject` (validates its own invariants; `copyWith` can clear nullable fields) | P1.1.1 |
| Kind / blend | `ObjectType`, `ObjectBlendMode` | P1.1.1 |
| Transform | `ObjectTransform` | P1.1.1 |
| Style | `ObjectStyle` (`SolidFill`, `Stroke`, `cornerRadius`); gradients P1.7.3, dashes P1.3.5 | P1.1.1 |
| Payload | `NoPayload`, `TextPayload` (plain text until P1.5), `ImagePayload` (SHA-256 hex), `PathPayload` (`MoveTo`, `LineTo`, `QuadTo`, `CubicTo`, `ClosePath` in object-local coordinates) | P1.1.1 |
| Colour | `ArgbColor` (`0xAARRGGBB`, pure Dart, no `dart:ui`) | P1.1.1 |
| Tree checks | `validateObjectGraph` → `List<ModelIssue>` | P1.1.1 |
| Page | `DesignPage`, `PageInsets`, `Guide` / `GuideAxis`, `PageBackground` (`SolidBackground`, `TransparentBackground`, `ImageBackground`) | P1.1.2 |
| Unit | `LengthUnit` (symbols, `fromSymbol`) | P1.1.2 |
| Conversion | `convertLength`, `defaultDpi`, `DesignPage.sizeIn`, `DesignPage.pixelSizeAt` | P1.1.3 |
| Page checks | `validatePages` → `List<ModelIssue>` | P1.1.2 |

All types are immutable values with value equality. Constructors throw `ArgumentError` for invalid input (non-finite numbers, negative sizes, payload not matching type, …). Cross-object problems are reported by validators, not thrown, so a damaged file can be repaired rather than rejected outright.

## Related

- [ADR-0003](../adr/0003-global-object-map.md) — global object map and ordering
- [file-format.md](file-format.md) — on-disk encoding
- [rendering-architecture.md](rendering-architecture.md) — how objects become pixels
- [export-architecture.md](export-architecture.md) — export walk of the tree
