# ADR-0002: Flutter UI with Rust native core

- **Status:** Accepted
- **Date:** 2026-10-02

## Context

Cross-platform desktop primary; performance and crypto paths need a memory-safe native layer.

## Decision

Flutter/Dart for UI; Rust workspace `rust/ocx_native` exposed via `flutter_rust_bridge`.

## Consequences

Dual toolchain in CI; codegen step in `scripts/codegen_rust_bridge.sh`.
