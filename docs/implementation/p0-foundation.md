# Phase 0 foundation (implemented)

## Code

- Melos workspace: `apps/desktop`, 21 `packages/*` skeletons with passing unit tests.
- Rust workspace: `rust/ocx_native` + `flutter_rust_bridge` entry (`ocx_native_version`).
- `packages/ocx_logging`: structured logging + `SecretRedactor` (see tests in `packages/ocx_logging/test/redaction_test.dart`).
- `packages/ocx_native_bridge`: Phase 0 Dart stub; FRB codegen via `scripts/codegen_rust_bridge.sh`.

## Commands

```bash
./scripts/bootstrap.sh
melos run analyze --no-select
melos run test:packages --no-select
melos run test --no-select
cargo test --manifest-path rust/Cargo.toml
cd apps/desktop && flutter run -d linux
```

## Documentation

Architecture lives in [docs/architecture/](../architecture/README.md) and is **hand-maintained**.

See [docs/README.md](../README.md) for the full index.

## License

Apache-2.0 — [ADR-0001](../adr/0001-project-license-apache-2.md).
