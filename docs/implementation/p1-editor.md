# Phase 1 editor and home (in progress)

> UI follows [design-system.md](../product/design-system.md) (Cobalt accent, neutral chrome, 28 px controls, fixed inspector section order).

Engineering log for the first usable editor. Normative design: [ux-spec.md](../product/ux-spec.md), [overview.md](../architecture/overview.md), [document-model.md](../architecture/document-model.md), [rendering-architecture.md](../architecture/rendering-architecture.md). Decisions: [ADR-0005](../adr/0005-riverpod-and-design-library.md), [ADR-0006](../adr/0006-invertible-changes-for-undo.md).

## What a user can do

- **First run (P1.1.7, part of P1.10.6):** welcome screen with the privacy promise; one click uses `Documents/OpenCanvasX` (created if missing) or picks any folder.
- **Home:** create from size presets or a custom size (P1.2.3), search and reopen designs from live thumbnails, change the projects folder, switch light/dark/system theme (P1.10.3).
- **Editor layout (P1.10.1):** toolbar (main menu with File/Edit/View/Insert/Arrange, tools Move · Shapes ▾ · Lines ▾ · Text · Hand, title + save state, undo/redo, zoom, theme), left sidebar (Layers tab: Pages + Layers; Elements tab: Text, Shapes, Lines), canvas, inspector (P1.10.2) in the order Alignment, Layout, Text, Appearance, Fill, Stroke.
- **Canvas (P1.2.1, P1.2.2, P1.2.5):** pages stacked vertically; wheel/trackpad pan, Ctrl+wheel zoom at cursor, middle-button or Space+drag pan, zoom slider and menu, fit page (Ctrl+0), 100 % (Ctrl+1).
- **Shapes (P1.3.1, P1.3.2):** rectangle, rounded rectangle, ellipse, polygon, star, line, arrow — draw with a tool (drag; Shift = square / 45°), click or drag from Elements, or the Insert menu. Tool shortcuts V, H, R, O, L, Shift+L, T.
- **Text (P1.5.1–P1.5.3):** heading/subheading/body from Elements or the Text tool (click to place); double-click or Enter edits inline; font, weight, size, italic, alignment, auto width / auto height / fixed, line height, letter spacing. Dragging a side handle of an auto-width text switches it to auto height.
- **Strokes (P1.3.5):** colour, weight, solid/dashed/dotted; opacity and blend mode in Appearance.
- **Templates (P2.2):** 24 original templates (social posts, stories, thumbnails, decks, poster, menu, flyer, business cards, resume, certificate, invitations, app screens and landing page boards). Home shows a gallery (search, categories) that creates a design; the editor's Design panel adds a template as new pages, or as frames on a board.
- **Home:** hero with search, quick kinds (free canvas, website & app, social, story, presentation, video, print, custom), templates, blank sizes, recent designs; sidebar Home · Templates · Your designs.
- **Layout (P1.10.1, design-system.md §5):** slim top bar with Export; 72 px content rail (Design, Elements, Text, Uploads, Layers, Pages) opening a 300 px panel; floating tool bar on the canvas.
- **Elements (P2.1.2):** shapes, lines, frame sizes, icons (Lucide, Tabler, Phosphor — pack and style filters) and stickers (Twemoji by category) with search; click to add or drag onto the canvas. Monochrome icons take the object's fill as their colour.
- **Uploads (P1.6.1, P1.6.2):** PNG, JPEG, WebP, GIF, BMP, SVG via the file dialog; validated by content (`asset_engine.checkMedia`), stored once per SHA-256 hash in the design, reusable from the panel. Placed images show their source and licence in the inspector (P2.1.4).
- **Export (P1.9):** Export button, File → Export…, Ctrl+Shift+E. PNG (0.5–4×, transparent option), JPG (quality), SVG (vector shapes/paths/frames with clip paths, text as text with the canvas's line breaks, images embedded, icon colour baked in), PDF (one file, every page or frame at its physical size; pages are rendered at 96/192/300 dpi — vector PDF is a later step). Scope: current page (on a board: each top-level frame), all pages, or the selection. Multiple files go to a chosen folder.
- **Boards and frames (ADR-0007, early P3.7.1):** "Free canvas" / "Website & app design" in the create dialog, or *Add board* in Pages, gives an unbounded board with a dot grid when zoomed in. The Frame tool (F) draws frames; its menu inserts device, social and slide sizes. Frames clip their content (toggle in the inspector's Frame section, which also changes the size), show their name above them (click to select, drag to move), and take in anything drawn, inserted or dropped on them; dragging out releases it. Ctrl+Alt+G frames the selection; Ungroup removes a frame. Fit (Ctrl+0) on a board fits its content.
- **Vector drawing (P2.6):** Pen (P): click to place points, drag to pull out smooth Bézier handles, click the first point to close, double-click, Enter or Escape to finish an open path; points snap. Pencil (Shift+P): freehand strokes simplified (Ramer–Douglas–Peucker) and smoothed into curves. Double-click a path to edit nodes: drag points or handles (opposite handle mirrors; Alt breaks the pair), Delete removes the selected point, Escape leaves. Paths store a view box so resizing scales their curves; strokes keep their width.
- **Snapping (P1.4.4):** moving snaps the selection's edges and centres to the page (fixed pages), other visible objects and enclosing frames within 6 screen pixels; resize handles and drawn shapes snap their edges the same way. Accent guide lines with end ticks show what snapped. Hold Alt to place freely. (A layout grid arrives with rulers/guides, P1.2.4.)
- **Distribute (P1.4.3):** equal spacing of 3+ elements horizontally or vertically.
- **Groups (P1.3.6):** Ctrl+G groups two or more siblings (the group box fits their bounds and takes the topmost member's stacking slot); Ctrl+Shift+G ungroups, folding the group's rotation, scale, opacity and visibility into the children so nothing moves. Groups nest. A click selects the top-level object; double-click enters a group (and a further double-click goes deeper or edits text); once inside, clicks pick siblings at the same depth and the entered group stays faintly outlined; Escape goes back up one level. Moves, nudges, align and distribute work in page units through any parent rotation/scale; copies and duplicates of nested objects land on the page as top-level objects in place. Resizing a group scales its contents (aspect locked; text sizes scale too). Layers show a tree: groups expand/collapse, open automatically around the selection, children are indented; only top-level rows are drag-reordered (arrange commands reorder nested objects among their siblings). Shift/Ctrl-click in Layers adds to the selection.
- **Context menu:** right-click on the canvas for clipboard and arrange commands.
- **Selection and transforms (P1.3.3, P1.3.4):** click, Shift+click, marquee; move (Shift constrains axis), 8 resize handles (Shift keeps ratio; rotated objects keep the opposite corner fixed), rotation handle (Shift snaps 15°), flip from the inspector, arrow-key nudge.
- **Inspector:** position, size with ratio lock, rotation, opacity, fill, border, corner radius, align (P1.4.2), arrange; page name, size, presets and background when nothing is selected.
- **Clipboard (P1.3.7):** cut, copy, paste, duplicate (Ctrl+X/C/V/D).
- **Layers (P1.4.1):** reorder by dragging, rename (double-click), hide, lock. Groups are not creatable yet (P1.3.6), so the list is flat.
- **Undo/redo (P1.8.1):** every edit, Ctrl+Z / Ctrl+Shift+Z / Ctrl+Y, labelled ("Undo move").
- **Saving:** automatic, 800 ms after the last edit, straight to the `.opencanvasx` file (atomic + verified); Ctrl+S saves immediately. Opening a design passed on the command line works (`opencanvasx.exe design.opencanvasx`).

## Code map

| Area | Location |
|------|----------|
| Geometry, presets | `packages/document_model/lib/src/geometry.dart`, `presets.dart` |
| Changes, history, edits, hit-testing, resize/rotate | `packages/design_engine/lib/src/` |
| Drawing | `packages/renderer/lib/src/` |
| App index settings, projects folder | `packages/storage/lib/src/app_index.dart`, `app_settings.dart`, `projects_location.dart` |
| Design system (tokens, light/dark themes) | `apps/desktop/lib/src/theme/ocx_theme.dart` |
| Home, welcome, create dialog | `apps/desktop/lib/src/home/` |
| Editor | `apps/desktop/lib/src/editor/` |

## Not done yet (still open in the checklist)

Vector PDF and WebP export (P1.9.2, P1.9.4), background export worker (P1.9.5), rulers/grid/guides (P1.2.4), snapping and smart guides (P1.4.4), character-level text formatting and local font discovery (P1.5.4–P1.5.6), images/SVG (P1.6), full colour picker and gradients (P1.7), history panel and checkpoints (P1.8.2–3), export (P1.9), shortcut customisation and command palette (P1.10.4–5), identity in onboarding (P1.10.6), offline/telemetry verification (P1.11).

## Testing

- `packages/design_engine`: changes, history, edits, scene queries, resize/rotate maths.
- `packages/renderer`: every object type paints; thumbnails; style resolution.
- `apps/desktop`: controller tests (`ProviderContainer`), viewport maths, and widget tests from first run through editing to going home, using an in-memory `DesignLibrary`.
- Visual review: real Windows build captured in light and dark themes.

Note: the first `dart test` / `flutter test` run downloads SQLite through the `sqlite3` build hook (hash-verified), so it needs network access once.
