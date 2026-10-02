# Testing strategy

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

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
- `melos run test:packages --no-select` and `melos run test --no-select`
- `cargo test --manifest-path rust/Cargo.toml`
- Desktop build on Linux, macOS, Windows (see `.github/workflows/ci.yml`)
