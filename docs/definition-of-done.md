# Definition of done

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

A checklist item or PR is **done** when:

1. Behavior matches the relevant doc/spec section.
2. Unit tests cover core logic; integration tests where network/files involved.
3. `melos run analyze` and tests pass; Rust clippy/tests pass for Rust changes.
4. User-visible changes noted in `docs/` when behavior or format changes.
5. No secrets, keys, or proprietary third-party content introduced.
6. [checklist.md](checklist.md) item marked `[x]` only after the above.

Aligns with [agent-guide.md](agent-guide.md).
