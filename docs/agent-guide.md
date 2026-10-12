# Agent guide

## Workflow

1. Open [checklist.md](checklist.md) and find the first unchecked item in the current phase.
2. Read the relevant docs (folder READMEs list order): [product/](product/README.md), [architecture/](architecture/README.md), [protocol/](protocol/README.md), etc.
3. Implement in the repo; add tests per [testing-strategy.md](testing-strategy.md).
4. When you change behavior or on-disk formats, update **architecture** Markdown by hand.
5. Mark `[x]` only when CI-equivalent checks pass locally.
6. One checklist item → one commit (`P1.2.3: description`).

## Documentation policy

All of `docs/` is **hand-maintained** Markdown in Git. No doc generator scripts.

| Area | Index |
|------|--------|
| Product | [product/README.md](product/README.md) |
| Architecture | [architecture/README.md](architecture/README.md) |
| Protocol / security | [protocol/README.md](protocol/README.md), [security/README.md](security/README.md) |
| ADRs | [adr/README.md](adr/README.md) |
| Checklist / implementation | [checklist.md](checklist.md), [implementation/README.md](implementation/README.md) |

Reference (not auto-synced): [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).

## Blocked items

Use `[!]` and one line explaining the blocker. Do not skip items silently.

## Content rules

- No Canva copies ([legal-content-rules.md](product/legal-content-rules.md)).
- No secrets in files or logs.
- No hand-rolled crypto ([crypto-spec.md](protocol/crypto-spec.md)).
