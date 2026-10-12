# Template architecture

Templates are **editable design documents**, not screenshots. Package: `packages/template_engine`.

## Template vs project

| | Template | User project |
|---|----------|--------------|
| Purpose | Starting point, reusable layout | Working file |
| Metadata | Category, license, required fonts/assets | User title, history |
| Mutation on use | Copied into new `document_id` on “Use template” | Direct edit |

## Template metadata

Stored beside or inside template file:

- `template_id`, `version`, `author`, `license`, `license_url`
- `category`, `tags`, `dimensions`, `preview` asset hash
- `required_assets[]`, `required_fonts[]`
- `min_app_version` / `schema_version` compatibility

## Sources

1. **Bundled** original templates (shipped with app or downloadable pack).
2. **User private** templates in a user folder.
3. **Community repositories** — user-added URL or Git checkout; no mandatory central server.

Repository layout (convention):

```
index.json
templates/*.opencanvasx
assets/sha256/*
previews/*
licenses/*
```

`index.json` entries point to template path, preview, license id.

## Declarative safety

Templates must not execute code. They are the same schema as [file-format.md](file-format.md) with optional **recipe** metadata for generator (below). Validation rejects unknown binary sections and script-like payloads.

## Template generator (later)

**Recipes** describe slots (title, body, image, CTA), grid, typography roles, and palette tokens. One recipe expands to many variants (size/platform). Generator runs locally; no cloud required.

## Magic resize

Separate engine rules map object constraints when changing canvas size (pin edges, reflow text, scale groups). Rules stored as metadata on template or brand kit, applied by `template_engine` + `design_engine`.

## Brand kit linkage

Brand kit supplies palette, logo hashes, font roles, tone hints. Templates reference brand **roles** (`primary`, `heading_font`) resolved at apply time.

## Related

- [asset-architecture.md](asset-architecture.md)
- [document-model.md](document-model.md)
