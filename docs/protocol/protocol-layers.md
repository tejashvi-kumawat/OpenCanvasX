# Collaboration protocol layers

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 88. COLLABORATION PROTOCOL

Protocol layers:

Layer 0:
Discovery

Layer 1:
Invitation

Layer 2:
Identity verification

Layer 3:
Key establishment

Layer 4:
Secure session

Layer 5:
Authorization

Layer 6:
CRDT synchronization

Layer 7:
Asset synchronization

Layer 8:
Presence/comments

Layer 9:
Versioning

## 89. CONNECTION FLOW

A creates document.

A clicks Collaborate.

System:
1. Creates collaboration session.
2. Creates ephemeral invitation.
3. Generates QR.
4. Displays fingerprint.
5. Waits for peer.

B scans.

B:
1. Parses invitation.
2. Validates expiry.
3. Validates signature.
4. Displays host identity.
5. Requests user approval.

After approval:
1. Perform key agreement.
2. Authenticate peers.
3. Establish encrypted session.
4. Run ICE.
5. Prefer direct P2P.
6. Fall back to relay if configured.
7. Synchronize document metadata.
8. Synchronize missing operations.
9. Synchronize assets.
10. Start collaboration.
