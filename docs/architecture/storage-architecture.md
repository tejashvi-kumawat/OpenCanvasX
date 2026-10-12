# Storage architecture

Storage covers **where projects live on disk**, how metadata is indexed, and how assets and snapshots are retained. Package: `packages/storage`.

## Project home

User picks a **projects root** on first launch (see product onboarding). Each project is a directory:

```
MyProject/
  project.opencanvasx    # or unpacked folder layout
  .ocx/                   # app metadata (optional hidden dir)
    index.sqlite
    cache/
    snapshots/
```

Single-file `.opencanvasx` ZIP is portable; directory layout suits Git and diff-friendly workflows.

## SQLite index

Used for fast listing and search, not as the authoritative document store (that is `document.json` inside the project).

Suggested tables:

| Table | Purpose |
|-------|---------|
| `projects` | id, path, title, modified_at, pinned |
| `recent` | ordered recent opens |
| `assets` | hash, mime, size, path, license_json |
| `search_fts` | FTS5 on text extracted from last saved document |

Rebuild FTS on save or background job after idle.

## Content-addressed assets

- Hash: SHA-256.
- Path: `{project}/assets/sha256/{hash}` or inside ZIP.
- Import: stream to temp, hash, dedupe, move into place.
- Delete: garbage-collect unreferenced hashes on save (with user opt-in for “optimize project”).

## Autosave

- Debounced save after edits (configurable interval).
- Atomic write: temp file + rename, or write new ZIP to `.opencanvasx.tmp` then replace.
- Crash recovery: open last good autosave if main file truncated.

## Snapshots and backup

| Mechanism | Description |
|-----------|-------------|
| Named checkpoint | User-triggered; stored under `snapshots/` with label |
| Automatic rolling | Keep last N autosnapshots (settings) |
| External backup | User points to copy target (drive, NAS, Syncthing) |

Sync tools are **user-operated**. On conflict, surface two versions; never silently pick winner.

## Collaboration local state

While in a session, device holds:

- Pending outbound ops queue
- Last synced vector clock / op id watermark
- Encrypted session state in secure storage, not in `.opencanvasx`

See [sync-spec.md](../protocol/sync-spec.md).

## Related

- [file-format.md](file-format.md)
- [document-model.md](document-model.md)
