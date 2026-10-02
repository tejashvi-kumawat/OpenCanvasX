# Agent architecture

Agents perform **multi-step design tasks** using a fixed tool API rather than free-form file or shell access. Package: `packages/agents`.

## Control loop

```
User goal → planner (LLM) → tool calls → validate → (optional) user approval → repeat → done
```

Planner runs against configured `AiProvider` ([ai-architecture.md](ai-architecture.md)).

## Tool design

Tools are small, auditable functions exposed to the model as JSON schema:

- Document: `create_page`, `create_text`, `edit_text`, `create_shape`, `align_objects`, …
- Inspect: `inspect_document`, `inspect_overflow`, `inspect_alignment`, `inspect_accessibility`
- Assets/templates: `search_local_assets`, `search_templates`, `apply_brand`
- Export: `export_pdf`, `export_png`, `export_svg` (with confirmation if overwriting)

Each invocation logged locally (tool name, args summary — no secrets).

## Approval levels

| Level | Behavior |
|-------|----------|
| Ask every action | Safest default |
| Destructive only | Confirm delete, share, external AI |
| Trusted project | Auto within allowlist for session |
| Autonomous sandbox | Post-MVP; still no shell/network unless granted |

Destructive examples: delete document, share collab, upload file, change permissions.

## Sandbox rules

- No arbitrary shell or filesystem paths.
- No reading secure storage or other apps’ files.
- Network only through `AiProvider` and declared plugin hosts.
- Model output that suggests code execution is rejected.

## Example flow

User: “Pitch deck from this outline.”

Agent: read outline → plan slides → pick template → create pages → fill text → apply brand → run overflow inspect → present draft → user approves export.

## Related

- [ai-architecture.md](ai-architecture.md)
- [document-model.md](document-model.md)
