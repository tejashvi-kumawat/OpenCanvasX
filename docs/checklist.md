# OpenCanvasX — Agent Checklist

## Agent Rules
- Work top to bottom. Never start a phase until the previous phase's **Exit Gate** is fully ticked.
- Tick `[x]` only when the item's output exists in the repo and its tests/lint pass.
- One minor item = one commit. Commit message starts with the item ID (e.g. `P1.2.3: add rotate transform`).
- Every item that ships code also ships: unit tests + doc update in `docs/`.
- If blocked, mark `[!]` and add a one-line reason beneath the item. Do not skip silently.
- Never copy Canva templates, assets, code, logos, or UI artwork. Only original or openly licensed content, with license metadata.
- Never implement crypto primitives manually. Use audited libraries.
- Never store API keys, passwords, or private keys in project files or logs.

Legend: `[ ]` todo · `[x]` done · `[!]` blocked

---

# PHASE 0 — Setup, Documentation, Decisions

## P0.1 Repository & Tooling
- [x] P0.1.1 Create monorepo `OpenCanvasX/` with `apps/ packages/ templates/ assets/ plugins/ protocols/ docs/ scripts/ tests/ third_party/`
- [x] P0.1.2 Add `README.md`, `LICENSE`, `THIRD_PARTY_NOTICES`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`
- [x] P0.1.3 Choose and record the project license (compatible with all planned dependencies)
- [x] P0.1.4 Set up Flutter/Dart workspace (melos or equivalent)
- [x] P0.1.5 Set up Rust workspace (cargo) + Flutter–Rust bridge
- [x] P0.1.6 Configure formatter, linter, static analysis for Dart and Rust
- [x] P0.1.7 Configure pre-commit hooks (format, lint, secrets scan)
- [x] P0.1.8 Set up CI: build + test on Windows, macOS, Linux
- [x] P0.1.9 Set up release pipeline skeleton (GitHub Releases, checksums, signing placeholders)
- [x] P0.1.10 Add issue templates, PR template, branch/commit conventions doc

## P0.2 Product Docs (`docs/product/`)
- [x] P0.2.1 `vision.md` — vision, principles (the 15 core principles), non-goals
- [x] P0.2.2 `positioning.md` — positioning, differentiators, free-product boundaries (no watermark, no limits, no forced account)
- [x] P0.2.3 `personas.md` — target users and top use cases
- [x] P0.2.4 `feature-catalog.md` — full feature list grouped by category, each tagged MVP / Post-MVP / Later
- [x] P0.2.5 `mvp-scope.md` — exact MVP: design, collaboration MVP, AI MVP
- [x] P0.2.6 `roadmap.md` — phases, dependencies, exit gates
- [x] P0.2.7 `ux-spec.md` — main UI layout (menus, left/right panels, canvas, bottom bar), onboarding flow, command palette, shortcuts
- [x] P0.2.8 `accessibility-spec.md`
- [x] P0.2.9 `telemetry-and-privacy-policy.md` — telemetry OFF by default, AI privacy rules, crash reporting rules
- [x] P0.2.10 `legal-content-rules.md` — template/asset licensing rules, Canva non-copy rule

## P0.3 Architecture Docs (`docs/architecture/`)
- [x] P0.3.1 `overview.md` — engine map (UI, design, document, template, asset, typography, export, media, collaboration, security, AI, agent, plugin, storage, platform)
- [x] P0.3.2 `tech-stack-decision.md` — ADRs for Flutter, Rust, Skia/Impeller, SQLite, FFmpeg, PDF libs, WebRTC, crypto libs
- [x] P0.3.3 `document-model.md` — object types, transforms, pages, layers, styles, IDs, versioning
- [x] P0.3.4 `file-format.md` — `.opencanvasx` spec: structure, versioning, migration, no secrets
- [x] P0.3.5 `rendering-architecture.md` — canvas, incremental/tiled rendering, virtualization, caching
- [x] P0.3.6 `storage-architecture.md` — SQLite schema plan, content-addressed assets, snapshots, backups
- [x] P0.3.7 `export-architecture.md` — SVG/PNG/PDF pipelines, vector-preservation rules
- [x] P0.3.8 `template-architecture.md` — declarative template format, recipes, metadata, repository format (`index.json`)
- [x] P0.3.9 `asset-architecture.md` — asset metadata, license fields, hashing, validation
- [x] P0.3.10 `plugin-architecture.md` — permissions, sandboxing, signing, API surface
- [x] P0.3.11 `ai-architecture.md` — provider interface, BYOK, local adapters, privacy disclosure flow, cost tracking
- [x] P0.3.12 `agent-architecture.md` — tool schema, sandbox, approval levels, audit log
- [x] P0.3.13 `extensibility-apis.md` — document, renderer, plugin, exporter, importer, AI provider, asset/template provider APIs
- [x] P0.3.14 `performance-budget.md` — targets (10k objects, 100+ pages, 100k operations)
- [x] P0.3.15 Architecture Decision Record template + `docs/adr/` folder

## P0.4 Collaboration & Security Docs (`docs/protocol/`, `docs/security/`)
- [x] P0.4.1 `protocol-layers.md` — Layers 0–9 (discovery → versioning)
- [x] P0.4.2 `invitation-spec.md` — fields, nonce, expiry, single-use, signature, `ocx://join/...` scheme
- [x] P0.4.3 `identity-and-auth.md` — device keys, fingerprints, OS secure storage, peer verification
- [x] P0.4.4 `authorization-spec.md` — roles, permissions, capability model
- [x] P0.4.5 `crypto-spec.md` — Ed25519, X25519, AEAD, HKDF; document keys; revocation + key rotation
- [x] P0.4.6 `crdt-spec.md` — operation schema, logical clocks, merge rules, tombstones, text CRDT choice
- [x] P0.4.7 `sync-spec.md` — offline queue, reconnect, missing-op exchange, asset chunk transfer
- [x] P0.4.8 `network-modes.md` — LAN, direct P2P, relay, status UI states
- [x] P0.4.9 `threat-model.md` — malicious network/peer/template/plugin/asset/file, replay, MITM, stolen invite, compromised relay
- [x] P0.4.10 `security-promises.md` — allowed and disallowed claims
- [x] P0.4.11 `input-validation-policy.md` — SVG, images, PDFs, archives, fonts, metadata

## P0.5 Quality, Process & Legal Docs
- [x] P0.5.1 `docs/testing-strategy.md` — unit/integration/security/performance plans
- [x] P0.5.2 `docs/dependency-policy.md` — license audit procedure, `DEPENDENCIES`, `LICENSES`
- [x] P0.5.3 `docs/definition-of-done.md`
- [x] P0.5.4 `docs/agent-guide.md` — how agents pick, execute, and verify checklist items
- [x] P0.5.5 `docs/glossary.md`
- [x] P0.5.6 `docs/release-process.md` — signing, checksums, update verification

## P0.6 Foundations in Code
- [x] P0.6.1 Skeleton packages created per repo structure (empty, compiling)
- [x] P0.6.2 Desktop app shell launches an empty window on all 3 OS
- [x] P0.6.3 Test harness runs in CI (one passing test per package)
- [x] P0.6.4 Logging module with secret-redaction rules

### Exit Gate P0
- [x] All docs above exist and are cross-linked from `docs/README.md`
- [x] CI green on 3 OS
- [x] Empty app shell builds and launches

---

# PHASE 1 — Core Editor (Necessary Foundation)

## P1.1 Document Model & Storage
- [x] P1.1.1 Implement object model (id, type, transform, style, children)
- [x] P1.1.2 Page model (size, background, margins, bleed, guides)
- [x] P1.1.3 Units & conversion (px, mm, cm, in, pt) + DPI
- [x] P1.1.4 Serialization to `.opencanvasx` + versioned migration framework
- [x] P1.1.5 Save / open / autosave
- [x] P1.1.6 Recent documents
- [x] P1.1.7 Local project directory selection

## P1.2 Canvas & Navigation
- [x] P1.2.1 Fixed page canvas with pan/zoom
- [x] P1.2.2 Multiple pages + page navigation
- [x] P1.2.3 Custom dimensions and size presets
- [ ] P1.2.4 Rulers, grid, guides
- [x] P1.2.5 Zoom shortcuts and fit-to-page

## P1.3 Objects & Transforms
- [x] P1.3.1 Rectangle, rounded rectangle, ellipse/circle, line, arrow
- [x] P1.3.2 Polygon, star
- [x] P1.3.3 Selection (single, multi, marquee)
- [x] P1.3.4 Move, resize, rotate, flip
- [x] P1.3.5 Opacity, fill, stroke, dashed stroke
- [x] P1.3.6 Group / ungroup, nested groups
- [x] P1.3.7 Copy / cut / paste / duplicate

## P1.4 Layers & Alignment
- [x] P1.4.1 Layer tree panel (rename, lock, hide, reorder)
- [x] P1.4.2 Align (left/center/right/top/middle/bottom)
- [x] P1.4.3 Distribute + equal spacing
- [x] P1.4.4 Snap to page / object / grid + smart guides

## P1.5 Text (Basic)
- [x] P1.5.1 Text box (auto width/height, fixed)
- [x] P1.5.2 Font family/weight/style/size, color
- [x] P1.5.3 Letter spacing, line height, alignment
- [ ] P1.5.4 Character-level formatting
- [ ] P1.5.5 Local font discovery + fallback/substitution
- [ ] P1.5.6 Font license metadata check (no unlicensed bundling)

## P1.6 Images & SVG (Basic)
- [x] P1.6.1 Import PNG, JPEG, WebP, GIF, BMP
- [x] P1.6.2 Import SVG (validated, sanitized)
- [ ] P1.6.3 Crop, resize, rotate, flip
- [ ] P1.6.4 Rounded corners, mask, clipping
- [ ] P1.6.5 Content-hash asset storage + thumbnail cache

## P1.7 Color (Basic)
- [x] P1.7.1 Color picker (RGB, HEX, HSL, HSV) + eyedropper
- [x] P1.7.2 Swatches + custom palettes
- [x] P1.7.3 Linear + radial gradient editor
- [x] P1.7.4 Contrast checker

## P1.8 History
- [x] P1.8.1 Undo / redo
- [ ] P1.8.2 History panel
- [ ] P1.8.3 Named checkpoints + snapshots + restore

## P1.9 Export (Basic)
- [x] P1.9.1 PNG export (scale, DPI, transparency)
- [ ] P1.9.2 JPEG / WebP export
- [x] P1.9.3 SVG export (native vector preserved)
- [ ] P1.9.4 PDF export (vector, page size, metadata)
- [ ] P1.9.5 Background export on worker thread

## P1.10 App Shell UX
- [x] P1.10.1 Main layout: top menu, left panel, canvas, right inspector, bottom bar
- [x] P1.10.2 Inspector / properties panel
- [x] P1.10.3 Dark + light theme
- [ ] P1.10.4 Keyboard shortcuts (core set) + customization
- [ ] P1.10.5 Command palette (Ctrl/Cmd+K) with fuzzy search
- [ ] P1.10.6 Onboarding: create identity, choose storage directory, privacy explanation

## P1.11 Offline & Privacy Baseline
- [ ] P1.11.1 Verify zero network calls during core editing
- [ ] P1.11.2 Telemetry absent/OFF; local crash logs only

### Exit Gate P1
- [ ] User can create, edit, save, reopen, and export a multi-page design offline on all 3 OS
- [ ] Core test suite passes; 1k-object document stays responsive

---

# PHASE 2 — Templates, Assets, Brand, Search (MVP Completion)

## P2.1 Asset Engine
- [x] P2.1.1 Asset metadata schema (id, source, author, license, license URL, attribution, tags, dimensions, hash)
- [x] P2.1.2 Asset library panel (browse, search, filter, tags)
- [ ] P2.1.3 Asset types: photos, icons, shapes, stickers, patterns, textures, frames, backgrounds
- [x] P2.1.4 License inspector UI + attribution tracking
- [x] P2.1.5 Reject assets lacking license metadata
- [ ] P2.1.6 Asset validation pipeline (images, SVG, archives, fonts, metadata)
- [x] P2.1.7 Seed original/openly-licensed asset pack with `licenses/` folder

## P2.2 Template Engine
- [x] P2.2.1 Declarative template format (no code execution)
- [x] P2.2.2 Template metadata (id, author, version, license, category, tags, dimensions, required assets, font deps, preview, compat version)
- [x] P2.2.3 Template browser panel + search/filter
- [ ] P2.2.4 Create design from template; save design as private template
- [x] P2.2.5 Template validator + malicious-template tests
- [ ] P2.2.6 Original official templates: social (Instagram, Facebook, LinkedIn, YouTube, TikTok, X)
- [x] P2.2.7 Original official templates: posters, flyers, resumes, certificates, invitations, business cards
- [ ] P2.2.8 Original official templates: presentations/pitch decks, reports, infographics, menus, newsletters

## P2.3 Brand Kit
- [ ] P2.3.1 Brand kit model (logos, colors, fonts, text styles, icons, spacing rules)
- [ ] P2.3.2 Brand panel UI
- [ ] P2.3.3 Apply brand kit to new/existing designs and templates
- [ ] P2.3.4 Brand validation (wrong colors/fonts, logo misuse, contrast)

## P2.4 Resize & Variants
- [ ] P2.4.1 Magic resize (preserve hierarchy, alignment, safe areas, crop)
- [ ] P2.4.2 Manual correction after resize
- [ ] P2.4.3 Template recipe generator (grid, palette, slots → variants)
- [ ] P2.4.4 Controlled/random variation + brand constraints

## P2.5 Search & Project Management
- [ ] P2.5.1 SQLite local index (documents, templates, assets, layers, text, fonts, commands)
- [ ] P2.5.2 Global search UI
- [ ] P2.5.3 Projects: create, rename, duplicate, archive, delete, import/export
- [ ] P2.5.4 Favorites, pinned projects
- [ ] P2.5.5 Local backup + retention settings + restore

## P2.6 Basic Vector Editing (MVP-required)
- [x] P2.6.1 Pen tool + Bézier paths
- [x] P2.6.2 Node editing
- [x] P2.6.3 Freehand drawing

### Exit Gate P2 (MVP Design Complete)
- [ ] Every item in spec §102 "MVP must contain" is working
- [ ] User can start from a template, apply a brand kit, and export PNG/SVG/PDF offline

---

# PHASE 3 — Professional Design Features

## P3.1 Advanced Vector
- [ ] P3.1.1 Boolean ops (union, subtract, intersect, exclude)
- [ ] P3.1.2 Offset path, stroke expansion, stroke alignment
- [ ] P3.1.3 Pattern fill, conic gradient
- [ ] P3.1.4 Clipping paths + masks + blend modes
- [ ] P3.1.5 Isolate mode

## P3.2 Advanced Typography
- [ ] P3.2.1 Paragraph formatting, justification, spacing
- [ ] P3.2.2 Lists, bullets, numbering, super/subscript, links
- [ ] P3.2.3 OpenType features, ligatures, variable fonts
- [ ] P3.2.4 Text on path
- [ ] P3.2.5 Text effects (outline, shadow, gradient)
- [ ] P3.2.6 Font embedding where license permits

## P3.3 Advanced Image Editing
- [ ] P3.3.1 Non-destructive adjustments (brightness, contrast, saturation, hue, exposure)
- [ ] P3.3.2 Blur, sharpen, duotone, pixelate, blur regions, filters
- [ ] P3.3.3 Local background removal (local model/tool)
- [ ] P3.3.4 Import TIFF, AVIF where supported

## P3.4 Color Extensions
- [ ] P3.4.1 CMYK and LAB support

## P3.5 Charts & Tables
- [ ] P3.5.1 Chart types: bar, line, area, pie, donut, scatter
- [ ] P3.5.2 Chart types: bubble, radar, histogram, heatmap, funnel, waterfall, timeline
- [ ] P3.5.3 Data input: manual, CSV, TSV, JSON, clipboard
- [ ] P3.5.4 Chart formatting (axis, legend, labels, grid, colors)
- [ ] P3.5.5 Tables: rows/cols, merge/split, borders, fill, alignment, number format, sorting, basic formulas

## P3.6 Presentations
- [ ] P3.6.1 Slide master + layouts
- [ ] P3.6.2 Presenter notes
- [ ] P3.6.3 Full-screen present mode + speaker view (present mode done: slideshow + board prototypes; speaker view pending)
- [ ] P3.6.4 Export slides to PDF and images
- [ ] P3.6.5 PPTX export/import (best fidelity, documented gaps)

## P3.7 Whiteboard
- [x] P3.7.1 Infinite canvas
- [ ] P3.7.2 Sticky notes, connectors, frames
- [ ] P3.7.3 Mind maps

## P3.8 Print & PDF
- [ ] P3.8.1 Bleed + crop marks
- [ ] P3.8.2 Print preview + print dialog (copies, ranges, scaling, duplex)
- [ ] P3.8.3 PDF/A export, rasterized option, compression
- [ ] P3.8.4 Import PDF pages as placed/editable objects
- [ ] P3.8.5 QR codes (URL, Wi-Fi, contact, email, text) + barcodes

## P3.9 Interop
- [ ] P3.9.1 Import: JSON, CSV, TXT, Markdown, HTML (practical subset)
- [ ] P3.9.2 Export: GIF, HTML, JSON, SVG sprite

## P3.10 Performance
- [ ] P3.10.1 GPU rendering, incremental + tiled rendering
- [ ] P3.10.2 Object/page virtualization, lazy image loading, mipmaps
- [ ] P3.10.3 Benchmarks: 10k objects, 100+ pages, large images

## P3.11 Accessibility
- [ ] P3.11.1 Keyboard navigation, focus indicators, screen-reader labels
- [ ] P3.11.2 High contrast, large UI, reduced motion
- [ ] P3.11.3 Alt text, accessible PDF metadata, reading order

### Exit Gate P3
- [ ] Performance benchmarks met; feature catalog items for this phase all verified

---

# PHASE 4 — Collaboration (P2P, E2E)

## P4.1 Identity & Crypto Foundation
- [ ] P4.1.1 Device identity keypair generation
- [ ] P4.1.2 OS secure storage integration for private keys
- [ ] P4.1.3 Fingerprint display + manual verification UI
- [ ] P4.1.4 Crypto wrapper package (Ed25519, X25519, AEAD, HKDF) over audited libs
- [ ] P4.1.5 Crypto unit tests + known-answer vectors

## P4.2 CRDT & Operations
- [ ] P4.2.1 Operation schema (id, actor, seq, doc id, logical clock, type, payload, signature, version)
- [ ] P4.2.2 CRDT for object properties, page order (sequence CRDT), layer order
- [ ] P4.2.3 Text CRDT
- [ ] P4.2.4 Tombstone rules for delete/update conflicts
- [ ] P4.2.5 Replay protection + signature + sequence validation
- [ ] P4.2.6 Operation log + snapshots in local storage
- [ ] P4.2.7 Convergence property tests (100k operations)

## P4.3 Offline Sync
- [ ] P4.3.1 Pending-operation queue
- [ ] P4.3.2 Missing-operation exchange on reconnect
- [ ] P4.3.3 Conflict-detected UI state; never discard unsynced work

## P4.4 Invitations & Sessions
- [ ] P4.4.1 Collaboration session creation
- [ ] P4.4.2 Signed, single-use, short-lived invitation
- [ ] P4.4.3 QR generation and scanning
- [ ] P4.4.4 `ocx://join/...` URI scheme registration on all OS
- [ ] P4.4.5 Explicit accept/reject with host identity display
- [ ] P4.4.6 Malformed/expired/replayed invitation tests

## P4.5 Transport
- [ ] P4.5.1 LAN transport + mDNS discovery ("available nearby", still needs approval)
- [ ] P4.5.2 Manual local IP join
- [ ] P4.5.3 WebRTC direct P2P with ICE + STUN
- [ ] P4.5.4 Manual signaling (zero-infrastructure mode)
- [ ] P4.5.5 Optional user-configured signaling / TURN / relay
- [ ] P4.5.6 Prefer direct, fall back to relay; network-mode status UI (Local/LAN/Direct/Relayed/Offline/Syncing/Synced/Conflict)

## P4.6 Encryption & Authorization
- [ ] P4.6.1 Document key generation + key wrapping per peer
- [ ] P4.6.2 Application-level payload encryption
- [ ] P4.6.3 Roles (Owner/Admin/Editor/Commenter/Viewer) + capability permissions
- [ ] P4.6.4 Revocation: invalidate session, rotate key, redistribute
- [ ] P4.6.5 MITM / rogue-peer / revoked-peer security tests

## P4.7 Asset Sync
- [ ] P4.7.1 Hash-based dedup
- [ ] P4.7.2 Encrypted chunk transfer, resumable, integrity-verified

## P4.8 Collaboration UX
- [ ] P4.8.1 Presence (cursors, selection, page, editing indicator; ephemeral)
- [ ] P4.8.2 Comments (page/object/text range; add, edit, resolve, reopen, mention)
- [ ] P4.8.3 Collaboration panel + bottom-bar status

## P4.9 Sync & Versioning Extras
- [ ] P4.9.1 Optional file sync adapters (Syncthing, WebDAV, SFTP, Git, S3-compatible)
- [ ] P4.9.2 Divergent-file conflict detection; preserve both versions
- [ ] P4.9.3 Local version compare

### Exit Gate P4
- [ ] Two devices edit the same document on LAN and over the internet with E2E encryption
- [ ] Security test suite (spec §100) passes
- [ ] Protocol flagged for external security review before any "high assurance" claim

---

# PHASE 5 — AI (Optional Layer)

## P5.1 Provider Layer
- [ ] P5.1.1 Abstract provider interface
- [ ] P5.1.2 OpenAI-compatible endpoint adapter
- [ ] P5.1.3 Anthropic-compatible and Google-compatible adapters
- [ ] P5.1.4 Local adapters (Ollama, llama.cpp, local OpenAI-compatible)
- [ ] P5.1.5 Config: provider, endpoint, model, key, temperature, max tokens, context, timeout, retry
- [ ] P5.1.6 API keys in OS secure storage only; never in docs, CRDT, logs, or sent to collaborators
- [ ] P5.1.7 "No AI" mode fully functional

## P5.2 Privacy & Cost
- [ ] P5.2.1 Context selector (page, selection, document, text, assets, folder)
- [ ] P5.2.2 Pre-send disclosure: "These items will be sent to provider X"
- [ ] P5.2.3 Local vs BYOK vs remote indicator
- [ ] P5.2.4 Usage/cost display, model selection, limits, local-only mode
- [ ] P5.2.5 Hardware requirement display for local AI

## P5.3 AI Panel & Text/Design Features
- [ ] P5.3.1 AI panel UI
- [ ] P5.3.2 Rewrite, shorten, expand, tone, translate
- [ ] P5.3.3 Copy and caption generation, design briefs
- [ ] P5.3.4 Palette, typography, spacing, hierarchy suggestions
- [ ] P5.3.5 Layout generation from text/structure
- [ ] P5.3.6 Presentation outline generation
- [ ] P5.3.7 Accessibility + consistency + alignment analysis
- [ ] P5.3.8 Layer renaming/organizing, template metadata generation

## P5.4 AI Image Features (user-provided image API)
- [ ] P5.4.1 Text to image, variations
- [ ] P5.4.2 Background generation/replacement
- [ ] P5.4.3 Inpainting/outpainting where provider supports
- [ ] P5.4.4 Disable-image-generation switch

## P5.5 Agent System
- [ ] P5.5.1 Agent loop: goal → plan → tool → execute → validate → approve → result
- [ ] P5.5.2 Tool registry with JSON schemas
- [ ] P5.5.3 Page/shape/text/image tools (create_page, delete_page, duplicate_page, create_text, edit_text, create_shape, edit_shape, insert_image, crop_image)
- [ ] P5.5.4 Layer tools (create_group, rename_layer, move_layer, reorder_layer, align_objects, distribute_objects)
- [ ] P5.5.5 Style/asset tools (apply_style, apply_brand, import_asset, search_local_assets, search_templates)
- [ ] P5.5.6 Content tools (create_chart, create_table, create_presentation, create_diagram, create_mindmap)
- [ ] P5.5.7 Export tools (export_pdf, export_png, export_svg)
- [ ] P5.5.8 Inspect tools (inspect_document, inspect_overflow, inspect_alignment, inspect_accessibility)
- [ ] P5.5.9 Audit log of every tool call

## P5.6 Agent Security
- [ ] P5.6.1 Sandbox + tool allowlist + read/write boundaries
- [ ] P5.6.2 No shell, no arbitrary network, no secrets, no private files by default
- [ ] P5.6.3 Approval levels (ask every action / ask destructive / trusted project / autonomous in sandbox); default conservative
- [ ] P5.6.4 Confirmation for high-risk actions (delete, export sensitive, share, upload, external AI call, execute code, change permissions)
- [ ] P5.6.5 Prompt-injection tests via malicious document/template content

## P5.7 Flagship Workflow
- [ ] P5.7.1 End-to-end "document → pitch deck" agent (outline, template, slides, charts, brand, typography, overflow check, approval, export)

### Exit Gate P5
- [ ] AI MVP (spec §102) works with a BYOK provider and a local endpoint
- [ ] No content leaves the device without the disclosure prompt

---

# PHASE 6 — Ecosystem

## P6.1 Plugin System
- [ ] P6.1.1 Plugin manifest + permission declarations
- [ ] P6.1.2 Sandboxed runtime
- [ ] P6.1.3 Install approval UI + signature verification + version compatibility
- [ ] P6.1.4 Plugin APIs: importer, exporter, tool, template pack, asset pack, AI provider, diagram type, effect
- [ ] P6.1.5 Malicious-plugin tests

## P6.2 Community Repositories
- [ ] P6.2.1 Repository format (`index.json`, `templates/`, `assets/`, `previews/`, `licenses/`)
- [ ] P6.2.2 Add repository by URL (Git, static HTTPS, local folder)
- [ ] P6.2.3 Publish, unpublish, fork, rate, tag, report
- [ ] P6.2.4 License enforcement on ingest
- [ ] P6.2.5 Contributor terms doc

## P6.3 Import/Export Expansion
- [ ] P6.3.1 Draw.io XML, Mermaid, PlantUML, Graphviz DOT import
- [ ] P6.3.2 DOCX import (practical subset)

## P6.4 Distribution
- [ ] P6.4.1 Windows installer + portable ZIP
- [ ] P6.4.2 macOS DMG (universal)
- [ ] P6.4.3 Linux AppImage, .deb, .rpm, Flatpak
- [ ] P6.4.4 Signed releases + checksums
- [ ] P6.4.5 Optional update system (manual, auto, package-manager); user can disable
- [ ] P6.4.6 Optional static docs/download site

### Exit Gate P6
- [ ] Third party can install a plugin and add a community template repo without any vendor server

---

# PHASE 7 — Post-MVP Expansion

## P7.1 Video & Audio
- [ ] P7.1.1 Video import, trim, crop, position, scale
- [ ] P7.1.2 Timeline with tracks + keyframes (opacity, position, scale, rotation)
- [ ] P7.1.3 Audio import, trim, volume, fade, multi-track, waveform, voiceover
- [ ] P7.1.4 MP4 / WebM export via FFmpeg

## P7.2 Animation
- [ ] P7.2.1 Presets: fade, slide, scale, rotate, pop, typewriter, wipe
- [ ] P7.2.2 Custom keyframes + easing + preview
- [ ] P7.2.3 Slide transitions and animations

## P7.3 Diagram Engine
- [ ] P7.3.1 Flowchart, UML, ER, sequence, state
- [ ] P7.3.2 Network, architecture, org chart, BPMN, mind map
- [ ] P7.3.3 Round-trip with Mermaid / PlantUML / DOT / Draw.io

## P7.4 PDF Studio Integration
- [ ] P7.4.1 OCR, merge, sign, redact
- [ ] P7.4.2 Open/edit exported PDF

## P7.5 Team & Enterprise
- [ ] P7.5.1 Team workspaces on user-owned storage
- [ ] P7.5.2 Shared brand kits, assets, permissions
- [ ] P7.5.3 SSO adapter, audit logs, org policies, private plugin/template repos

## P7.6 Mobile & Web
- [ ] P7.6.1 Android client
- [ ] P7.6.2 iOS / iPadOS client
- [ ] P7.6.3 Web viewer/editor (if justified by ADR)

### Exit Gate P7
- [ ] Each shipped item verified against feature catalog and test plan

---

# Continuous Tracks (tick per release)
- [ ] CT.1 THIRD_PARTY_NOTICES / LICENSES / DEPENDENCIES updated
- [ ] CT.2 Security regression tests pass
- [ ] CT.3 Performance benchmarks recorded
- [ ] CT.4 Docs match shipped behavior
- [ ] CT.5 Telemetry still OFF by default; no secrets in logs