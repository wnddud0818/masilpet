import 'package:flutter/material.dart';

/// MasilPet's "pocket walking companion" color language.
///
/// Keep product colors here instead of scattering literal values across
/// screens. The matching [MasilPetThemeTokens] extension makes the same
/// palette available through [BuildContext].
abstract final class MasilPetPalette {
  static const cream = Color(0xFFFFF8E7);
  static const creamDeep = Color(0xFFF5EBD8);
  static const paper = Color(0xFFFFFDF8);
  static const ink = Color(0xFF27332D);
  static const mutedInk = Color(0xFF617069);

  static const leaf = Color(0xFF287A62);
  static const leafDark = Color(0xFF195744);
  static const mint = Color(0xFFAEE8D1);
  static const mintPale = Color(0xFFE8F7EF);
  static const sun = Color(0xFFF6C85F);
  static const sunPale = Color(0xFFFFF3C7);
  static const coral = Color(0xFFFF8A5B);
  static const coralPale = Color(0xFFFFE7DB);
  static const sky = Color(0xFFA9DFF3);
  static const skyDeep = Color(0xFF3D7896);
  static const lavender = Color(0xFFC8BDF7);
  static const lavenderDeep = Color(0xFF6D57A8);

  static const outline = Color(0xFFDCCFB2);
  static const outlineStrong = Color(0xFFBDAF92);
  static const success = Color(0xFF2E8B68);
  static const warning = Color(0xFFB86D1F);
  static const danger = Color(0xFFD85B5B);
  static const shadow = Color(0xFF5C4A2D);
}

abstract final class MasilPetSpacing {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class MasilPetRadii {
  static const small = 10.0;
  static const control = 14.0;
  static const panel = 16.0;
  static const card = 18.0;
  static const hero = 28.0;
  static const pill = 999.0;

  static const smallBorder = BorderRadius.all(Radius.circular(small));
  static const controlBorder = BorderRadius.all(Radius.circular(control));
  static const panelBorder = BorderRadius.all(Radius.circular(panel));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const heroBorder = BorderRadius.all(Radius.circular(hero));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
}

abstract final class MasilPetShadows {
  static const card = <BoxShadow>[
    BoxShadow(
      color: Color(0x145C4A2D),
      blurRadius: 22,
      offset: Offset(0, 9),
    ),
    BoxShadow(
      color: Color(0x125C4A2D),
      blurRadius: 0,
      offset: Offset(0, 3),
    ),
  ];

  static const soft = <BoxShadow>[
    BoxShadow(
      color: Color(0x125C4A2D),
      blurRadius: 14,
      offset: Offset(0, 6),
    ),
  ];
}

abstract final class MasilPetMotion {
  static const press = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 260);
  static const celebration = Duration(milliseconds: 720);
}

@immutable
class MasilPetThemeTokens extends ThemeExtension<MasilPetThemeTokens> {
  const MasilPetThemeTokens({
    required this.canvas,
    required this.paper,
    required this.ink,
    required this.mutedInk,
    required this.mint,
    required this.sun,
    required this.coral,
    required this.outline,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
  });

  static const light = MasilPetThemeTokens(
    canvas: MasilPetPalette.cream,
    paper: MasilPetPalette.paper,
    ink: MasilPetPalette.ink,
    mutedInk: MasilPetPalette.mutedInk,
    mint: MasilPetPalette.mint,
    sun: MasilPetPalette.sun,
    coral: MasilPetPalette.coral,
    outline: MasilPetPalette.outline,
    success: MasilPetPalette.success,
    warning: MasilPetPalette.warning,
    danger: MasilPetPalette.danger,
    shadow: MasilPetPalette.shadow,
  );

  final Color canvas;
  final Color paper;
  final Color ink;
  final Color mutedInk;
  final Color mint;
  final Color sun;
  final Color coral;
  final Color outline;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;

  @override
  MasilPetThemeTokens copyWith({
    Color? canvas,
    Color? paper,
    Color? ink,
    Color? mutedInk,
    Color? mint,
    Color? sun,
    Color? coral,
    Color? outline,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
  }) {
    return MasilPetThemeTokens(
      canvas: canvas ?? this.canvas,
      paper: paper ?? this.paper,
      ink: ink ?? this.ink,
      mutedInk: mutedInk ?? this.mutedInk,
      mint: mint ?? this.mint,
      sun: sun ?? this.sun,
      coral: coral ?? this.coral,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  MasilPetThemeTokens lerp(
    covariant MasilPetThemeTokens? other,
    double t,
  ) {
    if (other == null) {
      return this;
    }
    return MasilPetThemeTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      sun: Color.lerp(sun, other.sun, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension MasilPetThemeContext on BuildContext {
  MasilPetThemeTokens get masilPetTheme =>
      Theme.of(this).extension<MasilPetThemeTokens>() ??
      MasilPetThemeTokens.light;
}

ThemeData buildMasilPetTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MasilPetPalette.leaf,
    brightness: Brightness.light,
  ).copyWith(
    primary: MasilPetPalette.leaf,
    onPrimary: Colors.white,
    primaryContainer: MasilPetPalette.mint,
    onPrimaryContainer: MasilPetPalette.leafDark,
    secondary: MasilPetPalette.coral,
    onSecondary: MasilPetPalette.ink,
    secondaryContainer: MasilPetPalette.coralPale,
    onSecondaryContainer: MasilPetPalette.ink,
    tertiary: MasilPetPalette.sun,
    onTertiary: MasilPetPalette.ink,
    tertiaryContainer: MasilPetPalette.sunPale,
    onTertiaryContainer: MasilPetPalette.ink,
    error: MasilPetPalette.danger,
    onError: Colors.white,
    errorContainer: const Color(0xFFFDE7E4),
    onErrorContainer: const Color(0xFF6D2525),
    surface: MasilPetPalette.paper,
    onSurface: MasilPetPalette.ink,
    surfaceDim: MasilPetPalette.creamDeep,
    surfaceBright: MasilPetPalette.paper,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFFFAEF),
    surfaceContainer: const Color(0xFFF9F1E2),
    surfaceContainerHigh: const Color(0xFFF3E9D7),
    surfaceContainerHighest: const Color(0xFFECE5D7),
    onSurfaceVariant: MasilPetPalette.mutedInk,
    outline: MasilPetPalette.outlineStrong,
    outlineVariant: MasilPetPalette.outline,
    shadow: MasilPetPalette.shadow,
    scrim: MasilPetPalette.ink,
    inverseSurface: MasilPetPalette.ink,
    onInverseSurface: MasilPetPalette.cream,
    inversePrimary: MasilPetPalette.mint,
    surfaceTint: MasilPetPalette.leaf,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MasilPetPalette.cream,
    canvasColor: MasilPetPalette.cream,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    extensions: const [MasilPetThemeTokens.light],
  );
  final textTheme = base.textTheme
      .apply(
        bodyColor: MasilPetPalette.ink,
        displayColor: MasilPetPalette.ink,
      )
      .copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          color: MasilPetPalette.ink,
          fontWeight: FontWeight.w900,
          height: 1.08,
          letterSpacing: -1,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          color: MasilPetPalette.ink,
          fontWeight: FontWeight.w900,
          height: 1.16,
          letterSpacing: -0.45,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          color: MasilPetPalette.ink,
          fontWeight: FontWeight.w800,
          height: 1.22,
          letterSpacing: -0.25,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          color: MasilPetPalette.ink,
          fontWeight: FontWeight.w800,
          height: 1.28,
          letterSpacing: -0.15,
        ),
        titleSmall: base.textTheme.titleSmall?.copyWith(
          color: MasilPetPalette.ink,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.48),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.46),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          color: MasilPetPalette.mutedInk,
          height: 1.42,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    dividerColor: MasilPetPalette.outline,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 64,
      titleSpacing: MasilPetSpacing.xl,
      backgroundColor: MasilPetPalette.cream,
      foregroundColor: MasilPetPalette.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      elevation: 1.5,
      shadowColor: MasilPetPalette.shadow.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      color: MasilPetPalette.paper,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.cardBorder,
        side: BorderSide(
          color: MasilPetPalette.outline,
          width: 1.2,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: MasilPetSpacing.lg,
          vertical: MasilPetSpacing.md,
        ),
        backgroundColor: MasilPetPalette.leaf,
        foregroundColor: Colors.white,
        disabledBackgroundColor: MasilPetPalette.leaf.withValues(alpha: 0.34),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.82),
        elevation: 0,
        textStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.controlBorder,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(
          horizontal: MasilPetSpacing.lg,
          vertical: MasilPetSpacing.md,
        ),
        foregroundColor: MasilPetPalette.leafDark,
        backgroundColor: MasilPetPalette.paper.withValues(alpha: 0.72),
        side: const BorderSide(
          color: MasilPetPalette.outlineStrong,
          width: 1.35,
        ),
        textStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.controlBorder,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: MasilPetSpacing.md),
        foregroundColor: MasilPetPalette.leafDark,
        textStyle: textTheme.labelLarge,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.controlBorder,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(48),
        foregroundColor: MasilPetPalette.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.controlBorder,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 3,
      highlightElevation: 1,
      backgroundColor: MasilPetPalette.sun,
      foregroundColor: MasilPetPalette.ink,
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.panelBorder,
        side: BorderSide(color: MasilPetPalette.outlineStrong),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      elevation: 0,
      backgroundColor: MasilPetPalette.paper,
      surfaceTintColor: Colors.transparent,
      indicatorColor: MasilPetPalette.mint,
      indicatorShape: const StadiumBorder(),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? MasilPetPalette.leafDark
              : MasilPetPalette.mutedInk,
          size: states.contains(WidgetState.selected) ? 26 : 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return textTheme.labelSmall?.copyWith(
          color: states.contains(WidgetState.selected)
              ? MasilPetPalette.leafDark
              : MasilPetPalette.mutedInk,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w900
              : FontWeight.w700,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: MasilPetPalette.paper,
      indicatorColor: MasilPetPalette.mint,
      indicatorShape: const StadiumBorder(),
      selectedIconTheme: const IconThemeData(
        color: MasilPetPalette.leafDark,
        size: 26,
      ),
      unselectedIconTheme: const IconThemeData(
        color: MasilPetPalette.mutedInk,
        size: 23,
      ),
      selectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: MasilPetPalette.leafDark,
        fontWeight: FontWeight.w900,
      ),
      unselectedLabelTextStyle: textTheme.labelMedium?.copyWith(
        color: MasilPetPalette.mutedInk,
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: MasilPetPalette.coral,
      textColor: MasilPetPalette.ink,
      textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: MasilPetPalette.mint,
      checkmarkColor: MasilPetPalette.leafDark,
      disabledColor: scheme.surfaceContainerHigh,
      labelStyle: textTheme.labelMedium?.copyWith(
        color: MasilPetPalette.ink,
      ),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(
        color: MasilPetPalette.leafDark,
        fontWeight: FontWeight.w800,
      ),
      side: const BorderSide(color: MasilPetPalette.outline),
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.pillBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: MasilPetSpacing.xs),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MasilPetPalette.leaf,
      linearTrackColor: MasilPetPalette.creamDeep,
      linearMinHeight: 10,
      borderRadius: MasilPetRadii.pillBorder,
    ),
    dividerTheme: const DividerThemeData(
      color: MasilPetPalette.outline,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: const DialogThemeData(
      elevation: 5,
      shadowColor: Color(0x335C4A2D),
      backgroundColor: MasilPetPalette.paper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.heroBorder,
        side: BorderSide(color: MasilPetPalette.outline, width: 1.2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 8,
      modalElevation: 8,
      shadowColor: Color(0x335C4A2D),
      backgroundColor: MasilPetPalette.paper,
      modalBackgroundColor: MasilPetPalette.paper,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MasilPetRadii.hero),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      backgroundColor: MasilPetPalette.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: MasilPetPalette.paper,
        fontWeight: FontWeight.w700,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.panelBorder,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: MasilPetPalette.ink,
        borderRadius: MasilPetRadii.smallBorder,
      ),
      textStyle: textTheme.labelMedium?.copyWith(
        color: MasilPetPalette.paper,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
  );
}
