# Release process

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 71. UPDATE SYSTEM

Options:
- manual update
- optional automatic update
- package-manager update

Update verification:
- signed release
- checksum
- secure distribution

Users can disable automatic updates.

## GitHub Releases (OpenCanvasX)

1. Tag `vX.Y.Z` on vetted commit (phase exit gate or patch).
2. Workflow `.github/workflows/release.yml` builds Linux artifact, writes `SHA256SUMS.txt`.
3. Signing placeholders: Windows (`WINDOWS_SIGNING`), Apple (`APPLE_SIGNING`) — configure in maintainer docs.
4. Users verify checksum before install; optional in-app update checks signature + hash.
