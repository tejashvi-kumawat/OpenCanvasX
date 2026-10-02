OPEN DESIGN STUDIO
COMPLETE PRODUCT + ARCHITECTURE SPECIFICATION
Version 1.0
Status: Product and technical master specification

============================================================
0. PRODUCT VISION
============================================================

Open Design Studio is a free, open-source, local-first, cross-platform visual creation suite inspired by the broad functionality people use in Canva, presentation tools, lightweight publishing tools, diagram tools, and creative editors.

The objective is NOT to copy Canva's proprietary templates, assets, code, branding, or copyrighted content.

The objective is to provide comparable categories of functionality using:
- Original software
- Original templates
- Openly licensed assets
- Community-created assets/templates
- User-provided assets
- Procedurally generated layouts
- Local computation
- Optional user-provided AI API keys
- Peer-to-peer collaboration
- User-controlled storage

Core principles:
1. Free for end users.
2. No mandatory account.
3. No mandatory cloud.
4. No mandatory subscription.
5. No mandatory hosted website.
6. Offline-first.
7. Local files are the source of truth.
8. Collaboration is peer-to-peer whenever possible.
9. End-to-end encryption for collaboration.
10. AI is BYOK (Bring Your Own Key) and/or local-model based.
11. No vendor lock-in.
12. Open and documented project format.
13. Export without artificial watermarks or subscription gates.
14. User owns their files.
15. Users can use their own storage, network, relay, and AI provider.

============================================================
1. PRODUCT POSITIONING
============================================================

Primary positioning:

"Professional design software that is free, local-first, private, open, and extensible."

The application should cover:

- Graphic design
- Social media design
- Presentations
- Documents
- Posters
- Flyers
- Resumes
- Certificates
- Invitations
- Business cards
- Infographics
- Whiteboards
- Diagrams
- Mind maps
- Charts
- Simple video compositions
- Simple motion graphics
- Brand kits
- Publishing
- PDF export
- SVG export
- PNG/JPEG/WebP export
- PPTX-compatible workflows where technically feasible
- Template-based design
- Community templates
- Asset management
- Local AI
- BYOK AI
- Agentic design workflows
- Real-time P2P collaboration

============================================================
2. PLATFORM TARGETS
============================================================

Primary:
- Windows
- macOS
- Linux

Future:
- Android
- iOS
- iPadOS
- Web viewer/editor if technically useful

Desktop should remain the primary full-featured implementation.

The application must work without an Internet connection for core editing.

============================================================
3. NO HOSTED WEBSITE REQUIREMENT
============================================================

The product itself does not require a hosted website.

The downloadable application is distributed through:
- GitHub Releases
- GitLab Releases
- Codeberg or another open-source forge
- Package repositories
- Direct release artifacts
- Optional third-party software stores

Possible artifacts:
- Windows installer
- Windows portable ZIP
- macOS DMG
- macOS universal package
- Linux AppImage
- Linux .deb
- Linux .rpm
- Flatpak
- Android APK
- iOS App Store build if later distributed

A project website is optional.

If a public website is desired, it can be hosted independently using:
- GitHub Pages
- GitLab Pages
- Cloudflare Pages
- Netlify
- Google Sites
- another static hosting provider

The core application must NOT depend on that website.

The application must never require:
https://something.yourdomain.com

for normal operation.

============================================================
4. OPTIONAL SELF-HOSTED / LOCAL SERVICES
============================================================

Users may optionally run:
- Signaling server
- STUN server
- TURN server
- Template repository
- Asset repository
- Team file server
- WebDAV server
- S3-compatible storage
- Git repository
- Syncthing
- NAS
- Local network server

These are optional.

The official product should remain usable without them.

============================================================
5. APPLICATION ARCHITECTURE
============================================================

High-level:

Application
|
+-- UI Layer
|
+-- Design Engine
|
+-- Document Engine
|
+-- Template Engine
|
+-- Asset Engine
|
+-- Typography Engine
|
+-- Export Engine
|
+-- Media Engine
|
+-- Collaboration Engine
|
+-- Security Engine
|
+-- AI Engine
|
+-- Agent Engine
|
+-- Plugin Engine
|
+-- Local Storage
|
+-- Import/Export Adapters
|
+-- Platform Services

============================================================
6. CORE DESIGN ENGINE
============================================================

Canvas:
- Infinite canvas option
- Fixed page canvas
- Multiple pages
- Artboards
- Custom dimensions
- Presets
- DPI settings
- Pixel dimensions
- Physical dimensions
- Unit selection
- mm
- cm
- inches
- px
- points

Page:
- Background color
- Background image
- Background gradient
- Background transparency
- Page bleed
- Margins
- Safe areas
- Guides

Objects:
- Text
- Rich text
- Rectangle
- Rounded rectangle
- Circle
- Ellipse
- Polygon
- Star
- Line
- Arrow
- Path
- Freehand drawing
- Pen tool
- Image
- SVG
- Video
- Audio
- Chart
- Table
- QR code
- Barcode
- Frame
- Group
- Component
- Embedded document

Object transforms:
- Move
- Resize
- Rotate
- Scale
- Skew
- Flip horizontal
- Flip vertical
- Position X/Y
- Width
- Height
- Rotation
- Opacity
- Anchor point

Alignment:
- Left
- Center
- Right
- Top
- Middle
- Bottom
- Distribute horizontally
- Distribute vertically
- Equal spacing
- Snap to page
- Snap to object
- Snap to grid
- Smart guides

Layers:
- Layer tree
- Groups
- Nested groups
- Lock
- Hide
- Rename
- Reorder
- Duplicate
- Isolate
- Group/ungroup
- Clipping
- Masking
- Blend modes

History:
- Undo
- Redo
- History panel
- Named checkpoints
- Document snapshots
- Restore snapshot

============================================================
7. VECTOR ENGINE
============================================================

Support:
- SVG import
- SVG export
- Paths
- Bézier curves
- Boolean operations
- Union
- Subtract
- Intersect
- Exclude
- Offset path
- Stroke expansion
- Stroke alignment
- Fill
- Stroke
- Dashed stroke
- Gradient fill
- Pattern fill
- Clipping paths
- Masks
- Opacity
- Blend modes

SVG should remain as native as possible instead of rasterizing unnecessarily.

============================================================
8. TEXT AND TYPOGRAPHY
============================================================

Features:
- Font family
- Font weight
- Font style
- Font size
- Letter spacing
- Line height
- Paragraph spacing
- Alignment
- Justification
- Text box
- Auto width
- Auto height
- Text on path
- Text effects
- Outline
- Shadow
- Gradient text
- Character-level formatting
- Paragraph-level formatting
- Lists
- Bullets
- Numbering
- Superscript
- Subscript
- Links
- OpenType features
- Ligatures
- Variable fonts
- Font embedding where legally permitted
- Font substitution
- Font fallback
- Font preview
- Local font discovery

Support open-license font collections.

Do not bundle fonts without checking their licenses.

============================================================
9. COLOR SYSTEM
============================================================

Support:
- RGB
- RGBA
- HEX
- HSL
- HSV
- CMYK where appropriate
- LAB where technically feasible
- Color picker
- Eyedropper
- Swatches
- Custom palettes
- Gradient editor
- Linear gradients
- Radial gradients
- Conic gradients
- Transparency
- Brand palettes
- Accessibility contrast checking

============================================================
10. IMAGE FEATURES
============================================================

Import:
- PNG
- JPEG
- WebP
- GIF
- TIFF where supported
- BMP
- SVG
- AVIF where supported

Editing:
- Crop
- Resize
- Rotate
- Flip
- Brightness
- Contrast
- Saturation
- Hue
- Exposure
- Blur
- Sharpen
- Transparency
- Background removal where local model/tool permits
- Mask
- Clipping
- Rounded corners
- Image filters
- Color adjustments
- Duotone
- Pixelation
- Blur regions

Non-destructive editing should be preferred.

============================================================
11. IMAGE ASSET SYSTEM
============================================================

Asset types:
- Photos
- Illustrations
- Icons
- SVGs
- Shapes
- Stickers
- Patterns
- Textures
- Frames
- Mockups
- Backgrounds
- Gradients

Asset metadata:
- ID
- Source
- Author
- License
- License URL
- Attribution requirement
- Tags
- Categories
- Dimensions
- Format
- Hash

Asset sources must be legally compatible with redistribution.

Never scrape and redistribute Canva assets.

============================================================
12. TEMPLATE SYSTEM
============================================================

Template categories:
- Instagram
- Facebook
- LinkedIn
- YouTube
- TikTok
- X
- Posters
- Flyers
- Brochures
- Resumes
- CVs
- Certificates
- Invitations
- Business cards
- Menus
- Newsletters
- Presentations
- Pitch decks
- Reports
- Infographics
- Calendars
- Planners
- Worksheets
- Event posters
- College posters
- Startup materials
- Marketing materials
- Educational materials
- Printable materials

Templates are editable design documents, not flattened screenshots.

Template metadata:
- Template ID
- Author
- Version
- License
- Category
- Tags
- Dimensions
- Required assets
- Font dependencies
- Preview
- Compatibility version

============================================================
13. TEMPLATE ECOSYSTEM
============================================================

Three sources:

1. Official original templates
2. Community templates
3. User-generated private templates

Official templates must be created independently.

Community templates require contributor licensing/terms.

Users must be able to:
- Publish
- Unpublish
- Fork
- Duplicate
- Modify
- Rate
- Tag
- Search
- Filter
- Report

No central service is required for private templates.

Community repositories can be hosted independently.

============================================================
14. TEMPLATE GENERATOR
============================================================

Create designs from layout recipes.

Recipe:
- Typography
- Grid
- Spacing
- Color palette
- Components
- Image slots
- Text slots
- CTA slots
- Header
- Footer
- Decorative elements

One recipe can generate many variants.

Support:
- Random variation
- Controlled variation
- Brand constraints
- Size adaptation
- Platform adaptation

============================================================
15. MAGIC RESIZE / RESPONSIVE DESIGN
============================================================

Convert:
- Instagram square -> Story
- Presentation -> poster
- A4 -> Letter
- LinkedIn post -> Instagram post
- 16:9 -> 4:3
- Desktop banner -> mobile banner

Preserve:
- hierarchy
- typography
- alignment
- safe areas
- image crop

Allow manual correction after automatic resize.

============================================================
16. BRAND KIT
============================================================

Brand:
- Logo
- Logo variants
- Colors
- Fonts
- Typography styles
- Icons
- Image style
- Spacing rules
- Brand templates

Apply brand kit to:
- New designs
- Existing designs
- Templates
- AI-generated layouts

Brand validation:
- incorrect colors
- incorrect fonts
- logo misuse
- contrast issues

============================================================
17. PRESENTATION SYSTEM
============================================================

Slides:
- Multiple slides
- Master slides
- Layouts
- Slide templates
- Presenter notes
- Slide transitions
- Animations
- Embedded media
- Charts
- Tables
- Shapes
- Speaker view
- Full-screen presentation

Export:
- PDF
- Images
- PPTX where technically feasible
- Video where technically feasible

============================================================
18. WHITEBOARD
============================================================

Infinite canvas:
- Sticky notes
- Text
- Shapes
- Connectors
- Freehand
- Images
- Documents
- Frames
- Tables
- Mind maps
- Diagrams
- Comments

Collaboration-ready.

============================================================
19. DIAGRAM ENGINE
============================================================

Diagram types:
- Flowcharts
- UML
- ER diagrams
- Sequence diagrams
- State diagrams
- Network diagrams
- Architecture diagrams
- Organization charts
- BPMN
- Mind maps

Import/export:
- SVG
- PNG
- PDF
- Mermaid where supported
- PlantUML where supported
- Graphviz DOT where supported
- Draw.io XML where compatible

============================================================
20. CHARTS AND DATA VISUALIZATION
============================================================

Chart types:
- Bar
- Line
- Area
- Pie
- Donut
- Scatter
- Bubble
- Radar
- Histogram
- Heatmap
- Funnel
- Waterfall
- Timeline

Input:
- Manual data
- CSV
- JSON
- TSV
- Clipboard
- Spreadsheet-compatible data

Formatting:
- Axis
- Legend
- Labels
- Grid
- Colors
- Fonts
- Tooltips
- Data tables

============================================================
21. TABLES
============================================================

Features:
- Insert table
- Add/remove rows
- Add/remove columns
- Merge cells
- Split cells
- Borders
- Fill
- Alignment
- Number formatting
- Sorting
- Basic formulas

============================================================
22. PDF SYSTEM
============================================================

Export:
- PDF
- PDF/A where supported
- Rasterized PDF option
- Vector PDF where possible
- Bleed
- Crop marks
- Page size
- DPI
- Compression
- Metadata

Import PDF pages as editable or placed objects where technically possible.

Integration with Document Studio:
- Open PDF in Document Studio
- Send design to PDF editor
- Edit exported PDF
- OCR
- Merge
- Sign
- Redact

============================================================
23. PRINTING
============================================================

Support:
- Page size
- Orientation
- Margins
- Bleed
- Crop marks
- Printer selection
- Print preview
- Copies
- Page ranges
- Scaling
- Fit to page
- Actual size
- Duplex where supported by OS

============================================================
24. VIDEO / MOTION
============================================================

Basic video composition:
- Video import
- Trim
- Crop
- Position
- Scale
- Text overlays
- Shapes
- Transitions
- Audio
- Timeline
- Simple keyframes
- Opacity animation
- Position animation
- Scale animation
- Rotation animation

Export using FFmpeg where appropriate.

============================================================
25. AUDIO
============================================================

Support:
- Audio import
- Trim
- Volume
- Fade
- Multiple tracks
- Mute
- Voiceover
- Background music
- Waveform preview

============================================================
26. ANIMATION
============================================================

Animation:
- Fade
- Slide
- Scale
- Rotate
- Pop
- Typewriter
- Wipe
- Custom keyframes

Timeline:
- Tracks
- Keyframes
- Duration
- Easing
- Playback
- Preview

============================================================
27. QR / BARCODE
============================================================

Generate:
- QR
- URL QR
- Wi-Fi QR
- Contact QR
- Email QR
- Text QR
- Collaboration invite QR

Barcode support where legally and technically appropriate.

============================================================
28. COLLABORATION
============================================================

Primary model:
- Local-first
- Peer-to-peer
- End-to-end encrypted

No central document database.

Modes:

1. Same LAN
2. Direct Internet P2P
3. Optional relay
4. User-provided relay

Transport candidates:
- LAN
- mDNS
- WebRTC
- ICE
- STUN
- TURN
- QUIC where appropriate

============================================================
29. COLLABORATION INVITATION
============================================================

User selects:
"Collaborate"

Generate:
- Short-lived invitation
- One-time nonce
- Session ID
- Host identity
- Public key information
- Expiration
- Signature

Display:
- QR code
- Copy invitation
- Optional local share

Invitation:
- expires
- is single-use
- is session-bound
- does not contain private keys
- does not contain document plaintext

============================================================
30. COLLABORATION AUTHENTICATION
============================================================

Every installation has:
- Device identity
- Public key
- Private key

Private key:
- Never transmitted
- Stored in OS secure storage

Peer verification:
- Public-key fingerprint
- Optional manual verification
- Explicit accept/reject

Never trust a display name alone.

============================================================
31. COLLABORATION AUTHORIZATION
============================================================

Roles:
- Owner
- Admin
- Editor
- Commenter
- Viewer

Permissions:
- View
- Edit
- Comment
- Invite
- Export
- Download
- Manage permissions
- Delete
- Change document settings

============================================================
32. END-TO-END ENCRYPTION
============================================================

Use established cryptographic libraries.

Recommended primitives:
- Ed25519 for signatures
- X25519 for key agreement
- AES-256-GCM or ChaCha20-Poly1305 for AEAD
- HKDF-SHA-256 for key derivation
- Cryptographically secure random generation

Do not implement cryptographic primitives manually.

Transport encryption:
- WebRTC DTLS/SRTP or equivalent secure transport

Application-level encryption:
- Encrypt collaboration payloads before transport where practical.

============================================================
33. DOCUMENT KEYS
============================================================

Each collaborative document gets a random document key.

Document key is not transmitted as plaintext.

Access is granted to authorized peers through secure key establishment/key wrapping.

When a user is revoked:
- invalidate session
- revoke capability
- rotate document key
- distribute new key only to authorized peers

============================================================
34. CRDT / COLLABORATION DATA MODEL
============================================================

Do not synchronize entire documents for every change.

Synchronize operations.

Example:
- object created
- object moved
- object resized
- text changed
- color changed
- layer reordered
- page added
- page deleted

Every operation should include:
- operation ID
- actor/device ID
- sequence number
- document ID
- logical clock information
- operation type
- payload
- authentication/signature
- protocol version

Replay protection:
- reject already processed operation IDs
- reject invalid sequence numbers
- validate signatures
- validate document/session binding

============================================================
35. OFFLINE COLLABORATION
============================================================

Users can continue editing offline.

Each device stores:
- local operations
- snapshots
- pending operations

When peers reconnect:
- exchange missing operations
- verify signatures
- decrypt
- merge
- create consistent state

============================================================
36. ASSET COLLABORATION
============================================================

Assets identified by content hash.

Example:
SHA-256(asset bytes)

If peer already has asset:
- do not transfer again

If not:
- transfer encrypted chunks

Support:
- resumable transfers
- integrity verification
- duplicate elimination
- chunk hashing
- compression where useful

============================================================
37. SECURITY HARDENING
============================================================

Required:
- Secure key storage
- Memory-safe implementation where possible
- Input validation
- Signed operations
- Replay protection
- Session expiration
- Invitation expiration
- Single-use invitations
- Capability-based permissions
- Key rotation
- Secure random generation
- Certificate/fingerprint verification where applicable
- No plaintext secrets in logs
- No API keys in project files by default
- Secure deletion best effort
- Locked documents
- Optional local password
- Optional application lock
- Optional encrypted project container

Threat model:
- Malicious network
- Rogue peer
- Stolen invitation
- Replay attack
- MITM
- Malicious template
- Malicious plugin
- Malicious asset
- Compromised relay
- Compromised local account
- Malicious project file

The final protocol should receive professional security review before production claims of high assurance.

============================================================
38. LOCAL PASSWORD / PROJECT ENCRYPTION
============================================================

Optional project password.

Project:
- encrypted at rest
- authenticated
- key derived from password using a modern password KDF

Never store:
- raw password
- raw API keys
- private keys in plaintext project metadata

============================================================
39. AI SYSTEM
============================================================

AI is optional.

No AI subscription is required from the application vendor.

Modes:

1. Local AI
2. BYOK cloud AI
3. User's own local server
4. OpenAI-compatible endpoint
5. Custom provider
6. No AI

============================================================
40. BYOK AI
============================================================

Users can enter their own API keys.

Provider examples can include:
- OpenAI-compatible APIs
- Anthropic-compatible APIs
- Google-compatible APIs
- Local Ollama-compatible servers
- Local llama.cpp servers
- Other compatible providers

The architecture should use an abstract provider interface.

AI configuration:
- provider
- endpoint
- model
- API key
- temperature
- max tokens
- context size
- timeout
- retry policy

API keys:
- stored in OS secure storage
- never placed in documents
- never synced through CRDT
- never sent to collaborators
- never logged

============================================================
41. AI DESIGN FEATURES
============================================================

AI can:
- Generate copy
- Rewrite text
- Shorten text
- Expand text
- Change tone
- Translate
- Generate design briefs
- Generate color palettes
- Generate layout suggestions
- Generate presentation outlines
- Generate social media captions
- Generate template metadata
- Suggest typography
- Suggest spacing
- Suggest hierarchy
- Analyze accessibility
- Analyze design consistency
- Generate chart descriptions
- Convert text to structured layouts
- Create components
- Rename layers
- Organize layers
- Detect alignment problems
- Suggest improvements

============================================================
42. AI IMAGE FEATURES
============================================================

Where a user provides an image-generation API:
- Text to image
- Image variations
- Background generation
- Background replacement
- Inpainting where provider supports it
- Outpainting where provider supports it
- Style variations

All external API costs belong to the user.

No provider API key is bundled by default.

============================================================
43. AI AGENT SYSTEM
============================================================

Create an agent framework capable of performing multi-step design operations.

Agent:
- receives goal
- plans
- selects tools
- executes
- validates
- asks for approval when required
- produces result

Example:

User:
"Create a professional startup pitch deck from this document."

Agent:
1. Read document
2. Extract key information
3. Create outline
4. Select template
5. Create slides
6. Generate charts
7. Apply brand kit
8. Check typography
9. Check overflow
10. Produce draft
11. Ask user for approval
12. Export

============================================================
44. AGENT TOOL SYSTEM
============================================================

Tools:
- create_page
- delete_page
- duplicate_page
- create_text
- edit_text
- create_shape
- edit_shape
- insert_image
- crop_image
- create_group
- rename_layer
- move_layer
- reorder_layer
- align_objects
- distribute_objects
- apply_style
- apply_brand
- import_asset
- search_local_assets
- search_templates
- create_chart
- create_table
- export_pdf
- export_png
- export_svg
- inspect_document
- inspect_overflow
- inspect_alignment
- inspect_accessibility
- create_presentation
- create_diagram
- create_mindmap

Agents must operate through explicit, auditable tools rather than unrestricted filesystem access.

============================================================
45. AGENT SECURITY
============================================================

Default:
- Agent sandbox
- Explicit permissions
- Tool allowlist
- Read/write boundaries
- No arbitrary shell commands
- No arbitrary network access
- No access to secrets
- No access to private files unless user grants it
- Confirmation for destructive operations

High-risk actions require confirmation:
- Delete document
- Export sensitive data
- Share document
- Upload file
- Call external AI
- Execute code
- Modify project permissions

============================================================
46. AI PRIVACY
============================================================

The application must clearly show:

LOCAL:
Data stays on device.

BYOK CLOUD:
Selected content is sent to user's selected provider.

REMOTE PROVIDER:
The app must display provider name before transmission.

Never silently upload user content to an AI service.

============================================================
47. PLUGIN SYSTEM
============================================================

Allow third-party plugins.

Plugin capabilities:
- New importers
- New exporters
- New tools
- New templates
- New asset packs
- New AI providers
- New diagram types
- New effects

Security:
- Permission declarations
- Sandboxed plugins where feasible
- No unrestricted access by default
- User approval before installation
- Plugin signature support
- Version compatibility

============================================================
48. COMMAND PALETTE
============================================================

Global shortcut:
Ctrl/Cmd + K

Commands:
- New design
- Open
- Save
- Export
- Insert
- Duplicate
- Group
- Ungroup
- Align
- Search templates
- Search assets
- Run AI
- Collaborate
- Change page
- Add page
- Open settings

Fuzzy search.

============================================================
49. KEYBOARD SHORTCUTS
============================================================

Support common shortcuts:
- Ctrl/Cmd + Z
- Ctrl/Cmd + Shift + Z
- Ctrl/Cmd + C
- Ctrl/Cmd + V
- Ctrl/Cmd + X
- Ctrl/Cmd + D
- Ctrl/Cmd + S
- Ctrl/Cmd + O
- Ctrl/Cmd + N
- Delete
- Shift for proportional scaling
- Alt/Option duplication
- Arrow movement
- Shift + arrow movement
- Zoom shortcuts

Allow custom shortcut mapping.

============================================================
50. ACCESSIBILITY
============================================================

Features:
- Keyboard navigation
- Screen-reader-friendly controls where supported
- High contrast
- Large UI mode
- Reduced motion
- Focus indicators
- Color contrast checker
- Alt text
- Accessible PDF metadata
- Reading order where supported

============================================================
51. SEARCH
============================================================

Global search:
- Documents
- Templates
- Assets
- Projects
- Layers
- Text
- Fonts
- Commands
- Plugins

Local indexing.

No mandatory cloud search.

============================================================
52. FILE FORMAT
============================================================

Native format should be open and documented.

Suggested:
.designstudio

Structure:
- version
- document metadata
- pages
- objects
- styles
- assets
- fonts metadata
- animations
- collaboration metadata
- AI metadata where applicable

Avoid storing API keys.

Support version migration.

============================================================
53. IMPORT
============================================================

Target:
- SVG
- PNG
- JPEG
- WebP
- PDF
- JSON
- CSV
- TXT
- Markdown
- HTML where practical
- PPTX where practical
- DOCX where practical
- Draw.io XML
- Mermaid
- PlantUML
- Graphviz DOT

Some formats may have partial fidelity.

============================================================
54. EXPORT
============================================================

Target:
- PNG
- JPEG
- WebP
- SVG
- PDF
- PDF/A where possible
- GIF
- MP4
- WebM
- PPTX where practical
- HTML
- JSON
- SVG sprite
- print-ready PDF

============================================================
55. VERSION CONTROL
============================================================

Local history:
- snapshots
- named versions
- restore
- compare

Optional external:
- Git
- Syncthing
- WebDAV
- NAS
- SFTP

============================================================
56. FILE SYNC
============================================================

Do not require company-owned cloud storage.

Optional:
- Syncthing
- WebDAV
- SFTP
- SMB
- NAS
- Git
- user-provided S3-compatible storage

Conflict handling:
- detect divergent versions
- offer merge
- preserve both versions
- never silently overwrite

============================================================
57. TEAM WORKSPACES
============================================================

Workspace can exist entirely locally or on user-owned storage.

Features:
- projects
- folders
- templates
- brand kits
- shared assets
- permissions
- comments
- version history

============================================================
58. COMMENTS
============================================================

Comments attached to:
- page
- object
- text range

Features:
- add
- edit
- resolve
- reopen
- mention collaborator
- timestamp
- author identity

Comments are synchronized through CRDT.

============================================================
59. PRESENCE
============================================================

Show:
- online users
- cursor
- selected object
- current page
- editing indicator

Presence data is ephemeral and should not become permanent document content unless explicitly saved.

============================================================
60. CONFLICT MANAGEMENT
============================================================

Use deterministic merge rules.

Examples:
- independent object edits merge
- text edits use CRDT-aware text model
- simultaneous deletion/update follows explicit tombstone rules
- page order uses sequence CRDT
- permissions use owner-authoritative policy

Never rely on wall-clock timestamps alone.

============================================================
61. NETWORK FAILURE
============================================================

When connection drops:
- continue local editing
- queue operations
- show offline state
- retry
- synchronize when connection returns

Never discard unsynchronized work.

============================================================
62. COLLABORATION STATUS UI
============================================================

Display:
- Local
- LAN
- Direct P2P
- Relayed
- Offline
- Synchronizing
- Synced
- Conflict detected

Do not hide network mode from users.

============================================================
63. TEMPLATE/ASSET LICENSE SYSTEM
============================================================

Every distributed asset should carry:
- license
- source
- author
- attribution requirement
- redistribution permission
- modification permission

Template repository must reject assets without known licensing metadata.

Users must be able to inspect license information.

============================================================
64. COMMUNITY MARKETPLACE WITHOUT MANDATORY SERVER
============================================================

The application can support repository URLs.

Example:
- Git repository
- static JSON repository
- HTTPS asset index
- local folder repository

Repository format:
index.json
templates/
assets/
previews/
licenses/

Users can add repositories manually.

Official repository is optional.

============================================================
65. SECURITY OF TEMPLATES AND PLUGINS
============================================================

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

============================================================
66. LOCAL DATABASE
============================================================

Possible technologies:
- SQLite
- JSON
- filesystem blobs

SQLite can store:
- project metadata
- search index
- asset metadata
- template metadata
- operation index

Large binary assets should be stored as files/blobs with hashes.

============================================================
67. PERFORMANCE
============================================================

Requirements:
- GPU rendering where available
- incremental rendering
- object virtualization
- page virtualization
- lazy image loading
- thumbnail caching
- asset caching
- background indexing
- background export
- worker threads
- memory limits
- large-document optimization

Target:
- thousands of objects per document
- hundreds of pages where practical
- large image assets
- long presentations

============================================================
68. LARGE DOCUMENT HANDLING
============================================================

Use:
- tiled rendering
- lazy loading
- mipmaps
- cached previews
- incremental serialization
- background asset decoding

Avoid loading every asset into RAM simultaneously.

============================================================
69. OFFLINE MODE
============================================================

Core features available offline:
- create
- edit
- save
- import
- export
- templates
- local assets
- local AI
- local collaboration on LAN
- document history

Internet-dependent:
- remote AI provider
- remote template repository
- remote asset repository
- Internet P2P negotiation where required

============================================================
70. TELEMETRY
============================================================

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

============================================================
71. UPDATE SYSTEM
============================================================

Options:
- manual update
- optional automatic update
- package-manager update

Update verification:
- signed release
- checksum
- secure distribution

Users can disable automatic updates.

============================================================
72. CRASH REPORTING
============================================================

Default:
- local crash logs

Optional:
- user-initiated crash report

Never automatically upload:
- documents
- images
- API keys
- private collaboration data

============================================================
73. DESIGN SYSTEM
============================================================

UI:
- Professional desktop UI
- Dark mode
- Light mode
- Custom theme
- Resizable panels
- Dockable panels
- Context toolbar
- Layers panel
- Assets panel
- Templates panel
- Inspector
- Properties
- History
- Comments
- Collaboration panel
- AI panel

============================================================
74. MAIN UI
============================================================

Top:
- File
- Edit
- View
- Insert
- Arrange
- Text
- Design
- Present
- Collaborate
- AI
- Plugins
- Help

Left:
- Templates
- Assets
- Elements
- Text
- Uploads
- Brand
- Projects

Center:
- Canvas

Right:
- Inspector
- Layers
- Properties
- AI
- Comments

Bottom:
- Zoom
- Page navigation
- Collaboration state

============================================================
75. ONBOARDING
============================================================

First launch:
- Create identity
- Choose local storage directory
- Optional import
- Optional local AI
- Optional BYOK
- Optional template repositories
- Privacy explanation

No mandatory account creation.

============================================================
76. PROJECT MANAGEMENT
============================================================

Projects:
- Create
- Rename
- Duplicate
- Archive
- Delete
- Export
- Import
- Backup
- Restore

Recent documents.

Favorites.

Pinned projects.

Search.

============================================================
77. BACKUP
============================================================

Local:
- automatic snapshots
- configurable retention
- backup directory

User-owned:
- external drive
- NAS
- Syncthing
- cloud drive folder

No mandatory company backup.

============================================================
78. AI DOCUMENT CONTEXT
============================================================

User can choose:
- current page
- selected objects
- entire document
- selected text
- specific assets
- project folder

Before sending externally, show:
"These items will be sent to provider X."

============================================================
79. AGENT APPROVAL LEVELS
============================================================

Modes:
1. Ask every action
2. Ask destructive actions
3. Trusted within selected project
4. Fully autonomous within sandbox

Default should be conservative.

============================================================
80. AI COST CONTROL
============================================================

Show:
- estimated token usage where provider exposes it
- request count
- model
- provider
- approximate cost where available

Allow:
- model selection
- max output
- context limits
- disable image generation
- local-only mode

============================================================
81. LOCAL AI
============================================================

Support local model runtimes through adapters:
- Ollama-compatible
- llama.cpp-compatible
- other local OpenAI-compatible servers

Local AI can perform:
- writing
- classification
- extraction
- layout planning
- document analysis
- agent actions

Hardware requirements should be displayed.

============================================================
82. AI MODEL SECURITY
============================================================

Never allow an AI model to:
- read all files by default
- execute arbitrary commands
- access private keys
- access API keys
- silently upload documents

Agent permissions must be explicit.

============================================================
83. EXTENSIBILITY
============================================================

APIs:
- document model API
- renderer API
- plugin API
- exporter API
- importer API
- AI provider API
- asset provider API
- template provider API
- collaboration protocol API

Document format should be versioned.

============================================================
84. OPEN SOURCE LICENSE STRATEGY
============================================================

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

============================================================
85. LEGAL CONTENT RULE
============================================================

Do not copy:
- Canva templates
- Canva proprietary assets
- Canva UI artwork
- Canva source code
- Canva logos
- proprietary template metadata

Build independent implementations.

Use:
- original designs
- open-license assets
- user-generated content
- compatible third-party libraries

============================================================
86. SUGGESTED TECHNOLOGY STACK
============================================================

Frontend:
- Flutter
- Dart

Native components:
- Rust or C/C++ where high-performance native code is required

Graphics:
- Skia/Impeller/Flutter rendering
- SVG engine
- GPU acceleration

Storage:
- SQLite
- filesystem
- content-addressed assets

PDF:
- qpdf
- PDFium
- MuPDF/Poppler depending on licensing and feature requirements
- Tesseract for OCR

Media:
- FFmpeg

Networking:
- WebRTC
- ICE
- STUN/TURN
- QUIC where useful

Cryptography:
- audited cryptographic libraries

AI:
- provider adapters
- local model adapters

============================================================
87. REPOSITORY STRUCTURE
============================================================

open-design-studio/
|
+-- apps/
|   +-- desktop/
|   +-- mobile/
|
+-- packages/
|   +-- design_engine/
|   +-- document_model/
|   +-- renderer/
|   +-- template_engine/
|   +-- asset_engine/
|   +-- typography/
|   +-- export_engine/
|   +-- pdf/
|   +-- media/
|   +-- collaboration/
|   +-- crdt/
|   +-- crypto/
|   +-- networking/
|   +-- identity/
|   +-- ai/
|   +-- agents/
|   +-- plugins/
|   +-- search/
|   +-- storage/
|
+-- templates/
|
+-- assets/
|
+-- plugins/
|
+-- protocols/
|
+-- docs/
|
+-- scripts/
|
+-- tests/
|
+-- third_party/
|
+-- LICENSE
+-- THIRD_PARTY_NOTICES
+-- README.md

============================================================
88. COLLABORATION PROTOCOL
============================================================

Protocol layers:

Layer 0:
Discovery

Layer 1:
Invitation

Layer 2:
Identity verification

Layer 3:
Key establishment

Layer 4:
Secure session

Layer 5:
Authorization

Layer 6:
CRDT synchronization

Layer 7:
Asset synchronization

Layer 8:
Presence/comments

Layer 9:
Versioning

============================================================
89. CONNECTION FLOW
============================================================

A creates document.

A clicks Collaborate.

System:
1. Creates collaboration session.
2. Creates ephemeral invitation.
3. Generates QR.
4. Displays fingerprint.
5. Waits for peer.

B scans.

B:
1. Parses invitation.
2. Validates expiry.
3. Validates signature.
4. Displays host identity.
5. Requests user approval.

After approval:
1. Perform key agreement.
2. Authenticate peers.
3. Establish encrypted session.
4. Run ICE.
5. Prefer direct P2P.
6. Fall back to relay if configured.
7. Synchronize document metadata.
8. Synchronize missing operations.
9. Synchronize assets.
10. Start collaboration.

============================================================
90. LINK-BASED INVITATION
============================================================

A can copy an invitation string.

It should be:
- short-lived
- one-time
- session-specific
- signed
- non-sensitive
- no private key
- no document plaintext

The application should recognize:
DS://join/...

without requiring a public website.

The OS can register the custom URI scheme.

============================================================
91. NO-WEBSITE JOIN
============================================================

Example:

DS://join/<opaque-invitation>

User opens it.

Operating system launches Design Studio.

The application handles the invitation locally.

No:
- website
- subdomain
- web login
- account
- hosted dashboard

required.

============================================================
92. PUBLIC WEBSITE OPTIONAL
============================================================

If a website exists, it is only:
- documentation
- downloads
- source code
- release notes
- community information

The application must not depend on it.

A static site is sufficient.

============================================================
93. LOCAL DISCOVERY
============================================================

On same network:
- mDNS
- service discovery
- QR
- manual local IP

Example:
"Tejashvi's Design Studio is available nearby."

Still require explicit approval.

============================================================
94. INTERNET DISCOVERY
============================================================

Do not expose listening ports unnecessarily.

Use:
- outbound connection
- ICE
- STUN
- secure signaling where used
- TURN only when necessary

Never ask ordinary users to manually port-forward unless advanced mode is enabled.

============================================================
95. ZERO-INFRASTRUCTURE MODE
============================================================

The application should support:
- QR handshake
- local network collaboration
- manual signaling
- direct connection where possible

This mode can operate without any vendor-owned server.

============================================================
96. OPTIONAL INFRASTRUCTURE MODE
============================================================

Advanced users can configure:
- signaling URL
- STUN URL
- TURN URL
- TURN credentials
- self-hosted collaboration relay

This lets companies run everything on their own infrastructure.

============================================================
97. ENTERPRISE / TEAM MODE
============================================================

Optional features:
- company-owned relay
- company-owned template repository
- company-owned asset repository
- SSO adapter
- enterprise identity
- audit logs
- organization policies
- role management
- private plugins
- private templates
- private brand kits

These remain optional and do not affect the free local version.

============================================================
98. FREE PRODUCT BOUNDARIES
============================================================

The product should not artificially disable:
- exports
- pages
- designs
- local templates
- local assets
- collaboration
- offline work
- document history
- local AI

No:
- watermarks
- five-project limits
- three-export limits
- forced account
- subscription popup

============================================================
99. OPTIONAL PAID ECOSYSTEM
============================================================

If the project eventually needs revenue, revenue should come from optional services, not blocking core software.

Possible:
- managed relay
- hosted template repository
- hosted asset repository
- managed team collaboration
- enterprise support
- signed enterprise builds
- managed update infrastructure

The local application remains free.

============================================================
100. TESTING
============================================================

Unit:
- document model
- CRDT
- crypto wrappers
- permissions
- serialization
- templates

Integration:
- P2P
- LAN
- NAT traversal
- relay
- reconnect
- offline sync
- asset transfer

Security:
- malformed invitations
- expired invitations
- replay
- MITM simulation
- unauthorized peer
- revoked peer
- malicious template
- malicious SVG
- malformed PDF
- malicious plugin
- invalid CRDT operation

Performance:
- 10k objects
- 100k operations
- large assets
- 100+ pages
- multiple collaborators

============================================================
101. PHASED DEVELOPMENT
============================================================

PHASE 1:
Core editor
- Canvas
- Objects
- Text
- Layers
- Undo/redo
- Save/open
- SVG
- PNG
- PDF

PHASE 2:
Template and asset system
- Template engine
- Asset manager
- Brand kit
- Search
- Original template library

PHASE 3:
Professional design
- Vector tools
- Masks
- Boolean operations
- Advanced typography
- Charts
- Tables
- Presentations
- Whiteboard

PHASE 4:
Collaboration
- Identity
- QR invitations
- LAN
- CRDT
- Encryption
- Direct P2P
- STUN
- TURN adapter
- Comments
- Presence

PHASE 5:
AI
- BYOK
- Local AI
- AI panel
- Tool calling
- Agent system
- Permission sandbox

PHASE 6:
Ecosystem
- Plugins
- Community templates
- Community assets
- Repository support
- Import/export expansion

============================================================
102. MVP
============================================================

MVP must contain:
- Canvas
- Pages
- Layers
- Text
- Shapes
- Images
- SVG
- Basic vector editing
- Templates
- Assets
- Brand kit
- PNG export
- SVG export
- PDF export
- Local project files
- Offline operation

Collaboration MVP:
- QR
- Identity
- P2P
- E2E encryption
- Basic CRDT
- Two-user editing
- LAN
- Direct Internet where possible

AI MVP:
- BYOK provider
- Local model endpoint
- Text rewrite
- Layout generation
- Basic agent tools

============================================================
103. POST-MVP
============================================================

- Video
- Audio
- Advanced animation
- Advanced presentation
- Diagram engine
- Community repository
- Plugin marketplace/repository
- Advanced AI agents
- Team administration
- Mobile clients

============================================================
104. CORE PRODUCT DIFFERENTIATORS
============================================================

1. Completely free core application.
2. No mandatory cloud.
3. No mandatory account.
4. No mandatory subscription.
5. Offline-first.
6. Local files.
7. P2P collaboration.
8. E2E encryption.
9. User-controlled infrastructure.
10. BYOK AI.
11. Local AI.
12. Agentic automation.
13. Open project format.
14. Open-source code.
15. No artificial export restrictions.
16. No forced watermark.
17. Community templates.
18. Community assets.
19. Extensible plugin architecture.

============================================================
105. SECURITY PROMISE
============================================================

Do not claim:
"perfect security"
"unhackable"
"100% secure"

Instead communicate technically verifiable properties:
- End-to-end encrypted collaboration
- Private keys stay on devices
- No central document storage
- Local-first
- Short-lived invitations
- Explicit peer approval
- Signed operations
- Replay protection
- Capability-based permissions
- Optional key rotation
- Optional self-hosted relay

============================================================
106. FINAL SYSTEM
============================================================

                     OPEN DESIGN STUDIO
                             |
        +--------------------+--------------------+
        |                    |                    |
     DESIGN               CONTENT             AI
        |                    |                    |
   Vector engine         Templates          Local models
   Canvas                Assets             BYOK
   Typography            Brand kits         Agents
   Layers                Media              Tools
   Animation             Documents          Automation
        |                    |                    |
        +--------------------+--------------------+
                             |
                       DOCUMENT MODEL
                             |
                       LOCAL STORAGE
                             |
                     +-------+-------+
                     |               |
                 Offline         Collaboration
                                     |
                          +----------+----------+
                          |          |          |
                         LAN       P2P        Relay
                          |          |          |
                        mDNS      WebRTC      TURN
                                     |
                                E2E ENCRYPTION
                                     |
                              CRDT OPERATIONS
                                     |
                           AUTHENTICATED PEERS

The product remains usable without:
- hosted website
- company cloud
- company database
- company storage
- company AI
- mandatory account
- mandatory subscription

Optional external services are user-controlled.

============================================================
107. FINAL PRINCIPLE
============================================================

The software should provide the capabilities.

The user should control:
- their files
- their storage
- their identity
- their collaboration
- their AI provider
- their API keys
- their network
- their templates
- their assets
- their infrastructure

The company should not need to become the permanent middleman for ordinary usage.

END OF SPECIFICATION
