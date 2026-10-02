# Invitation specification

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

## 29. COLLABORATION INVITATION

User selects:
"Collaborate"

Generate:
- Short-lived invitation
- One-time nonce
- Session ID
- Host identity
- Public key information
- Expiration
- Signature

Display:
- QR code
- Copy invitation
- Optional local share

Invitation:
- expires
- is single-use
- is session-bound
- does not contain private keys
- does not contain document plaintext

## 90. LINK-BASED INVITATION

A can copy an invitation string.

It should be:
- short-lived
- one-time
- session-specific
- signed
- non-sensitive
- no private key
- no document plaintext

The application should recognize:
DS://join/...

without requiring a public website.

The OS can register the custom URI scheme.

## 91. NO-WEBSITE JOIN

Example:

DS://join/<opaque-invitation>

User opens it.

Operating system launches Design Studio.

The application handles the invitation locally.

No:
- website
- subdomain
- web login
- account
- hosted dashboard

required.

## 27. QR / BARCODE

Generate:
- QR
- URL QR
- Wi-Fi QR
- Contact QR
- Email QR
- Text QR
- Collaboration invite QR

Barcode support where legally and technically appropriate.
