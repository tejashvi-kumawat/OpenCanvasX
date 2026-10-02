# Plugin architecture

Plugins extend importers, exporters, tools, asset sources, AI providers, and diagram types without forking core. SDK: `packages/plugins_sdk`.

## Manifest

Each plugin ships a manifest (JSON):

- `id`, `version`, `min_app_version`
- `permissions[]` — declared capability requests
- `entrypoint` — Dart isolate or native bridge (TBD per platform)
- Optional **signature** for trusted publishers

## Permission examples

| Permission | Grants |
|------------|--------|
| `read_document` | Selected objects or pages via API |
| `write_document` | Apply commands through design_engine |
| `read_assets` | List/import hashes |
| `network` | Explicit host allowlist |
| `export` | Register export format |

Default deny; user approves at install and per sensitive call where needed.

## Sandboxing

Phase 6 target: plugins run with least privilege — no raw filesystem glob, no env secrets, no shell. Until sandbox is complete, gate plugin support behind “developer mode” warning.

## Templates vs plugins

Templates are data. Plugins are code. Never blur the two (no “template” that runs scripts).

## Distribution

User adds plugin path or installs from signed bundle. Optional community repo lists plugin ids and download URLs (user-controlled).

## Related

- [extensibility-apis.md](extensibility-apis.md)
- [security/input-validation-policy.md](../security/input-validation-policy.md)
