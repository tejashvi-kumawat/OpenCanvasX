import 'package:flutter/material.dart';

// Tokens from docs/product/design-system.md. Change them there first.

/// Spacing on a 4 px grid (design-system.md §4).
abstract final class Space {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii (design-system.md §4).
abstract final class Radii {
  /// Inputs, icon buttons, segmented items.
  static const double xs = 4;

  /// Buttons, menus, tooltips, list selection.
  static const double sm = 6;

  /// Cards, popovers.
  static const double md = 8;

  /// Dialogs.
  static const double lg = 12;
}

/// Fixed sizes of the app chrome (design-system.md §4–5).
abstract final class Chrome {
  static const double control = 28;
  static const double button = 32;
  static const double toolbar = 44;
  static const double leftSidebar = 240;
  static const double inspector = 248;
  static const double homeSidebar = 220;
  static const double icon = 16;
  static const double toolbarIcon = 18;
}

/// The single brand colour: Cobalt.
abstract final class Brand {
  static const Color cobalt = Color(0xFF3256F0);
  static const Color cobaltDark = Color(0xFF7B93FF);
}

/// Every colour token of the design system.
@immutable
class OcxColors extends ThemeExtension<OcxColors> {
  const OcxColors({
    required this.accent,
    required this.accentSubtle,
    required this.onAccent,
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.workspace,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.pageShadow,
  });

  final Color accent;
  final Color accentSubtle;
  final Color onAccent;
  final Color background;
  final Color surface;
  final Color surfaceSunken;
  final Color workspace;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color pageShadow;

  /// Hover overlay (6 % of the text colour).
  Color get hover => text.withValues(alpha: 0.06);

  /// Pressed overlay (10 %).
  Color get pressed => text.withValues(alpha: 0.10);

  static const light = OcxColors(
    accent: Brand.cobalt,
    accentSubtle: Color(0xFFEBEFFE),
    onAccent: Color(0xFFFFFFFF),
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0F1F4),
    workspace: Color(0xFFE8EAEE),
    border: Color(0xFFE1E3E8),
    borderStrong: Color(0xFFC9CDD6),
    text: Color(0xFF16181D),
    textSecondary: Color(0xFF5B616E),
    textTertiary: Color(0xFF8A909C),
    success: Color(0xFF1F9D55),
    warning: Color(0xFFC27C00),
    danger: Color(0xFFD93D3D),
    pageShadow: Color(0x24101318),
  );

  static const dark = OcxColors(
    accent: Brand.cobaltDark,
    accentSubtle: Color(0xFF232A4D),
    onAccent: Color(0xFF0B1033),
    background: Color(0xFF121316),
    surface: Color(0xFF1B1C20),
    surfaceSunken: Color(0xFF23252A),
    workspace: Color(0xFF0E0F11),
    border: Color(0xFF2E3036),
    borderStrong: Color(0xFF3D4048),
    text: Color(0xFFECEDEF),
    textSecondary: Color(0xFFA4A8B2),
    textTertiary: Color(0xFF7A7F8A),
    success: Color(0xFF3CCB7F),
    warning: Color(0xFFF0B429),
    danger: Color(0xFFF07070),
    pageShadow: Color(0x80000000),
  );

  @override
  OcxColors copyWith() => this;

  @override
  OcxColors lerp(OcxColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return OcxColors(
      accent: l(accent, other.accent),
      accentSubtle: l(accentSubtle, other.accentSubtle),
      onAccent: l(onAccent, other.onAccent),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      workspace: l(workspace, other.workspace),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      textSecondary: l(textSecondary, other.textSecondary),
      textTertiary: l(textTertiary, other.textTertiary),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      danger: l(danger, other.danger),
      pageShadow: l(pageShadow, other.pageShadow),
    );
  }
}

/// Shortcut: `context.ocx.border`.
extension OcxThemeContext on BuildContext {
  OcxColors get ocx => Theme.of(this).extension<OcxColors>()!;
}

/// Named text styles from design-system.md §3, mapped onto Material slots
/// so stock widgets pick up the compact sizes automatically.
abstract final class OcxText {
  static TextStyle caption(BuildContext c) => Theme.of(c).textTheme.labelSmall!;
  static TextStyle body(BuildContext c) => Theme.of(c).textTheme.bodyMedium!;
  static TextStyle bodyStrong(BuildContext c) =>
      Theme.of(c).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.w600);
  static TextStyle title(BuildContext c) => Theme.of(c).textTheme.titleMedium!;
  static TextStyle heading(BuildContext c) => Theme.of(c).textTheme.titleLarge!;
  static TextStyle display(BuildContext c) =>
      Theme.of(c).textTheme.headlineMedium!;
}

/// Builds the light or dark theme.
ThemeData buildOcxTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? OcxColors.dark : OcxColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.cobalt,
    brightness: brightness,
  ).copyWith(
    primary: c.accent,
    onPrimary: c.onAccent,
    secondaryContainer: c.accentSubtle,
    onSecondaryContainer: c.accent,
    surface: c.surface,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.surfaceSunken,
    surfaceContainer: c.surfaceSunken,
    surfaceContainerHigh: c.surface,
    surfaceContainerHighest: c.surfaceSunken,
    outline: c.borderStrong,
    outlineVariant: c.border,
    error: c.danger,
    surfaceTint: Colors.transparent,
  );

  TextStyle s(double size, double height, FontWeight weight, Color color) =>
      TextStyle(
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0,
      );

  final text = TextTheme(
    displaySmall: s(26, 32, FontWeight.w700, c.text),
    headlineMedium: s(26, 32, FontWeight.w700, c.text),
    headlineSmall: s(18, 24, FontWeight.w600, c.text),
    titleLarge: s(18, 24, FontWeight.w600, c.text),
    titleMedium: s(14, 20, FontWeight.w600, c.text),
    titleSmall: s(12, 18, FontWeight.w600, c.text),
    bodyLarge: s(12, 16, FontWeight.w400, c.text),
    bodyMedium: s(12, 18, FontWeight.w400, c.text),
    bodySmall: s(11, 16, FontWeight.w400, c.textSecondary),
    labelLarge: s(12, 16, FontWeight.w600, c.text),
    labelMedium: s(11, 16, FontWeight.w500, c.textSecondary),
    labelSmall: s(11, 16, FontWeight.w600, c.textSecondary),
  );

  final small = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.xs),
  );
  final medium = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.sm),
  );
  const noBorder = OutlineInputBorder(
    borderSide: BorderSide(color: Colors.transparent),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.surface,
    textTheme: text,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    splashFactory: NoSplash.splashFactory,
    hoverColor: c.hover,
    highlightColor: c.pressed,
    focusColor: c.accent.withValues(alpha: 0.18),
    extensions: [c],
    iconTheme: IconThemeData(size: Chrome.icon, color: c.text),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, Chrome.button),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        shape: medium,
        textStyle: text.labelLarge,
        iconSize: Chrome.icon,
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, Chrome.button),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        shape: medium,
        side: BorderSide(color: c.border),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        textStyle: text.labelLarge,
        iconSize: Chrome.icon,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, Chrome.control),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm),
        shape: medium,
        foregroundColor: c.text,
        textStyle: text.labelLarge,
        iconSize: Chrome.icon,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(Chrome.control),
        fixedSize: const Size.square(Chrome.control),
        padding: EdgeInsets.zero,
        iconSize: Chrome.icon,
        shape: small,
        foregroundColor: c.text,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceSunken,
      hoverColor: Colors.transparent,
      isDense: true,
      constraints: const BoxConstraints(minHeight: Chrome.control),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: 7,
      ),
      border: noBorder,
      enabledBorder: noBorder,
      disabledBorder: noBorder,
      focusedBorder: noBorder.copyWith(
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      hintStyle: text.bodyMedium!.copyWith(color: c.textTertiary),
      prefixStyle: text.labelMedium!.copyWith(color: c.textTertiary),
      suffixStyle: text.labelMedium!.copyWith(color: c.textTertiary),
      prefixIconColor: c.textTertiary,
      suffixIconColor: c.textTertiary,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      textStyle: text.labelMedium!.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2128),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(c.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(6),
        shadowColor: const WidgetStatePropertyAll(Color(0x33000000)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: c.border),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: Space.xs),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(200, 32),
        maximumSize: const Size(double.infinity, 32),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        textStyle: text.bodyMedium,
        iconSize: Chrome.icon,
        foregroundColor: c.text,
        shape: medium,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      textStyle: text.bodyMedium,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.border),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 420,
      backgroundColor: c.surface,
      contentTextStyle: text.bodyMedium,
      actionTextColor: c.accent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.border),
      ),
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 2,
      activeTrackColor: c.accent,
      inactiveTrackColor: c.borderStrong,
      thumbColor: c.surface,
      overlayShape: SliderComponentShape.noOverlay,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      showValueIndicator: ShowValueIndicator.never,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        minimumSize: const WidgetStatePropertyAll(Size(0, Chrome.control)),
        textStyle: WidgetStatePropertyAll(text.labelMedium),
        iconSize: const WidgetStatePropertyAll(Chrome.icon),
        side: WidgetStatePropertyAll(BorderSide(color: c.border)),
        shape: WidgetStatePropertyAll(small),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accentSubtle : c.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.accent : c.textSecondary,
        ),
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(c.textTertiary.withValues(alpha: 0.4)),
    ),
    checkboxTheme: CheckboxThemeData(
      visualDensity: VisualDensity.compact,
      shape: small,
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity.compact,
      minTileHeight: Chrome.button,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.md),
      shape: medium,
      selectedColor: c.accent,
      selectedTileColor: c.accentSubtle,
      titleTextStyle: text.bodyMedium,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent),
  );
}
