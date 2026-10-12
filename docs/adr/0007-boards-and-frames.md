# ADR-0007: Boards (unbounded pages) and frames

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

OpenCanvasX combines Canva-style fixed pages (posts, slides, print) with Figma-style free design: an unlimited canvas where several artboards (phone screens, web pages, posts) sit side by side. The checklist plans an infinite canvas (P3.7.1) and frames (P3.7.2); website/app prototyping (later phases) needs screens that are first-class objects. Users asked for this early.

## Decision

1. **`DesignPage.kind`** is `fixed` (default) or `board`. A board is unbounded: objects may sit anywhere, there is no page clip or edge, and `width`/`height` only give the starting view. The editor shows a board alone in the workspace (page (0, 0) at the workspace origin) with its background as the canvas colour; fixed pages keep the vertical stack. JSON: `"kind": "board"`, omitted for fixed pages.
2. **`ObjectType.frame`** is a container (like `group`) with its own box, style (fill, stroke, corner radius) and `FramePayload { clip_content }` (default `true`). Children use the frame's local space. Unlike groups:
   - resizing a frame does not scale its children;
   - clicks go through frames to their content; a top-level frame that has content is picked by its **title** above it (so a drag inside it starts a marquee), empty or nested frames by their body;
   - objects drawn, inserted or dropped on a frame become its children, and dragging them out moves them back to the page (objects inside groups are not reparented);
   - "Ungroup" on a frame removes it, keeping the children in place.
   Frames are allowed on fixed pages too.
3. `schema_version` becomes **2**. The 1 → 2 step is empty (v1 files are valid v2 files), but v1 builds must refuse files that may contain boards or frames.
4. Frame sizes reuse `PagePreset` (`framePresets`: devices, social, slides). Two board presets ("Free canvas", "Website & app design") and device presets are added to the create dialog.

## Consequences

- Export (P1.9) will treat each top-level frame on a board as an exportable artboard; prototyping links will connect frames.
- Page thumbnails of boards show only the starting view for now.
- Hit testing, rendering, reorder, copy, duplicate and reparenting all go through the generic container rules (`ObjectType.isContainer`).
