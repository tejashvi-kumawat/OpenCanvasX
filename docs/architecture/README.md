# Architecture documentation

Hand-maintained design docs for OpenCanvasX. Edit in Git; do not autogenerate this folder.

Master spec (reference only): [OpenCanvasX_Complete_Specification.md](../../OpenCanvasX_Complete_Specification.md).

## Read in this order (implementation order)

Follow this sequence when building or onboarding — each doc assumes the ones above.

| # | Document | Phase focus |
|---|----------|-------------|
| 1 | [overview.md](overview.md) | System map and package roles |
| 2 | [tech-stack-decision.md](tech-stack-decision.md) | Flutter, Rust, storage, collab stack |
| 3 | [document-model.md](document-model.md) | In-memory truth: pages, objects, layers |
| 4 | [file-format.md](file-format.md) | `.opencanvasx` on-disk layout and migration |
| 5 | [storage-architecture.md](storage-architecture.md) | Projects dir, SQLite index, autosave, snapshots |
| 6 | [rendering-architecture.md](rendering-architecture.md) | Scene graph, tiles, GPU path |
| 7 | [export-architecture.md](export-architecture.md) | Import/export pipelines |
| 8 | [asset-architecture.md](asset-architecture.md) | Asset metadata, validation, collab by hash |
| 9 | [template-architecture.md](template-architecture.md) | Templates, brand, repos, resize |
| 10 | [performance-budget.md](performance-budget.md) | Scale targets and test thresholds |
| 11 | [extensibility-apis.md](extensibility-apis.md) | Public API surfaces and stability |
| 12 | [plugin-architecture.md](plugin-architecture.md) | Plugins, permissions, sandbox |
| 13 | [ai-architecture.md](ai-architecture.md) | BYOK, local AI, privacy UI |
| 14 | [agent-architecture.md](agent-architecture.md) | Tool-calling agents and approvals |

Hard decisions: add an [ADR](../adr/README.md).

Collaboration wire protocol: [../protocol/README.md](../protocol/README.md) (Phase 4).
