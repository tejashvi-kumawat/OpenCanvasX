# Threat model

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

## 37. SECURITY HARDENING

Required:
- Secure key storage
- Memory-safe implementation where possible
- Input validation
- Signed operations
- Replay protection
- Session expiration
- Invitation expiration
- Single-use invitations
- Capability-based permissions
- Key rotation
- Secure random generation
- Certificate/fingerprint verification where applicable
- No plaintext secrets in logs
- No API keys in project files by default
- Secure deletion best effort
- Locked documents
- Optional local password
- Optional application lock
- Optional encrypted project container

Threat model:
- Malicious network
- Rogue peer
- Stolen invitation
- Replay attack
- MITM
- Malicious template
- Malicious plugin
- Malicious asset
- Compromised relay
- Compromised local account
- Malicious project file

The final protocol should receive professional security review before production claims of high assurance.

## 65. SECURITY OF TEMPLATES AND PLUGINS

Templates should be declarative data.

Templates should NOT execute arbitrary code.

Plugins are separate and permission-controlled.

Assets are treated as untrusted input.

Validate:
- SVG
- images
- PDFs
- archives
- metadata
- fonts

Avoid malicious embedded content.
