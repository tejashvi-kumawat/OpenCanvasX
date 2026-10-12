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
