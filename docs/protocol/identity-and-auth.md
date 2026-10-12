# Identity and authentication

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 30. COLLABORATION AUTHENTICATION

Every installation has:
- Device identity
- Public key
- Private key

Private key:
- Never transmitted
- Stored in OS secure storage

Peer verification:
- Public-key fingerprint
- Optional manual verification
- Explicit accept/reject

Never trust a display name alone.

## 93. LOCAL DISCOVERY

On same network:
- mDNS
- service discovery
- QR
- manual local IP

Example:
"Tejashvi's OpenCanvasX is available nearby."

Still require explicit approval.
