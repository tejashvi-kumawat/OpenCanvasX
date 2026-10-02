# Technology stack

Decisions here reflect the current plan for Open Design Studio. Locked choices have ADRs; tentative choices are marked **TBD** until dependency audit completes.

## Client application

| Choice | Status | Notes |
|--------|--------|-------|
| **Flutter (Dart)** for UI | Accepted — [ADR-0002](../adr/0002-flutter-plus-rust.md) | Desktop first; same codebase can target mobile later |
| **Rust** for native core | Accepted — ADR-0002 | Performance, crypto-adjacent code; exposed via `flutter_rust_bridge` |
| **Skia** (via Flutter / Impeller) | Accepted | 2D canvas, text, images |
| **Melos** | Accepted | Monorepo bootstrap and scripts |

## Persistence

| Choice | Status | Notes |
|--------|--------|-------|
| **SQLite** | Planned | Project index, search FTS, asset catalog metadata |
| **Filesystem + content hashes** | Planned | Large binaries under `assets/sha256/<hash>` |
| Native **`.designstudio`** archive | Planned | ZIP container; see [file-format.md](file-format.md) |

## Import / export

| Area | Candidates | Status |
|------|------------|--------|
| PDF read/write | PDFium, qpdf, MuPDF/Poppler | **TBD** — license + feature audit before pin |
| OCR | Tesseract | Optional, later |
| Vector | In-house + SVG DOM | Primary path for shapes/text |
| Raster export | Flutter/Skia | PNG, JPEG, WebP |
| Video/audio | **FFmpeg** | Post-MVP; subprocess or FFI wrapper |

## Collaboration

| Choice | Notes |
|--------|-------|
| **WebRTC** + ICE | Direct P2P; STUN/TURN as optional user config |
| **mDNS** | LAN discovery with explicit user approval |
| **Audited Rust/crypto crates** | Ed25519, X25519, AEAD — no custom primitives |

Protocol detail: [../protocol/](../protocol/protocol-layers.md).

## AI

| Choice | Notes |
|--------|-------|
| Abstract **provider interface** in `ai_engine` | OpenAI-compatible HTTP, local Ollama/llama.cpp |
| Keys in **OS secure storage** | Never in project files or CRDT |

See [ai-architecture.md](ai-architecture.md).

## Platforms

**Primary:** Windows, macOS, Linux (desktop).

**Later:** Android, iOS, optional web viewer — out of scope until desktop MVP ships.

## Licensing

Project license: **Apache-2.0** ([ADR-0001](../adr/0001-project-license-apache-2.md)). Every bundled library must be recorded in `DEPENDENCIES` and `THIRD_PARTY_NOTICES` before release.

## What we are not building

- Mandatory hosted backend for editing
- Central document database for collaboration
- Bundled commercial AI keys or stock photo deals tied to the app vendor
