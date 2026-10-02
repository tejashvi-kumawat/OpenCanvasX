# Telemetry and privacy

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

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
