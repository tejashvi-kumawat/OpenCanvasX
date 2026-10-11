# ADR-0003: Global object map with page-rooted layer order

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

[document-model.md](../architecture/document-model.md) asks Phase 1 to choose between one global object map and a per-page partition, and recommends a global map with `page_id` on root-level objects. We also need a way to generate the stable object ids it requires, and a value-type style for the model that later layers (undo, CRDT) can rely on.

## Decision

1. **One global map** `ObjectId → DesignObject` per document.
2. **Root objects carry `pageId`**; nested objects carry only `parentId`. Exactly one of the two is set on every object.
3. **Z-order is explicit and ordered back-to-front** (index 0 is drawn first): a group's `childIds` orders its children; a page's `objectIds` orders its root objects.
4. **Ids are random UUID v4 strings** generated from `Random.secure()` inside `document_model`. No third-party UUID package is added.
5. **Model types are immutable values** that validate their own invariants on construction (`ArgumentError`); cross-object rules (parent/child links, page membership) are checked by validator functions that return a list of issues instead of throwing.

## Consequences

- Moving a root object between pages changes one `pageId` and two page order lists; nested objects are untouched.
- Every edit produces new values, which suits command-based undo (P1.8) and later CRDT operations (Phase 4).
- Validators can report every problem in an untrusted file at once, supporting repair UI rather than failing on the first error.
- UUID v4 generation is a few lines of code with no new dependency. Ids are identifiers, not secrets.
