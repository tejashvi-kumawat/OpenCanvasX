# Input validation policy

> **Source:** Derived from [OpenCanvasX_Complete_Specification.md](../OpenCanvasX_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for OpenCanvasX.

## 65. SECURITY OF TEMPLATES AND PLUGINS

Templates should be declarative data.

Templates should NOT execute arbitrary code.

Plugins are separate and permission-controlled.

Assets are treated as untrusted input.

Validate:
- SVG
- images
- PDFs
- archives
- metadata
- fonts

Avoid malicious embedded content.

## Validation checklist

- Size limits on uploads and embedded SVG/PDF streams
- Reject external entities in XML/SVG where disabled
- Scan archive depth and file count
- Font parsing via trusted libraries only
- Templates: schema validate; no script tags or remote URLs without user confirm
