import 'package:flutter/material.dart';

/// MasilPet's "paper notebook" art direction (종이 수첩).
///
/// The product reads like a pocket walking journal: parchment paper, ink-black
/// type, a red rubber stamp for verified visits, dashed rules instead of
/// dividers, and hard offset shadows instead of soft blurs. Corners are almost
/// square (2–4px) so cards feel like paper cut with scissors rather than
/// Material surfaces.
///
/// Keep product colors here instead of scattering literal values across
/// screens. The matching [MasilPetThemeTokens] extension makes the same
/// palette available through [BuildContext].

/// Bundled font families. See `pubspec.yaml` for the asset declarations.
abstract final class MasilPetFonts {
  /// Headings, buttons, card titles, speech bubbles.
  static const serif = 'GowunBatang';

  /// Body copy and descriptions.
  static const sans = 'GowunDodum';

  /// Handwritten margin notes and section eyebrows.
  static const hand = 'NanumPenScript';

  /// Dates, counters, and stamp-like meta labels.
  static const mono = 'IBMPlexMono';
}

abstract final class MasilPetPalette {
  /// Desk surface behind the page shell (visible on wide layouts only).
  static const board = Color(0xFFD8C8A8);

  /// The page itself.
  static const canvas = Color(0xFFF2E9D8);

  /// Card stock laid on the page.
  static const paper = Color(0xFFFBF6EA);

  /// Slightly warmer paper used for sheets and overlays.
  static const sheet = Color(0xFFF7F1E2);

  /// Tinted fill for chips, callouts, and pressed states.
  static const subtle = Color(0xFFEFE4CD);

  /// Navigation bar / side rail stock.
  static const navSurface = Color(0xFFEBE0CA);

  /// Progress track.
  static const track = Color(0xFFE6D9C0);

  /// Hover and row separators.
  static const hover = Color(0xFFE2D5BB);

  /// Hard offset shadow cast by cards.
  static const shadowHard = Color(0xFFDCCDAE);

  static const outlineSoft = Color(0xFFD7C8AC);
  static const outline = Color(0xFFC9B894);
  static const outlineStrong = Color(0xFFD2C2A2);
  static const outlineFaint = Color(0xFFC1B096);

  static const ink = Color(0xFF23201B);
  static const inkShadow = Color(0xFF0E0C09);
  static const inkHover = Color(0xFF3A342B);
  static const inkSoft = Color(0xFF4A4238);
  static const muted = Color(0xFF6E6355);
  static const mutedWarm = Color(0xFF8A7B66);
  static const faint = Color(0xFF9A8A72);
  static const faintWarm = Color(0xFFA0917A);
  static const disabled = Color(0xFFBFAF94);
  static const disabledFaint = Color(0xFFCBBB9E);

  /// The rubber stamp red — the single loudest color in the product.
  static const stamp = Color(0xFFB23A2E);
  static const stampShadow = Color(0xFF7E2419);
  static const stampHover = Color(0xFFC4463A);
  static const stampPale = Color(0xFFE0B3AC);
  static const stampTint = Color(0xFFE8B4AB);

  static const forest = Color(0xFF2E5C46);
  static const forestDark = Color(0xFF24503C);
  static const forestPale = Color(0xFFA9C3B3);
  static const forestTint = Color(0xFFE3EDE0);

  static const sun = Color(0xFFF6C85F);
  static const sunDeep = Color(0xFFE0AE3E);
  static const sunPale = Color(0xFFFBF0D2);

  /// Category ink colors, mirroring the design's POI legend.
  static const catNature = forest;
  static const catFood = Color(0xFFB4531F);
  static const catCulture = Color(0xFF5B4A86);
  static const catHistory = Color(0xFF7A4A3A);
  static const catShopping = Color(0xFF8A6A1E);
  static const catFestival = stamp;

  /// Care stat bars.
  static const statSatiety = Color(0xFFC4881F);
  static const statClean = Color(0xFF3A6E8F);
  static const statVitality = forest;

  static const success = forest;
  static const warning = statSatiety;
  static const danger = stamp;
  static const shadow = Color(0xFF6B5636);
}

abstract final class MasilPetSpacing {
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const xxl = 30.0;
}

/// Paper is cut, not moulded — corners stay nearly square.
abstract final class MasilPetRadii {
  static const tight = 2.0;
  static const small = 3.0;
  static const card = 3.0;
  static const bubble = 4.0;
  static const sheet = 6.0;
  static const pill = 999.0;

  static const tightBorder = BorderRadius.all(Radius.circular(tight));
  static const smallBorder = BorderRadius.all(Radius.circular(small));
  static const cardBorder = BorderRadius.all(Radius.circular(card));
  static const bubbleBorder = BorderRadius.all(Radius.circular(bubble));
  static const pillBorder = BorderRadius.all(Radius.circular(pill));
  static const sheetBorder = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// Offset shadows with zero blur — the look of a card lifted off paper.
abstract final class MasilPetShadows {
  /// Featured card: `5px 5px 0 #DCCDAE`.
  static const stamped = <BoxShadow>[
    BoxShadow(
      color: MasilPetPalette.shadowHard,
      blurRadius: 0,
      offset: Offset(5, 5),
    ),
  ];

  /// Speech bubble: `3px 3px 0 #DCCDAE`.
  static const bubble = <BoxShadow>[
    BoxShadow(
      color: MasilPetPalette.shadowHard,
      blurRadius: 0,
      offset: Offset(3, 3),
    ),
  ];

  /// Speech bubble sitting on artwork: `3px 3px 0 rgba(60,45,25,.22)`.
  static const bubbleOnScene = <BoxShadow>[
    BoxShadow(
      color: Color(0x383C2D19),
      blurRadius: 0,
      offset: Offset(3, 3),
    ),
  ];

  /// Plain card resting on the page: `0 1px 0 #D7C8AC`.
  static const card = <BoxShadow>[
    BoxShadow(
      color: MasilPetPalette.outlineSoft,
      blurRadius: 0,
      offset: Offset(0, 1),
    ),
  ];

  /// Ink button lip: `0 3px 0 #0E0C09`.
  static const inkButton = <BoxShadow>[
    BoxShadow(
      color: MasilPetPalette.inkShadow,
      blurRadius: 0,
      offset: Offset(0, 3),
    ),
  ];

  /// Stamp button lip: `0 3px 0 #7E2419`.
  static const stampButton = <BoxShadow>[
    BoxShadow(
      color: MasilPetPalette.stampShadow,
      blurRadius: 0,
      offset: Offset(0, 3),
    ),
  ];

  /// Popover lifted above the yard: `0 6px 0 rgba(60,45,25,.22)`.
  static const popover = <BoxShadow>[
    BoxShadow(
      color: Color(0x383C2D19),
      blurRadius: 0,
      offset: Offset(0, 6),
    ),
  ];

  /// Toast: the only genuinely soft shadow in the system.
  static const toast = <BoxShadow>[
    BoxShadow(
      color: Color(0x73000000),
      blurRadius: 24,
      spreadRadius: -12,
      offset: Offset(0, 10),
    ),
  ];

  static const soft = card;
}

abstract final class MasilPetBorders {
  /// 1.5px ink outline used by featured cards and speech bubbles.
  static const ink = BorderSide(color: MasilPetPalette.ink, width: 1.5);

  /// 1px hairline used by ordinary cards.
  static const hairline = BorderSide(color: MasilPetPalette.outlineSoft);

  /// 1px mid-tone outline used by controls and the map frame.
  static const control = BorderSide(color: MasilPetPalette.outline);

  static const inkBox = Border.fromBorderSide(ink);
  static const hairlineBox = Border.fromBorderSide(hairline);
  static const controlBox = Border.fromBorderSide(control);
}

abstract final class MasilPetMotion {
  static const press = Duration(milliseconds: 90);
  static const fast = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 260);
  static const sheet = Duration(milliseconds: 320);
  static const rise = Duration(milliseconds: 450);
  static const stamp = Duration(milliseconds: 500);
  static const celebration = Duration(milliseconds: 720);

  /// `bob` — the resting float of a pet sprite.
  static const bob = Duration(milliseconds: 3400);

  /// `bob` at excited tempo.
  static const bobExcited = Duration(milliseconds: 1500);

  /// `ring` — the pulsing halo on the active map pin.
  static const ring = Duration(milliseconds: 2200);

  /// `sway` — trees in the yard.
  static const sway = Duration(milliseconds: 8000);

  /// `drift` — clouds crossing the yard.
  static const drift = Duration(seconds: 46);

  /// `shake` — an egg about to hatch.
  static const shake = Duration(milliseconds: 1400);

  static const stampCurve = Cubic(0.2, 1.4, 0.5, 1);
  static const sheetCurve = Cubic(0.2, 0.9, 0.3, 1);
}

/// Named type styles. The design leans on four families at once, so the
/// mapping is spelled out here rather than derived from a Material scale.
abstract final class MasilPetType {
  /// `IBM Plex Mono` 10px / .18em — the dateline above a page title.
  static const dateLine = TextStyle(
    fontFamily: MasilPetFonts.mono,
    fontSize: 10,
    height: 1.2,
    letterSpacing: 1.8,
    color: MasilPetPalette.faint,
  );

  /// `IBM Plex Mono` 10px / .16em — stamp-red eyebrow on featured cards.
  static const eyebrow = TextStyle(
    fontFamily: MasilPetFonts.mono,
    fontSize: 10,
    height: 1.2,
    letterSpacing: 1.6,
    color: MasilPetPalette.stamp,
  );

  /// `IBM Plex Mono` 11px / .1em — counters and rarity tags.
  static const metaMono = TextStyle(
    fontFamily: MasilPetFonts.mono,
    fontSize: 11,
    height: 1.25,
    letterSpacing: 1.1,
    color: MasilPetPalette.mutedWarm,
  );

  /// `IBM Plex Mono` 9.5px — the smallest meta label.
  static const microMono = TextStyle(
    fontFamily: MasilPetFonts.mono,
    fontSize: 9.5,
    height: 1.25,
    letterSpacing: 0.8,
    color: MasilPetPalette.mutedWarm,
  );

  /// `Nanum Pen Script` 21px — margin notes and section eyebrows.
  static const hand = TextStyle(
    fontFamily: MasilPetFonts.hand,
    fontSize: 21,
    height: 1.25,
    color: MasilPetPalette.mutedWarm,
  );

  static const handLarge = TextStyle(
    fontFamily: MasilPetFonts.hand,
    fontSize: 23,
    height: 1.2,
    color: MasilPetPalette.mutedWarm,
  );

  static const handSmall = TextStyle(
    fontFamily: MasilPetFonts.hand,
    fontSize: 19,
    height: 1.2,
    color: MasilPetPalette.mutedWarm,
  );

  /// `Gowun Batang` 34px bold — onboarding headline.
  static const display = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 34,
    height: 1.32,
    letterSpacing: -0.68,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 26px bold — hero card title.
  static const heroTitle = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.2,
    letterSpacing: -0.52,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 24px bold — page title in the header.
  static const pageTitle = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 24,
    height: 1.2,
    letterSpacing: -0.48,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 17px bold — section heading.
  static const sectionTitle = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.3,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 15.5px bold — list row title.
  static const rowTitle = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 15.5,
    height: 1.3,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 16px regular — what a pet says.
  static const bubble = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontSize: 16,
    height: 1.6,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 15.5px regular — long-form journal prose.
  static const prose = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontSize: 15.5,
    height: 1.8,
    color: MasilPetPalette.ink,
  );

  /// `Gowun Batang` 17px bold — button label.
  static const button = TextStyle(
    fontFamily: MasilPetFonts.serif,
    fontWeight: FontWeight.w700,
    fontSize: 17,
    height: 1.2,
  );

  /// `Gowun Dodum` 15px — primary body copy.
  static const body = TextStyle(
    fontFamily: MasilPetFonts.sans,
    fontSize: 15,
    height: 1.75,
    color: MasilPetPalette.muted,
  );

  /// `Gowun Dodum` 14px — dense body copy.
  static const bodySmall = TextStyle(
    fontFamily: MasilPetFonts.sans,
    fontSize: 14,
    height: 1.65,
    color: MasilPetPalette.muted,
  );

  /// `Gowun Dodum` 12.5px — captions under a title.
  static const caption = TextStyle(
    fontFamily: MasilPetFonts.sans,
    fontSize: 12.5,
    height: 1.4,
    color: MasilPetPalette.mutedWarm,
  );
}

@immutable
class MasilPetThemeTokens extends ThemeExtension<MasilPetThemeTokens> {
  const MasilPetThemeTokens({
    required this.board,
    required this.canvas,
    required this.paper,
    required this.sheet,
    required this.subtle,
    required this.navSurface,
    required this.track,
    required this.ink,
    required this.inkSoft,
    required this.muted,
    required this.mutedWarm,
    required this.faint,
    required this.outline,
    required this.outlineSoft,
    required this.stamp,
    required this.forest,
    required this.sun,
    required this.success,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.shadowHard,
  });

  static const light = MasilPetThemeTokens(
    board: MasilPetPalette.board,
    canvas: MasilPetPalette.canvas,
    paper: MasilPetPalette.paper,
    sheet: MasilPetPalette.sheet,
    subtle: MasilPetPalette.subtle,
    navSurface: MasilPetPalette.navSurface,
    track: MasilPetPalette.track,
    ink: MasilPetPalette.ink,
    inkSoft: MasilPetPalette.inkSoft,
    muted: MasilPetPalette.muted,
    mutedWarm: MasilPetPalette.mutedWarm,
    faint: MasilPetPalette.faint,
    outline: MasilPetPalette.outline,
    outlineSoft: MasilPetPalette.outlineSoft,
    stamp: MasilPetPalette.stamp,
    forest: MasilPetPalette.forest,
    sun: MasilPetPalette.sun,
    success: MasilPetPalette.success,
    warning: MasilPetPalette.warning,
    danger: MasilPetPalette.danger,
    shadow: MasilPetPalette.shadow,
    shadowHard: MasilPetPalette.shadowHard,
  );

  final Color board;
  final Color canvas;
  final Color paper;
  final Color sheet;
  final Color subtle;
  final Color navSurface;
  final Color track;
  final Color ink;
  final Color inkSoft;
  final Color muted;
  final Color mutedWarm;
  final Color faint;
  final Color outline;
  final Color outlineSoft;
  final Color stamp;
  final Color forest;
  final Color sun;
  final Color success;
  final Color warning;
  final Color danger;
  final Color shadow;
  final Color shadowHard;

  @override
  MasilPetThemeTokens copyWith({
    Color? board,
    Color? canvas,
    Color? paper,
    Color? sheet,
    Color? subtle,
    Color? navSurface,
    Color? track,
    Color? ink,
    Color? inkSoft,
    Color? muted,
    Color? mutedWarm,
    Color? faint,
    Color? outline,
    Color? outlineSoft,
    Color? stamp,
    Color? forest,
    Color? sun,
    Color? success,
    Color? warning,
    Color? danger,
    Color? shadow,
    Color? shadowHard,
  }) {
    return MasilPetThemeTokens(
      board: board ?? this.board,
      canvas: canvas ?? this.canvas,
      paper: paper ?? this.paper,
      sheet: sheet ?? this.sheet,
      subtle: subtle ?? this.subtle,
      navSurface: navSurface ?? this.navSurface,
      track: track ?? this.track,
      ink: ink ?? this.ink,
      inkSoft: inkSoft ?? this.inkSoft,
      muted: muted ?? this.muted,
      mutedWarm: mutedWarm ?? this.mutedWarm,
      faint: faint ?? this.faint,
      outline: outline ?? this.outline,
      outlineSoft: outlineSoft ?? this.outlineSoft,
      stamp: stamp ?? this.stamp,
      forest: forest ?? this.forest,
      sun: sun ?? this.sun,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      shadowHard: shadowHard ?? this.shadowHard,
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
      board: Color.lerp(board, other.board, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      sheet: Color.lerp(sheet, other.sheet, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      track: Color.lerp(track, other.track, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedWarm: Color.lerp(mutedWarm, other.mutedWarm, t)!,
      faint: Color.lerp(faint, other.faint, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineSoft: Color.lerp(outlineSoft, other.outlineSoft, t)!,
      stamp: Color.lerp(stamp, other.stamp, t)!,
      forest: Color.lerp(forest, other.forest, t)!,
      sun: Color.lerp(sun, other.sun, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shadowHard: Color.lerp(shadowHard, other.shadowHard, t)!,
    );
  }
}

extension MasilPetThemeContext on BuildContext {
  MasilPetThemeTokens get masilPetTheme =>
      Theme.of(this).extension<MasilPetThemeTokens>() ??
      MasilPetThemeTokens.light;
}

/// Ink color for a POI category marker.
Color masilPetCategoryColor(String categoryLabel) {
  switch (categoryLabel) {
    case '자연':
      return MasilPetPalette.catNature;
    case '음식':
      return MasilPetPalette.catFood;
    case '문화':
      return MasilPetPalette.catCulture;
    case '역사':
      return MasilPetPalette.catHistory;
    case '시장':
    case '쇼핑':
      return MasilPetPalette.catShopping;
    case '축제':
      return MasilPetPalette.catFestival;
    default:
      return MasilPetPalette.mutedWarm;
  }
}

/// Single-syllable stamp mark drawn inside a map pin.
String masilPetCategoryMark(String categoryLabel) {
  switch (categoryLabel) {
    case '자연':
      return '자';
    case '음식':
      return '식';
    case '문화':
      return '문';
    case '역사':
      return '사';
    case '시장':
    case '쇼핑':
      return '장';
    case '축제':
      return '축';
    default:
      return '기';
  }
}

ThemeData buildMasilPetTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: MasilPetPalette.forest,
    brightness: Brightness.light,
  ).copyWith(
    primary: MasilPetPalette.ink,
    onPrimary: MasilPetPalette.sheet,
    primaryContainer: MasilPetPalette.subtle,
    onPrimaryContainer: MasilPetPalette.ink,
    secondary: MasilPetPalette.stamp,
    onSecondary: MasilPetPalette.paper,
    secondaryContainer: MasilPetPalette.stampPale,
    onSecondaryContainer: MasilPetPalette.stampShadow,
    tertiary: MasilPetPalette.forest,
    onTertiary: MasilPetPalette.paper,
    tertiaryContainer: MasilPetPalette.forestTint,
    onTertiaryContainer: MasilPetPalette.forestDark,
    error: MasilPetPalette.stamp,
    onError: MasilPetPalette.paper,
    errorContainer: MasilPetPalette.stampPale,
    onErrorContainer: MasilPetPalette.stampShadow,
    surface: MasilPetPalette.paper,
    onSurface: MasilPetPalette.ink,
    surfaceDim: MasilPetPalette.canvas,
    surfaceBright: MasilPetPalette.paper,
    surfaceContainerLowest: MasilPetPalette.paper,
    surfaceContainerLow: MasilPetPalette.sheet,
    surfaceContainer: MasilPetPalette.canvas,
    surfaceContainerHigh: MasilPetPalette.subtle,
    surfaceContainerHighest: MasilPetPalette.navSurface,
    onSurfaceVariant: MasilPetPalette.muted,
    outline: MasilPetPalette.outline,
    outlineVariant: MasilPetPalette.outlineSoft,
    shadow: MasilPetPalette.shadow,
    scrim: MasilPetPalette.ink,
    inverseSurface: MasilPetPalette.ink,
    onInverseSurface: MasilPetPalette.sheet,
    inversePrimary: MasilPetPalette.subtle,
    surfaceTint: Colors.transparent,
  );

  final textTheme = TextTheme(
    displayLarge: MasilPetType.display.copyWith(fontSize: 40),
    displayMedium: MasilPetType.display.copyWith(fontSize: 37),
    displaySmall: MasilPetType.display,
    headlineLarge: MasilPetType.display.copyWith(fontSize: 30, height: 1.35),
    headlineMedium: MasilPetType.display.copyWith(fontSize: 27, height: 1.38),
    headlineSmall: MasilPetType.heroTitle,
    titleLarge: MasilPetType.pageTitle,
    titleMedium: MasilPetType.sectionTitle,
    titleSmall: MasilPetType.rowTitle,
    bodyLarge: MasilPetType.body,
    bodyMedium: MasilPetType.bodySmall,
    bodySmall: MasilPetType.caption,
    labelLarge: MasilPetType.button.copyWith(color: MasilPetPalette.ink),
    labelMedium: MasilPetType.metaMono,
    labelSmall: MasilPetType.microMono,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MasilPetPalette.canvas,
    canvasColor: MasilPetPalette.canvas,
    fontFamily: MasilPetFonts.sans,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    splashFactory: InkSparkle.splashFactory,
    extensions: const [MasilPetThemeTokens.light],
  );

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    dividerColor: MasilPetPalette.outlineSoft,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      elevation: 0,
      toolbarHeight: 62,
      titleSpacing: MasilPetSpacing.xl,
      backgroundColor: MasilPetPalette.canvas,
      foregroundColor: MasilPetPalette.ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: MasilPetType.pageTitle,
      shape:
          const Border(bottom: BorderSide(color: MasilPetPalette.shadowHard)),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      color: MasilPetPalette.paper,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.cardBorder,
        side: MasilPetBorders.hairline,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(
          horizontal: MasilPetSpacing.xl,
          vertical: MasilPetSpacing.md,
        ),
        backgroundColor: MasilPetPalette.ink,
        foregroundColor: MasilPetPalette.sheet,
        disabledBackgroundColor: MasilPetPalette.outline,
        disabledForegroundColor: MasilPetPalette.sheet,
        elevation: 0,
        textStyle: MasilPetType.button,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.smallBorder,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(
          horizontal: MasilPetSpacing.lg,
          vertical: MasilPetSpacing.md,
        ),
        foregroundColor: MasilPetPalette.ink,
        backgroundColor: Colors.transparent,
        side: MasilPetBorders.ink,
        textStyle: MasilPetType.button.copyWith(fontSize: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.smallBorder,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: MasilPetSpacing.md),
        foregroundColor: MasilPetPalette.muted,
        textStyle: MasilPetType.bodySmall.copyWith(
          color: MasilPetPalette.muted,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.tightBorder,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(46),
        foregroundColor: MasilPetPalette.ink,
        shape: const RoundedRectangleBorder(
          borderRadius: MasilPetRadii.tightBorder,
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 0,
      highlightElevation: 0,
      backgroundColor: MasilPetPalette.stamp,
      foregroundColor: MasilPetPalette.paper,
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.smallBorder,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 62,
      elevation: 0,
      backgroundColor: MasilPetPalette.navSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.tightBorder,
      ),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color: states.contains(WidgetState.selected)
              ? MasilPetPalette.stamp
              : MasilPetPalette.faint,
          size: 6,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: MasilPetFonts.serif,
          fontSize: 13.5,
          height: 1.2,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          color: selected ? MasilPetPalette.ink : MasilPetPalette.faint,
        );
      }),
    ),
    navigationRailTheme: NavigationRailThemeData(
      elevation: 0,
      backgroundColor: MasilPetPalette.navSurface,
      indicatorColor: MasilPetPalette.ink,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.smallBorder,
      ),
      selectedIconTheme: const IconThemeData(
        color: MasilPetPalette.sheet,
        size: 20,
      ),
      unselectedIconTheme: const IconThemeData(
        color: MasilPetPalette.muted,
        size: 20,
      ),
      selectedLabelTextStyle: MasilPetType.rowTitle.copyWith(
        fontSize: 15,
        color: MasilPetPalette.sheet,
      ),
      unselectedLabelTextStyle: MasilPetType.rowTitle.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: MasilPetPalette.muted,
      ),
    ),
    badgeTheme: BadgeThemeData(
      backgroundColor: MasilPetPalette.stamp,
      textColor: MasilPetPalette.paper,
      textStyle: MasilPetType.microMono.copyWith(
        fontSize: 9,
        letterSpacing: 0,
        color: MasilPetPalette.paper,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: MasilPetPalette.paper,
      selectedColor: MasilPetPalette.ink,
      checkmarkColor: MasilPetPalette.sheet,
      disabledColor: MasilPetPalette.subtle,
      showCheckmark: false,
      labelStyle: MasilPetType.bodySmall.copyWith(
        fontSize: 13,
        height: 1.2,
        color: MasilPetPalette.muted,
      ),
      secondaryLabelStyle: MasilPetType.bodySmall.copyWith(
        fontSize: 13,
        height: 1.2,
        color: MasilPetPalette.sheet,
      ),
      side: MasilPetBorders.hairline,
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.pillBorder,
      ),
      padding: const EdgeInsets.symmetric(horizontal: MasilPetSpacing.xs),
      elevation: 0,
      pressElevation: 0,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: MasilPetPalette.forest,
      linearTrackColor: MasilPetPalette.track,
      linearMinHeight: 9,
      borderRadius: MasilPetRadii.pillBorder,
    ),
    dividerTheme: const DividerThemeData(
      color: MasilPetPalette.outlineSoft,
      thickness: 1,
      space: 1,
    ),
    dialogTheme: const DialogThemeData(
      elevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: MasilPetPalette.sheet,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: MasilPetType.heroTitle,
      contentTextStyle: MasilPetType.bodySmall,
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.bubbleBorder,
        side: MasilPetBorders.ink,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 0,
      modalElevation: 0,
      shadowColor: Colors.transparent,
      backgroundColor: MasilPetPalette.sheet,
      modalBackgroundColor: MasilPetPalette.sheet,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: MasilPetPalette.outlineStrong,
      dragHandleSize: Size(44, 4),
      shape: RoundedRectangleBorder(
        borderRadius: MasilPetRadii.sheetBorder,
        side: BorderSide(color: MasilPetPalette.ink, width: 2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      backgroundColor: MasilPetPalette.ink,
      contentTextStyle: MasilPetType.bubble.copyWith(
        fontSize: 14,
        height: 1.5,
        color: MasilPetPalette.sheet,
      ),
      actionTextColor: MasilPetPalette.stampTint,
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.smallBorder,
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: MasilPetPalette.ink,
        borderRadius: MasilPetRadii.tightBorder,
      ),
      textStyle: MasilPetType.caption.copyWith(color: MasilPetPalette.sheet),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: MasilPetPalette.forest,
      inactiveTrackColor: MasilPetPalette.track,
      thumbColor: MasilPetPalette.ink,
    ),
    checkboxTheme: base.checkboxTheme.copyWith(
      fillColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? MasilPetPalette.forest
            : Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(MasilPetPalette.paper),
      side: const BorderSide(color: MasilPetPalette.outline, width: 1.5),
      shape: const RoundedRectangleBorder(
        borderRadius: MasilPetRadii.tightBorder,
      ),
    ),
  );
}
