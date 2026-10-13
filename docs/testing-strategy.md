# Testing strategy

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 100. TESTING

Unit:
- document model
- CRDT
- crypto wrappers
- permissions
- serialization
- templates

Integration:
- P2P
- LAN
- NAT traversal
- relay
- reconnect
- offline sync
- asset transfer

Security:
- malformed invitations
- expired invitations
- replay
- MITM simulation
- unauthorized peer
- revoked peer
- malicious template
- malicious SVG
- malformed PDF
- malicious plugin
- invalid CRDT operation

Performance:
- 10k objects
- 100k operations
- large assets
- 100+ pages
- multiple collaborators

## CI (OpenCanvasX)

- `melos run analyze --no-select`
- `melos run test:packages --no-select` (pure-Dart packages, `dart test`) and `melos run test --no-select` (Flutter packages — the app and `renderer` — with `flutter test`)
- `cargo test --manifest-path rust/Cargo.toml`
- Desktop build on Linux, macOS, Windows (see `.github/workflows/ci.yml`)

## Performance (Phase 1 exit gate)

"1k-object document stays responsive" is checked two ways:

- `packages/design_engine/test/performance_test.dart` (tag `performance`) builds a 1,000-object page and measures the per-frame operations (median of 15 runs, JIT): snap-target collection ~1.7 ms (< 50), snapping one move ~1 ms (< 8), click hit test < 1 ms (< 8), moving and undoing one object < 0.5 ms (< 8), moving 100 objects < 0.5 ms (< 16), encoding/decoding the document ~3/7 ms (< 200/300).
- The app widget test "performance: dragging on a 1,000-object page" previews 20 drag steps with the inspector open and guards against accidental O(n²) per-frame work (median frame < 400 ms in debug mode; release is several times faster). Painting 1,000 shapes in the renderer takes ~8 ms in debug.
