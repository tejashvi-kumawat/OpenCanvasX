# Dependency policy

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 84. OPEN SOURCE LICENSE STRATEGY

The project should use a license compatible with all dependencies.

Each dependency must be audited for:
- license
- redistribution
- static/dynamic linking requirements
- attribution
- notice requirements
- patent clauses
- source distribution requirements

Do not assume "open source" means "no obligations."

Maintain:
THIRD_PARTY_NOTICES
LICENSES
DEPENDENCIES

## Repository files

| File | Purpose |
|------|---------|
| `DEPENDENCIES` | Machine-readable list with licenses |
| `THIRD_PARTY_NOTICES` | Human summary |
| `LICENSES/` | Full license texts for bundled components |

New dependencies require license classification before merge.
