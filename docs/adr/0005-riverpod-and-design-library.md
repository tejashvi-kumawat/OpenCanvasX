# ADR-0005: Riverpod for UI state, one seam for design files

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

The editor shell (P1.10) needs shared, testable state: the open design, undo history, viewport, panels and settings. The docs did not choose a state-management approach. Widget tests that performed real file I/O inside Flutter's fake-async test zone proved flaky on Windows (handles left open).

## Decision

1. **Riverpod** (`flutter_riverpod`, MIT) holds app state. Controllers are `Notifier`s (`EditorController`, `ViewportController`, `ProjectsFolderController`, `ThemeModeController`); the app index is injected with `appIndexProvider.overrideWithValue(...)` in `main()`.
2. **All design-file access goes through `DesignLibrary`** (`apps/desktop/lib/src/library/design_library.dart`): list, create, open, save. Production uses `FileDesignLibrary` (backed by `storage`); tests use an in-memory library. Folder picking, folder checks and folder creation are injectable providers for the same reason.
3. Widgets never touch `dart:io` directly; real file behaviour is tested in `packages/storage` with real temporary folders.

## Consequences

- Screens are fully testable with fakes; the app's `flutter test` needs no disk access.
- One dependency (`flutter_riverpod` + `riverpod`, MIT) recorded in `DEPENDENCIES`.
- New file features (export P1.9, snapshots P1.8.3) extend `DesignLibrary` rather than calling `storage` from widgets.
