# Phase 1 editor and home (in progress)

Engineering log for the first usable editor. Normative design: [ux-spec.md](../product/ux-spec.md), [overview.md](../architecture/overview.md), [document-model.md](../architecture/document-model.md), [rendering-architecture.md](../architecture/rendering-architecture.md). Decisions: [ADR-0005](../adr/0005-riverpod-and-design-library.md), [ADR-0006](../adr/0006-invertible-changes-for-undo.md).

## What a user can do

- **First run (P1.1.7, part of P1.10.6):** welcome screen with the privacy promise; one click uses `Documents/OpenCanvasX` (created if missing) or picks any folder.
- **Home:** create from size presets or a custom size (P1.2.3), search and reopen designs from live thumbnails, change the projects folder, switch light/dark/system theme (P1.10.3).
- **Editor layout (P1.10.1):** top bar (menus File/Edit/View/Insert/Arrange, undo/redo, save status, editable title), left rail with Elements / Layers / Pages panels, canvas, right inspector (P1.10.2), bottom bar (pages, zoom).
- **Canvas (P1.2.1, P1.2.2, P1.2.5):** pages stacked vertically; wheel/trackpad pan, Ctrl+wheel zoom at cursor, middle-button or Space+drag pan, zoom slider and menu, fit page (Ctrl+0), 100 % (Ctrl+1).
- **Shapes (P1.3.1):** rectangle, rounded rectangle, circle/ellipse, line, arrow — click or drag from Elements, or the Insert menu.
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

Rulers/grid/guides (P1.2.4), polygon/star (P1.3.2), dashed strokes (P1.3.5), groups (P1.3.6), distribute and snapping (P1.4.3, P1.4.4), text (P1.5), images/SVG (P1.6), full colour picker and gradients (P1.7), history panel and checkpoints (P1.8.2–3), export (P1.9), shortcut customisation and command palette (P1.10.4–5), identity in onboarding (P1.10.6), offline/telemetry verification (P1.11).

## Testing

- `packages/design_engine`: changes, history, edits, scene queries, resize/rotate maths.
- `packages/renderer`: every object type paints; thumbnails; style resolution.
- `apps/desktop`: controller tests (`ProviderContainer`), viewport maths, and widget tests from first run through editing to going home, using an in-memory `DesignLibrary`.
- Visual review: real Windows build captured in light and dark themes.

Note: the first `dart test` / `flutter test` run downloads SQLite through the `sqlite3` build hook (hash-verified), so it needs network access once.
