# ADR-0004: Product name OpenCanvasX

- **Status:** Accepted
- **Date:** 2026-10-12

## Context

Phase 0 docs, specification and code used the working name "Open Design Studio" (`ods_` prefixes, `open_design_studio` app package, `.designstudio` files, `DS://join` invitations, `com.opendesignstudio.*` app ids). The repository is `tejashvi-kumawat/OpenCanvasX`, and the Phase 0 `repository` URLs pointed to a GitHub account that does not exist. No project files had been written by users, so renaming had no migration cost.

## Decision

The product is **OpenCanvasX** everywhere:

| Thing | Before | After |
|-------|--------|-------|
| Product name in docs and UI | Open Design Studio | OpenCanvasX |
| Specification file | `Open_Design_Studio_Complete_Specification.md` | `OpenCanvasX_Complete_Specification.md` |
| Code prefix | `ods_` / `Ods` | `ocx_` / `Ocx` (`ocx_logging`, `ocx_native_bridge`, Rust `ocx_native`) |
| Desktop app package / binary | `open_design_studio` | `opencanvasx` |
| App id (macOS, Linux) | `com.opendesignstudio.*` | `com.opencanvasx.opencanvasx` |
| Project file extension | `.designstudio` | `.opencanvasx` |
| Project metadata dir | `.ods/` | `.ocx/` |
| Invitation URI scheme | `DS://join/…` | `ocx://join/…` |
| Repository URL (melos, Cargo) | `github.com/open-design-studio/open-design-studio` | `github.com/tejashvi-kumawat/OpenCanvasX` |

`.ocx` alone is deliberately **not** used as a file extension: Windows already associates it with ActiveX controls.

JSON keys inside `.opencanvasx` files are **snake_case**, matching the field tables in [file-format.md](../architecture/file-format.md). This closes the open choice for P1.1.4.

## Consequences

- Old names must not be reintroduced; a repo-wide search for `design studio`, `ods_` and `designstudio` should return nothing.
- Per-user app data folders derive from the new ids, so the rename had to land before P1.1.5–P1.1.7 write any settings.
