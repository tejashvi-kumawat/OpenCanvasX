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


## Implementation (plugin API 1)

- **Manifest** `plugin.json`: `id` (reverse-DNS style), `name`, `version`, `api` (1), `author`, `description`, `permissions` (`read_selection`, `read_document`, `write_document`, `network`), `entry.command` (program + arguments, run in the plugin folder; `..` refused) and `commands` (`id`, `title`, `inputs` of type `text` / `number` / `select` / `color`). Unknown permissions block installation. `packages/plugins_sdk` `PluginManifest`.
- **Approval** (P6.1.3): the install dialog lists permissions in plain words; approval is stored with the manifest's SHA-256 and the approved permissions — a changed manifest must be reviewed again. Plugins are **unsigned** for now (signature verification pending).
- **Runtime** (P6.1.2, partial): one process per run, empty environment (only `PATH`/`SYSTEMROOT` to start programs), working directory = plugin folder, request JSON on stdin, one JSON object on stdout, 15 s timeout, 10 MB output cap, killed on overrun. This isolates OpenCanvasX's memory and secrets but not the file system or network; therefore code plugins run only with **Developer mode** on (as this document required), with a warning in the Apps panel.
- **Protocol**: request `{api, command, inputs, page, selection?, document?}` (selection/document only with read permissions); response `{"operations": [...]}` with `create_shape`, `create_text`, `create_svg` (sanitised), `update`, `delete`, `notify`. Every operation is validated (permission, numbers finite and within ±1 000 000, colours `#RRGGBB[AA]`, text ≤ 20 000 chars, ≤ 2 000 operations, ids on the page); one invalid operation rejects the whole response. Results apply as **one undo step** named after the plugin.
- **Examples** in `plugins/` (Python, standard library): placeholder text, palette generator, rename layers, bar chart.
- Tests cover hostile manifests and responses, timeouts, crashes, output floods, permission checks and the environment.
