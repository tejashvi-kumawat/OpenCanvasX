# Feature catalog

> **Source:** Derived from [Open_Design_Studio_Complete_Specification.md](../Open_Design_Studio_Complete_Specification.md).
> **Status:** Normative product/architecture documentation for Open Design Studio.

Tags used below: **MVP** · **Post-MVP** · **Later**

## 6. CORE DESIGN ENGINE

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

## 17. PRESENTATION SYSTEM

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

## 18. WHITEBOARD

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

## 19. DIAGRAM ENGINE

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

## 24. VIDEO / MOTION

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

## 28. COLLABORATION

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

## 39. AI SYSTEM

AI is optional.

No AI subscription is required from the application vendor.

Modes:

1. Local AI
2. BYOK cloud AI
3. User's own local server
4. OpenAI-compatible endpoint
5. Custom provider
6. No AI

## 47. PLUGIN SYSTEM

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

## MVP vs later (summary)

| Area | MVP | Post-MVP | Later |
|------|-----|----------|-------|
| Editor | §6 core, PNG/SVG/PDF | Presentations, charts, vectors | Video, advanced motion |
| Collab | QR, 2-user P2P, E2E, basic CRDT | Comments, presence | Enterprise SSO |
| AI | BYOK, local endpoint, basic tools | Full agents | — |
| Ecosystem | Local templates/assets | Community repos | Marketplace services |
