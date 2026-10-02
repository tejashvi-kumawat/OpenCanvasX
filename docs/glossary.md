# Glossary

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

| Term | Definition |
|------|------------|
| BYOK | Bring Your Own Key — user-supplied AI API credentials |
| CRDT | Conflict-free replicated data type for mergeable edits |
| Document key | Symmetric key for encrypting collaborative session payloads |
| E2E | End-to-end encryption; keys not available to relay/server |
| `.designstudio` | Native project archive format |
| Operation log | CRDT sync unit (create/move/edit), not full document snapshots |
| P2P | Peer-to-peer collaboration without central document DB |
| Relay | Optional TURN/signaling helper; does not store document plaintext |
