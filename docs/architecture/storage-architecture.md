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

### App-wide index (P1.1.6)

Recent documents are app-wide, not per project, so they live in an `index.sqlite` in the app's per-user data folder (derived from the app id `com.opencanvasx.opencanvasx`; the app passes the path in). Implemented by `RecentDocuments` (`storage/lib/src/recent_documents.dart`) with the `sqlite3` package:

```sql
CREATE TABLE recent (
  path TEXT PRIMARY KEY NOT NULL,   -- absolute path of the .opencanvasx file
  title TEXT NOT NULL,
  document_id TEXT,                 -- manifest document_id, when known
  opened_at INTEGER NOT NULL        -- UTC microseconds since epoch
);
```

- Schema version in `PRAGMA user_version` (currently `1`); an index from a newer build is refused rather than altered.
- Re-recording a path moves it to the top; the list is trimmed to a limit (default 20).
- `pruneMissing()` drops entries whose file no longer exists. Paths stay on the device.

## Content-addressed assets

- Hash: SHA-256.
- Path: `{project}/assets/sha256/{hash}` or inside ZIP.
- Import: stream to temp, hash, dedupe, move into place.
- Delete: garbage-collect unreferenced hashes on save (with user opt-in for “optimize project”).

## Autosave

- Debounced save after edits (configurable interval).
- Atomic write: temp file + rename, or write new ZIP to `.opencanvasx.tmp` then replace.
- Crash recovery: open last good autosave if main file truncated.

Implementation (`storage/lib/src/project_file.dart`, P1.1.5):

| Piece | Behaviour |
|-------|-----------|
| `writeProjectFile` | Writes `<file>.tmp`, flushes, decodes it back to verify, then renames over `<file>`; on any failure the temp file is removed and the previous file is untouched |
| `saveProject` | Explicit save: `writeProjectFile`, then deletes `<file>.autosave` |
| `Autosaver` | Debounced (default 2 s quiet period, configurable); saves never overlap; edits during a save trigger another; failures stay dirty and are reported to `onError`; `flush()` before close |
| Autosave target | `<file>.autosave` next to the project (`autosavePathFor`), a full `.opencanvasx` ZIP |
| `openProject` | Opens `<file>`; if it is missing or unreadable, opens the autosave instead (`ProjectSource.autosave`). If both are readable and the autosave is newer, opens `<file>` and sets `newerAutosaveAvailable` so the UI asks — never picks silently |

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
