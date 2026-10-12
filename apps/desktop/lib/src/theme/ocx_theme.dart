import 'package:flutter/material.dart';

/// Spacing scale (logical pixels). Use these instead of ad-hoc numbers so
/// every screen shares one rhythm.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii.
abstract final class Radii {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 14;
  static const double xl = 20;

  /// Fully rounded ends (search fields, count badges).
  static const double pill = 999;
}

/// Fixed sizes of the editor chrome (ux-spec.md "Main UI").
abstract final class Chrome {
  static const double topBarHeight = 56;
  static const double bottomBarHeight = 44;
  static const double railWidth = 76;
  static const double sidePanelWidth = 296;
  static const double inspectorWidth = 296;
  static const double homeSidebarWidth = 256;
}

/// Brand colours.
abstract final class Brand {
  static const Color violet = Color(0xFF6D4AFF);
  static const Color violetLight = Color(0xFFA08BFF);
  static const Color teal = Color(0xFF12B5C9);
  static const Color magenta = Color(0xFFB548F0);

  static const LinearGradient gradient = LinearGradient(
    colors: [teal, violet, magenta],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0FA3B8), Color(0xFF5B3DF5), Color(0xFF9C3FE6)],
    stops: [0, 0.6, 1],
  );
}

/// App-specific colours not covered by [ColorScheme].
@immutable
class OcxColors extends ThemeExtension<OcxColors> {
  const OcxColors({
    required this.workspace,
    required this.panel,
    required this.border,
    required this.subtleText,
    required this.hover,
    required this.selectedFill,
    required this.selection,
    required this.pageShadow,
    required this.success,
  });

  /// Grey area around pages in the editor.
  final Color workspace;

  /// Side panels, top/bottom bars of the editor.
  final Color panel;

  /// Hairlines between regions and around cards.
  final Color border;

  /// Secondary text (captions, sizes, hints).
  final Color subtleText;

  /// Hover background for list rows and tiles.
  final Color hover;

  /// Background of a selected row or tile.
  final Color selectedFill;

  /// Selection outlines and handles on the canvas.
  final Color selection;

  /// Shadow under pages and cards.
  final Color pageShadow;

  final Color success;

  static const light = OcxColors(
    workspace: Color(0xFFEBEDF2),
    panel: Color(0xFFFFFFFF),
    border: Color(0xFFE3E6ED),
    subtleText: Color(0xFF667085),
    hover: Color(0xFFF3F4F8),
    selectedFill: Color(0xFFEEEAFF),
    selection: Brand.violet,
    pageShadow: Color(0x1F101828),
    success: Color(0xFF12A15A),
  );

  static const dark = OcxColors(
    workspace: Color(0xFF0E1015),
    panel: Color(0xFF181B22),
    border: Color(0xFF2A2E38),
    subtleText: Color(0xFF9AA2B2),
    hover: Color(0xFF22262F),
    selectedFill: Color(0xFF2B2550),
    selection: Brand.violetLight,
    pageShadow: Color(0x66000000),
    success: Color(0xFF3CCB7F),
  );

  @override
  OcxColors copyWith({
    Color? workspace,
    Color? panel,
    Color? border,
    Color? subtleText,
    Color? hover,
    Color? selectedFill,
    Color? selection,
    Color? pageShadow,
    Color? success,
  }) => OcxColors(
    workspace: workspace ?? this.workspace,
    panel: panel ?? this.panel,
    border: border ?? this.border,
    subtleText: subtleText ?? this.subtleText,
    hover: hover ?? this.hover,
    selectedFill: selectedFill ?? this.selectedFill,
    selection: selection ?? this.selection,
    pageShadow: pageShadow ?? this.pageShadow,
    success: success ?? this.success,
  );

  @override
  OcxColors lerp(OcxColors? other, double t) {
    if (other == null) return this;
    return OcxColors(
      workspace: Color.lerp(workspace, other.workspace, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      border: Color.lerp(border, other.border, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      hover: Color.lerp(hover, other.hover, t)!,
      selectedFill: Color.lerp(selectedFill, other.selectedFill, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      pageShadow: Color.lerp(pageShadow, other.pageShadow, t)!,
      success: Color.lerp(success, other.success, t)!,
    );
  }
}

/// Shortcut: `context.ocx.border`.
extension OcxThemeContext on BuildContext {
  OcxColors get ocx => Theme.of(this).extension<OcxColors>()!;
}

/// Builds the light or dark theme.
ThemeData buildOcxTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? OcxColors.dark : OcxColors.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.violet,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? Brand.violetLight : Brand.violet,
    onPrimary: isDark ? const Color(0xFF1A1240) : Colors.white,
    surface: isDark ? const Color(0xFF13151B) : const Color(0xFFFFFFFF),
    onSurface: isDark ? const Color(0xFFE8EAF0) : const Color(0xFF101828),
    onSurfaceVariant: colors.subtleText,
    surfaceContainerLowest:
        isDark ? const Color(0xFF0F1116) : const Color(0xFFF7F8FB),
    surfaceContainerLow:
        isDark ? const Color(0xFF181B22) : const Color(0xFFF4F5F9),
    surfaceContainer:
        isDark ? const Color(0xFF1D2028) : const Color(0xFFF0F1F6),
    outline: colors.border,
    outlineVariant: colors.border,
  );

  final base = (isDark
          ? Typography.material2021().white
          : Typography.material2021().black)
      .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  final text = base.copyWith(
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.1,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    labelMedium: base.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.subtleText,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
      color: colors.subtleText,
    ),
    bodySmall: base.bodySmall?.copyWith(color: colors.subtleText),
  );

  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Radii.md),
  );
  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(Radii.md),
    borderSide: BorderSide(color: colors.border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    textTheme: text,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    extensions: [colors],
    dividerTheme: DividerThemeData(
      color: colors.border,
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg + 2),
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        shape: rounded,
        side: BorderSide(color: colors.border),
        foregroundColor: scheme.onSurface,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 36),
        shape: rounded,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        shape: rounded,
        foregroundColor: scheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1F232C) : const Color(0xFFF5F6FA),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.md - 2,
      ),
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
      hintStyle: text.bodyMedium?.copyWith(color: colors.subtleText),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: colors.border),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 450),
      textStyle: text.bodySmall?.copyWith(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xEE1D2130),
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(scheme.surface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
            side: BorderSide(color: colors.border),
          ),
        ),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: Space.xs + 2),
        ),
      ),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: MenuItemButton.styleFrom(
        minimumSize: const Size(220, 36),
        padding: const EdgeInsets.symmetric(horizontal: Space.md),
        textStyle: text.bodyMedium,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      width: 440,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
      showValueIndicator: ShowValueIndicator.never,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(
        colors.subtleText.withValues(alpha: 0.35),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected)
                ? const Icon(Icons.check, size: 14)
                : null,
      ),
    ),
  );
}
