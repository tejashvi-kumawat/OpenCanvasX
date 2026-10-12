# CRDT and operation log

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 34. CRDT / COLLABORATION DATA MODEL

Do not synchronize entire documents for every change.

Synchronize operations.

Example:
- object created
- object moved
- object resized
- text changed
- color changed
- layer reordered
- page added
- page deleted

Every operation should include:
- operation ID
- actor/device ID
- sequence number
- document ID
- logical clock information
- operation type
- payload
- authentication/signature
- protocol version

Replay protection:
- reject already processed operation IDs
- reject invalid sequence numbers
- validate signatures
- validate document/session binding

## 60. CONFLICT MANAGEMENT

Use deterministic merge rules.

Examples:
- independent object edits merge
- text edits use CRDT-aware text model
- simultaneous deletion/update follows explicit tombstone rules
- page order uses sequence CRDT
- permissions use owner-authoritative policy

Never rely on wall-clock timestamps alone.
