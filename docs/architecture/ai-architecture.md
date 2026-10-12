# AI architecture

AI is **optional**. No vendor subscription is bundled. Package: `packages/ai_engine`.

## Modes

| Mode | Data leaves device? |
|------|---------------------|
| Off | No |
| Local (Ollama, llama.cpp, compatible server) | No (LAN to user machine only) |
| BYOK cloud | Yes — user’s provider account |
| Custom endpoint | Per user configuration |

## Provider interface

Abstract `AiProvider`:

- `complete(prompt, options)` → text stream
- Optional: `embed`, `imageGenerate` if provider supports
- Configuration: endpoint, model, timeout, max tokens, temperature
- **No API key** in interface return values; key loaded from secure storage per request

Implementations: OpenAI-compatible HTTP, Anthropic adapter (if needed), local HTTP adapter.

## Secret handling

- Keys in OS keychain/credential store.
- Never in `.opencanvasx`, never in CRDT, never in logs ([ocx_logging](../implementation/p0-foundation.md) redaction).

## Privacy UI

Before any cloud call, show:

- Provider name
- Summary of what will be sent (page, selection, document per user choice)

Modes labeled **Local** vs **Cloud** in panel chrome.

## Features (phased)

**MVP:** rewrite text, short layout suggestions, basic prompt templates.

**Later:** palette/hierarchy suggestions, accessibility hints, image gen via user’s image API.

## Cost visibility

When provider returns usage metadata, show approximate tokens/requests; user caps in settings ([product telemetry doc](../product/telemetry-and-privacy-policy.md)).

## Related

- [agent-architecture.md](agent-architecture.md)
- [extensibility-apis.md](extensibility-apis.md)
