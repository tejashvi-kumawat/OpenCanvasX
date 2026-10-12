# OpenCanvasX design system

> **Status:** Normative. Every screen and component follows this document; deviations need a note here first.
> Implementation: `apps/desktop/lib/src/theme/ocx_theme.dart` (tokens) and `apps/desktop/lib/src/widgets/` (shared components).

OpenCanvasX is a professional tool. The interface is calm, dense and predictable so the user's design is the only colourful thing on screen.

## 1. Principles

1. **Content first.** The canvas is the hero. Chrome is neutral, quiet and never competes with the design.
2. **One accent.** A single brand colour marks what matters: the primary action, the selection, focus and the active tool. Nothing else is coloured.
3. **Dense, not cramped.** Desktop density like professional design tools: small type, 28 px controls, tight but consistent spacing.
4. **Group by task.** Controls live in labelled sections in a fixed order. Related values share a row (X/Y, W/H). Nothing is placed "wherever there was room".
5. **Show what is relevant.** Panels show only what applies to the current selection. Rare options live in menus, not on permanent buttons.
6. **Keyboard first, mouse friendly.** Every frequent action has a shortcut, shown in its tooltip and menu item.
7. **Accessible by default.** Text meets WCAG AA contrast, focus is always visible, nothing relies on colour alone.

## 2. Colour

### Brand

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `accent` | `#3256F0` Cobalt | `#7B93FF` | Primary button, selection outline and handles, focus ring, active tool, links |
| `accentSubtle` | `#EBEFFE` | `#232A4D` | Selected row/tab/tool background |
| `onAccent` | `#FFFFFF` | `#0B1033` | Text/icons on accent |

Rules:

- **No gradients** anywhere in the UI (backgrounds, buttons, logo, bars).
- **One primary (accent) button per view.** Everything else is secondary or ghost.
- The accent is never used for decoration, large background areas or illustrations.

### Neutrals

| Token | Light | Dark | Use |
|-------|-------|------|-----|
| `background` | `#F5F6F8` | `#121316` | Window background, home content area |
| `surface` | `#FFFFFF` | `#1B1C20` | Panels, toolbar, cards, menus, dialogs |
| `surfaceSunken` | `#F0F1F4` | `#23252A` | Inputs, thumbnails wells, segmented tracks |
| `workspace` | `#E8EAEE` | `#0E0F11` | Area around pages on the canvas |
| `border` | `#E1E3E8` | `#2E3036` | Hairlines between regions, card outlines |
| `borderStrong` | `#C9CDD6` | `#3D4048` | Input outline on hover, dividers that must be seen |
| `text` | `#16181D` | `#ECEDEF` | Primary text and icons |
| `textSecondary` | `#5B616E` | `#A4A8B2` | Labels, values that are less important |
| `textTertiary` | `#8A909C` | `#7A7F8A` | Placeholders, disabled, captions |

### Semantic

| Token | Light | Dark |
|-------|-------|------|
| `success` | `#1F9D55` | `#3CCB7F` |
| `warning` | `#C27C00` | `#F0B429` |
| `danger` | `#D93D3D` | `#F07070` |

Semantic colours appear only as small text, icons or thin backgrounds for status (never as large fills).

## 3. Typography

System UI font (Segoe UI on Windows, SF Pro on macOS, the desktop default on Linux). No bundled UI font, so nothing to license and the app feels native.

| Style | Size / line height | Weight | Use |
|-------|-------------------|--------|-----|
| `caption` | 11 / 16 | 500 | Section headers, input prefixes, badges, hints |
| `body` | 12 / 18 | 400 | Default UI text, menu items, list rows |
| `bodyStrong` | 12 / 18 | 600 | Selected items, emphasised values |
| `input` | 12 / 16 | 400 | Text inside inputs |
| `title` | 14 / 20 | 600 | Panel titles, dialog section titles, card titles |
| `heading` | 18 / 24 | 600 | Dialog titles, home section titles |
| `display` | 26 / 32 | 700 | Home page heading only |

Rules: sentence case everywhere ("Add page", not "Add Page"); section headers are 11 px semibold in `textSecondary`, **not** uppercase with letter spacing; no more than three sizes on one panel.

## 4. Spacing and sizing

4 px grid. Allowed spacings: **4, 8, 12, 16, 24, 32, 48.**

| Element | Size |
|---------|------|
| Compact control (input, icon button, segmented item, select) | 28 px high |
| Button | 32 px high (36 px only for the main call to action on home and in dialogs) |
| Editor toolbar | 44 px |
| List row (layers, pages, menu item) | 28 px (layers), 32 px (menus) |
| Panel padding | 12 px horizontal |
| Gap between controls in a row | 8 px |
| Gap between sections | separated by a 1 px `border` line, 12 px above and below content |

### Icons

- Outlined Material Symbols, **16 px** in panels, menus and inputs; **18 px** in the editor toolbar; **20 px** maximum anywhere in chrome.
- Icon-only buttons are 28 × 28 px with a 16 px icon and always have a tooltip with name and shortcut.
- No icon larger than 20 px except illustrations in empty states (max 40 px).

### Radius

| Use | Radius |
|-----|--------|
| Inputs, small buttons, icon buttons, segmented items | 4 px |
| Buttons, menus, tooltips, list selection | 6 px |
| Cards, popovers | 8 px |
| Dialogs | 12 px |

### Elevation

Flat by default. Shadows only for floating layers: menus/popovers (`0 4 16 rgba(0,0,0,.12)`), dialogs (`0 12 32 rgba(0,0,0,.18)`), pages on the canvas (soft 1 px + 8 px blur). Cards on home use a 1 px border, no shadow; a light shadow appears on hover.

## 5. Layout

### Editor

```
┌───────────────────────────────────────────────────────────────────────────────┐
│ Top bar 44: [⌂] [Menu ▾]          Title · Saved          [↶ ↷] [Zoom ▾] [☼] [Export] │
├──────┬──────────────┬────────────────────────────────────────┬─────────────────┤
│ Rail │ Panel 300    │                                        │ Inspector 248   │
│ 72   │ (Design,     │            Canvas (workspace)          │ (selection or   │
│ Design│ Elements,   │                                        │  page)          │
│ Elem.│  Text,       │                                        │                 │
│ Text │  Uploads,    │      ┌──────────────────────────┐      │                 │
│ Upl. │  Layers,     │      │ ↖ ✋ │ # ▢▾ ╱▾ T          │      │                 │
│ Lay. │  Pages)      │      └──────────────────────────┘      │                 │
│ Pages│              │        floating tool bar               │                 │
└──────┴──────────────┴────────────────────────────────────────┴─────────────────┘
```

- **Top bar (left → right):** home · main menu (File, Edit, View, Insert, Arrange as submenus) · *centre:* document title with save state · undo/redo · zoom menu · theme · **Export** (the one primary button).
- **Content rail (72 px):** icon + 10.5 px label per tab: *Design* (page/frame sizes, templates as they land), *Elements* (shapes, lines, frames, icons, stickers — searchable, "See all" opens a filtered browser with the pack's licence line), *Text* (text boxes and presets), *Uploads* (import files, reuse images in the design), *Layers* (layer tree of the active page), *Pages* (page/board thumbnails, add, duplicate, reorder, delete). Clicking the open tab collapses the 300 px panel.
- **Floating tool bar:** centred 16 px above the canvas bottom, `surface`, 1 px border, radius 12, menu shadow. Order: Move, Hand · Frame ▾, Shapes ▾, Lines ▾, Text. Tools do not live in the top bar.
- **Right sidebar (inspector):** always the same section order (below). Empty state = page properties.
- No bottom bar: zoom lives in the top bar, page navigation in the Pages panel.

### Inspector section order

0. **Source** — only for placed images: pack, version, licence and author (attribution text when the licence needs it) or "Uploaded …".
1. **Alignment** — one row: align left/centre/right/top/middle/bottom; distribute (when ≥ 3 selected).
2. **Layout** — X, Y · W, H (+ lock ratio) · rotation, corner radius.
3. **Text** — only for text: font, weight, size · alignment · line height, letter spacing.
4. **Appearance** — opacity, blend mode (later).
5. **Fill** — colour row: swatch, hex, opacity, remove.
6. **Stroke** — colour row, weight, style (solid/dashed/dotted).
7. **Arrange** is *not* a section: it is in the Arrange menu, the context menu and shortcuts.

Each section: header row (title 11 px semibold + trailing actions such as `+`), content rows with label prefixes inside inputs ("X", "W", "°"), 1 px divider below.

### Home

- Left sidebar 220 px: logo, primary "Create design" button, navigation (Home, Designs), storage status, theme.
- Content max width 1200 px, 32 px gutters: heading + search, "Start a design" presets row, "Recent designs" grid.
- Cards: thumbnail well (`surfaceSunken`), title (`title`), meta line (`caption`).

## 6. Components

| Component | Spec |
|-----------|------|
| Primary button | Accent fill, `onAccent` text, 32 px, radius 6, 12 px text 600 |
| Secondary button | `surface` fill, 1 px `border`, `text` |
| Ghost button | No fill; hover `accentSubtle` (selected) or 6 % `text` overlay |
| Icon button | 28 px square, 16 px icon, radius 4; selected = `accentSubtle` + accent icon |
| Input | 28 px, `surfaceSunken`, no border at rest, `borderStrong` on hover, 1.5 px accent on focus; prefix label in `textTertiary` |
| Select / dropdown | Same as input with chevron; opens a menu |
| Segmented control | 28 px track `surfaceSunken`; selected item `surface` with 1 px border |
| Menu | `surface`, radius 8, item 32 px, shortcut right-aligned in `textTertiary`, separators between groups |
| Tooltip | Dark (`#1F2128`), white 11 px text, name + shortcut |
| Toast | Bottom centre, `surface`, border, 12 px text, optional action |
| Dialog | 12 radius, 24 px padding, title `heading`, actions bottom-right (secondary then primary) |

### States

Hover = 6 % `text` overlay · pressed = 10 % · selected = `accentSubtle` · focus = 2 px accent ring (keyboard focus only) · disabled = 40 % opacity.

### Motion

120–160 ms, ease-out, for hover, panel and menu transitions only. No bouncing, no motion on the canvas content.

## 7. Canvas visuals

- Selection: 1 px accent outline; handles 7 × 7 px white squares with 1 px accent border; rotation handle 8 px circle 20 px below the box.
- Hover: 1 px accent outline at 60 % opacity.
- Marquee: accent at 8 % fill, 1 px accent border.
- Measurement labels (size while resizing, angle while rotating): dark tooltip style, 11 px.
- Pages: white (or the page background) with a soft shadow on `workspace`; the page title sits above the page in `caption` style; the active page title uses `text`, others `textSecondary`.

## 8. Writing

- Sentence case, short, verb first on buttons ("Create design", "Choose folder").
- Explain consequences in dialogs ("Neither version has been deleted.").
- No exclamation marks, no jokes in errors, never blame the user.

## 9. Do and don't

| Do | Don't |
|----|-------|
| Neutral chrome, colour only for meaning | Gradients, coloured bars, decorative blobs |
| 16 px icons, 28 px controls | 24 px+ icons in panels, oversized buttons |
| Fixed section order in the inspector | Controls appended "one by one" as features land |
| One primary button per view | Several filled buttons competing |
| Tooltips with shortcuts | Unlabelled icon buttons |
| Group related values on one row | One value per full-width row |
