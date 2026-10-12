# OpenCanvasX

Free, open-source, **local-first** visual design application — comparable categories to mainstream design tools, without mandatory cloud, accounts, or subscriptions.

## Status

**Phase 0** — monorepo scaffolding, architecture docs, CI, and empty desktop shell.

## Quick start

```bash
# Linux: install Flutter into .toolchain/ (once)
./scripts/install_flutter_linux.sh

# Bootstrap Dart packages
export PATH="$PWD/.toolchain/flutter/bin:$PATH"
dart pub get
dart run melos bootstrap

# Run desktop shell
cd apps/desktop && flutter run -d linux

# Tests
dart run melos test
cargo test --workspace --manifest-path rust/Cargo.toml
```

## Repository layout

```
apps/desktop/          Flutter desktop application
packages/              Dart engines and shared libraries
rust/ocx_native/       Rust native core (flutter_rust_bridge)
docs/                  Product, architecture, protocol, process docs
protocols/             Collaboration protocol artifacts (Phase 4+)
templates/ assets/ plugins/   Content and extensions (Phase 2+)
scripts/               Bootstrap, codegen, release helpers
```

## Documentation

Start at [docs/README.md](docs/README.md). Implementation tracking: [docs/checklist.md](docs/checklist.md).

## License

Apache-2.0 — see [LICENSE](LICENSE). Third-party notices: [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES).
