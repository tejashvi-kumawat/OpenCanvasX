# Export and import architecture

Import/export adapters live in `packages/export_engine` and `packages/pdf_engine`, with format-specific plugins later.

## Export goals

- No artificial limits (watermarks, page caps) on free core exports.
- **Vector preservation** for SVG/PDF when source objects are vector.
- Deterministic output given same document and settings (modulo font substitution).

## Supported targets (phased)

| Format | Phase | Notes |
|--------|-------|-------|
| PNG | 1 | Page or selection; alpha; user scale / DPI |
| SVG | 1 | Single page default; embed images as needed |
| PDF | 1 | Single/multi page; print-ready later |
| JPEG/WebP | 2+ | Quality sliders |
| PDF/A | 3+ | Archival subset |
| PPTX | Later | Best-effort fidelity |
| MP4/WebM | Post-MVP | Via media pipeline |

## Export pipeline

1. **Scope**: current page, all pages, or selection bounds.
2. **Flatten options**: include hidden layers (default no), outline text (optional for PDF).
3. **Traverse** document like renderer ([rendering-architecture.md](rendering-architecture.md)).
4. **Backend** writes stream to user path.
5. **Progress** for batch/long jobs on background isolate with cancel.

## Import pipeline

1. Detect format (extension + sniff).
2. Parse into temporary object graph.
3. Map to document model types (partial fidelity OK — document gaps in UI).
4. Register imported binaries as content-addressed assets.

Priority importers: SVG, PNG/JPEG/WebP, PDF (first page or full), plain text/markdown blocks.

## Color and print

- Working color space: sRGB for screen exports.
- CMYK conversion optional for print PDF (explicit user setting, Phase 3+).
- Bleed: read from page definition when exporting print preset.

## Fidelity notes

Office formats and HTML may lose layout nuance. Each importer documents a **known limitations** section in code and user-facing dialog when relevant.

## Related

- [file-format.md](file-format.md)
- [asset-architecture.md](asset-architecture.md)


## Implementation status (Phase 1)

- `packages/export_engine` (pure Dart): `exportTargets` (page, board frames, selection → regions), `exportSvg` (own SVG 1.1 writer; text lines supplied by the renderer's layout), `encodeJpeg`/`encodePng` (`image`), `encodeRasterPdf` (`pdf`: pages at physical size with a rendered image, title/author/creator metadata).
- `packages/renderer`: `renderRegion` (draws a target into a `ui.Image`), `textLines` (line breaks matching the canvas).
- App: `lib/src/export/` dialog and `buildExport`; images are decoded (`MediaCache.preload`) before rendering so nothing exports as a placeholder.
- `exportHtmlSite` (early P3.9.2): static site, one HTML page per target with inline SVG, prototype links as `<a>` hotspots positioned in %, pager links for pages.
- Next: vector PDF with embedded OFL fonts, WebP, an export worker isolate (P1.9.5), PPTX (Phase 3), HTML with real text/CSS layout.

## Background export (P1.9.5)

Pages are rendered one at a time on the UI isolate (Flutter's canvas requires it), yielding a frame between pages so the editor stays responsive; the export dialog shows "Rendering page n of m…". JPEG and PDF encoding run on a background isolate (`Isolate.run`), PNG encoding runs in the engine off the UI thread, and SVG/HTML are string building that needs the UI isolate's text layout.
