# Cryptography specification

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 32. END-TO-END ENCRYPTION

Use established cryptographic libraries.

Recommended primitives:
- Ed25519 for signatures
- X25519 for key agreement
- AES-256-GCM or ChaCha20-Poly1305 for AEAD
- HKDF-SHA-256 for key derivation
- Cryptographically secure random generation

Do not implement cryptographic primitives manually.

Transport encryption:
- WebRTC DTLS/SRTP or equivalent secure transport

Application-level encryption:
- Encrypt collaboration payloads before transport where practical.

## 33. DOCUMENT KEYS

Each collaborative document gets a random document key.

Document key is not transmitted as plaintext.

Access is granted to authorized peers through secure key establishment/key wrapping.

When a user is revoked:
- invalidate session
- revoke capability
- rotate document key
- distribute new key only to authorized peers
