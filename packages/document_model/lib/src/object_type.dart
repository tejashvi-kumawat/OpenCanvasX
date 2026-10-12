/// Phase 1 object kinds (document-model.md). Later kinds are added as their
/// checklist items land.
enum ObjectType {
  text,
  rect,
  roundedRect,
  ellipse,
  line,
  arrow,
  path,
  image,
  group,
  polygon,
  star,

  /// Artboard / container that clips its children (ADR-0007). Unlike a
  /// group it has its own box and style, and resizing it does not scale
  /// its contents.
  frame,
}

/// Kinds that hold children.
extension ObjectTypeContainers on ObjectType {
  bool get isContainer => this == ObjectType.group || this == ObjectType.frame;
}

/// Compositing mode used when drawing an object over what is beneath it.
///
/// The set matches the separable and non-separable modes shared by SVG, PDF
/// and Skia so export can preserve them.
enum ObjectBlendMode {
  normal,
  multiply,
  screen,
  overlay,
  darken,
  lighten,
  colorDodge,
  colorBurn,
  hardLight,
  softLight,
  difference,
  exclusion,
  hue,
  saturation,
  color,
  luminosity,
}
