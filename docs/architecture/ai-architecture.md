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

## Implementation (P5)

- `packages/ai_engine`: `AiConfig` (kind, endpoint, model, temperature,
  max tokens, timeout; serialised **without** the key), `complete()` for
  OpenAI-compatible (`/chat/completions`), Anthropic (`/v1/messages`) and
  Ollama (`/api/chat`). Cloud endpoints must use https; `isLocal` treats
  localhost, private IPv4 ranges and `.local` hosts as local. Replies are
  capped at 8 MB and time out. Errors are `AiException` with a user
  message and never include the key.
- Prompts (`tasks.dart`): text tasks (rewrite, shorten, expand, formal,
  friendly, fix grammar, translate) wrap the text in `<text>` tags and ask
  for the new text only; design-from-prompt asks for the plugin operations
  protocol. The reply is parsed with `extractJsonObject` and applied
  through `applyPluginResponse` with **write permission only**, so AI
  output is validated exactly like an untrusted plugin and is one undo
  step ("AI design").
- App (`apps/desktop/lib/src/ai`): AI is **off** until set up (setting
  `ai.config`). Keys are stored with `flutter_secure_storage` (Windows
  Credential Manager / DPAPI, Keychain, libsecret) under
  `opencanvasx.ai.<kind>`. Before a cloud call a dialog names the provider
  and host and summarises what is sent (only the selected text, or the
  prompt and page size); local providers do not ask. "Don't ask again"
  lasts until the app closes. The AI rail tab shows Off / Local / Cloud,
  and a request log with characters sent and token usage (no content).

## Related

- [agent-architecture.md](agent-architecture.md)
- [extensibility-apis.md](extensibility-apis.md)
