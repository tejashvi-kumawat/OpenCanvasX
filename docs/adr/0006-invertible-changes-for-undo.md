# ADR-0006: Data-level invertible changes for undo

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

document-model.md asks for a command stack holding inverse operations (P1.8.1) and for edits that decompose into collaboration operations later (Phase 4). Writing a hand-made inverse for every command is error-prone.

## Decision

Every edit is a **`Change`** (`packages/design_engine/lib/src/change.dart`): data listing objects to put or delete, optionally a replacement page list and metadata. `Change.applyTo(document)` returns the new document **and the exact inverse change**, computed from the previous values. `History` stores only inverses; undo applies one and pushes the resulting redo change.

High-level operations (`insertObjects`, `moveObjects`, `deleteObjects`, `pasteObjects`, `reorderObjects`, `alignObjects`, page operations, …) are pure functions that build `Change`s. Drags preview edits live and are committed as **one** change at the end (`beginGesture` / `previewObjects` / `endGesture`).

## Consequences

- Undo/redo is correct by construction for every operation, including ones added later.
- Object-level puts and deletes map directly onto `ObjectCreated` / `ObjectUpdated` / `ObjectDeleted` operations for the CRDT (Phase 4).
- Page-list replacements are coarse; Phase 4 will split them into page operations.
