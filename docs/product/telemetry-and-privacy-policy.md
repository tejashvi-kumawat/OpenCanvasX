# Telemetry and privacy

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 70. TELEMETRY

Default:
- OFF

No mandatory analytics.

If telemetry is ever added:
- opt-in
- transparent
- documented
- anonymous where possible
- never collect document content
- never collect API keys
- never collect private project data

## 72. CRASH REPORTING

Default:
- local crash logs

Optional:
- user-initiated crash report

Never automatically upload:
- documents
- images
- API keys
- private collaboration data

## 46. AI PRIVACY

The application must clearly show:

LOCAL:
Data stays on device.

BYOK CLOUD:
Selected content is sent to user's selected provider.

REMOTE PROVIDER:
The app must display provider name before transmission.

Never silently upload user content to an AI service.

## 78. AI DOCUMENT CONTEXT

User can choose:
- current page
- selected objects
- entire document
- selected text
- specific assets
- project folder

Before sending externally, show:
"These items will be sent to provider X."

## Implementation (P1.11)

- **No telemetry.** The app contains no analytics, usage pings or update checks.
- **Network inventory.** Core editing, saving, versions, templates from folders, asset packs, fonts, plugins and every export format run with no network access; a widget test refuses all HTTP connections (`HttpOverrides`) while editing, saving and exporting in every format and asserts that no connection was attempted. The only code that can open connections is opt-in and user-initiated: online template sources the user adds (`HttpTemplateRepository`, sha256-verified downloads) and an AI provider the user configures (cloud requests are shown and confirmed first; local providers stay on the machine).
- **Local crash logs.** Unhandled Flutter and platform errors are appended to `<app data>/logs/crash-YYYY-MM-DD.log` after secret redaction (`SecretRedactor`: key/token/password assignments, bearer tokens, PEM blocks, `sk-…` provider keys including `sk-ant-…`/`sk-proj-…`, invite links). The newest 10 files are kept. Nothing is uploaded; the command palette's "Open crash logs folder" lets the user look at and share a log themselves.
