# Performance budget

Targets guide implementation and CI benchmarks. Adjust with ADR if hardware assumptions change.

## Document scale (single user)

| Metric | Target |
|--------|--------|
| Objects per document | 10,000 without functional loss |
| Pages | 100+ (presentations); lazy page load |
| Pan/zoom | Interactive on mid-range GPU laptop (60 fps goal for typical docs) |
| Open/save | Progressive load; UI responsive within 1 s for medium projects |

## Collaboration scale

| Metric | Target |
|--------|--------|
| Operation log | 100,000 ops merge without corruption (test harness) |
| Concurrent editors | MVP: 2; stretch: 5 with acceptable latency on LAN |
| Asset transfer | Dedup by hash; resume interrupted chunks |

## Memory

- Do not decode all images at full resolution at open.
- Tile cache and thumbnail caches have configurable byte caps; LRU eviction.

## Rendering

- Incremental damage rects for edits.
- Virtualize off-screen pages in page strip and multi-page outline.

See [rendering-architecture.md](rendering-architecture.md).

## Testing

Performance tests live in `tests/` (Phase 1+):

- Synthetic doc generators (N objects, M pages).
- Collab stress: replay op logs.
- Export batch timing logged in CI (informational, not gating initially).

Functional gates remain in [testing-strategy.md](../testing-strategy.md).

## Offline

Core edit/save/export must meet same budgets offline; only network-dependent features degrade.

## Related

- [overview.md](overview.md)
- [storage-architecture.md](storage-architecture.md)
