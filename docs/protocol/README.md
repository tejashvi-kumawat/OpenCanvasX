# Collaboration protocol documentation

P2P sessions, encryption, and sync (Phase 4+). Read after [document-model.md](../architecture/document-model.md) and [file-format.md](../architecture/file-format.md).

## Read in this order

| # | Document | Layer / topic |
|---|----------|----------------|
| 1 | [protocol-layers.md](protocol-layers.md) | Layers 0–9 map and connection flow |
| 2 | [network-modes.md](network-modes.md) | LAN, direct P2P, relay, UI status |
| 3 | [invitation-spec.md](invitation-spec.md) | QR, `DS://join/…`, expiry, single-use |
| 4 | [identity-and-auth.md](identity-and-auth.md) | Device keys, fingerprints, secure storage |
| 5 | [authorization-spec.md](authorization-spec.md) | Roles and capabilities |
| 6 | [crypto-spec.md](crypto-spec.md) | E2E primitives, document keys, rotation |
| 7 | [crdt-spec.md](crdt-spec.md) | Operation log, merge, text model |
| 8 | [sync-spec.md](sync-spec.md) | Offline queue, reconnect, asset chunks |

Security context: [../security/README.md](../security/README.md).

Machine-readable artifacts (later): [../../protocols/](../../protocols/).
