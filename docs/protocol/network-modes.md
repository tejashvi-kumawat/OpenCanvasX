# Network modes and UI

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 28. COLLABORATION

Primary model:
- Local-first
- Peer-to-peer
- End-to-end encrypted

No central document database.

Modes:

1. Same LAN
2. Direct Internet P2P
3. Optional relay
4. User-provided relay

Transport candidates:
- LAN
- mDNS
- WebRTC
- ICE
- STUN
- TURN
- QUIC where appropriate

## 62. COLLABORATION STATUS UI

Display:
- Local
- LAN
- Direct P2P
- Relayed
- Offline
- Synchronizing
- Synced
- Conflict detected

Do not hide network mode from users.

## 94. INTERNET DISCOVERY

Do not expose listening ports unnecessarily.

Use:
- outbound connection
- ICE
- STUN
- secure signaling where used
- TURN only when necessary

Never ask ordinary users to manually port-forward unless advanced mode is enabled.

## 95. ZERO-INFRASTRUCTURE MODE

The application should support:
- QR handshake
- local network collaboration
- manual signaling
- direct connection where possible

This mode can operate without any vendor-owned server.

## 96. OPTIONAL INFRASTRUCTURE MODE

Advanced users can configure:
- signaling URL
- STUN URL
- TURN URL
- TURN credentials
- self-hosted collaboration relay

This lets companies run everything on their own infrastructure.
