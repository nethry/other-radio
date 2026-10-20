import 'package:flutter/material.dart';

/// Accent colours offered in settings. `ink` is the darker variant used for
/// accent-coloured text and icons on the light theme, where the bright accent
/// would fail contrast.
enum RadioAccent {
  coral('Koral', Color(0xFFFF6B3D), Color(0xFFC2410C)),
  teal('Morski', Color(0xFF4FD1C5), Color(0xFF0F766E)),
  lime('Limonka', Color(0xFFB7F34A), Color(0xFF4D7C0F)),
  violet('Fiolet', Color(0xFF8B7CFF), Color(0xFF5B4BD6));

  const RadioAccent(this.label, this.color, this.ink);
  final String label;
  final Color color;
  final Color ink;

  static RadioAccent byName(String? name) =>
      values.firstWhere((a) => a.name == name, orElse: () => RadioAccent.coral);
}

/// Logo colours from `assets/branding/` (independent of the accent setting).
/// The ink variant keeps the wordmark legible on the light theme.
const brandMint = Color(0xFF65E5CD);
const brandMintInk = Color(0xFF0F766E);

const danger = Color(0xFFE5484D);
const dangerInk = Color(0xFFC2262C);

/// Tile background/foreground pairs used for station monograms.
typedef TilePalette = ({Color bg, Color fg});

const _darkTiles = <TilePalette>[
  (bg: Color(0xFF2B1B14), fg: Color(0xFFFF9A72)),
  (bg: Color(0xFF14233A), fg: Color(0xFF8FC2FF)),
  (bg: Color(0xFF2A1630), fg: Color(0xFFE7A6FF)),
  (bg: Color(0xFF13281F), fg: Color(0xFF7FE0B0)),
  (bg: Color(0xFF2E2614), fg: Color(0xFFFFD27A)),
  (bg: Color(0xFF311519), fg: Color(0xFFFF8A95)),
  (bg: Color(0xFF1B1F33), fg: Color(0xFFA9B4FF)),
  (bg: Color(0xFF122A2C), fg: Color(0xFF7FDCE6)),
];

const _lightTiles = <TilePalette>[
  (bg: Color(0xFFFFE3D8), fg: Color(0xFF8A2E0E)),
  (bg: Color(0xFFDCEBFF), fg: Color(0xFF1D4F91)),
  (bg: Color(0xFFF3DDFB), fg: Color(0xFF6B2585)),
  (bg: Color(0xFFD7F3E5), fg: Color(0xFF17603F)),
  (bg: Color(0xFFFFF0CC), fg: Color(0xFF7A5300)),
  (bg: Color(0xFFFFDCE0), fg: Color(0xFF8E1D2B)),
  (bg: Color(0xFFE2E6FF), fg: Color(0xFF323E9E)),
  (bg: Color(0xFFD4F1F3), fg: Color(0xFF145E66)),
];

/// Design tokens from the OtherRadio canvas, exposed as a theme extension so
/// widgets can read `context.rc.mu` instead of hard-coding colours.
@immutable
class RadioTokens extends ThemeExtension<RadioTokens> {
  const RadioTokens({
    required this.dark,
    required this.ac,
    required this.act,
    required this.bg,
    required this.sf,
    required this.sf2,
    required this.hov,
    required this.bd,
    required this.bd2,
    required this.panel,
    required this.tx,
    required this.tx2,
    required this.mu,
    required this.dim,
    required this.orbit,
    required this.seg,
    required this.segOn,
    required this.navOn,
    required this.bar,
    required this.onAccent,
    required this.glowOpacity,
    required this.shadow,
    required this.shadowSm,
    required this.shadowHover,
    required this.artShadow,
    required this.tiles,
    required this.calm,
  });

  factory RadioTokens.of({
    required bool dark,
    required RadioAccent accent,
    bool calm = false,
  }) => dark
      ? RadioTokens(
          dark: true,
          ac: accent.color,
          act: accent.color,
          bg: const Color(0xFF0A0C10),
          sf: const Color(0xFF12151C),
          sf2: const Color(0xFF1A1E27),
          hov: const Color(0xFF161A22),
          bd: const Color(0xFF252A35),
          bd2: const Color(0xFF2C3240),
          panel: const Color(0xFF0D1015),
          tx: const Color(0xFFECEEF2),
          tx2: const Color(0xFFC9CED8),
          mu: const Color(0xFF9AA1AE),
          dim: const Color(0xFF6B7280),
          orbit: const Color(0xFF3A4150),
          seg: const Color(0xFF12151C),
          segOn: const Color(0xFF232836),
          navOn: const Color(0xFF161A22),
          bar: const Color(0xFF0A0C10),
          onAccent: const Color(0xFF0A0C10),
          glowOpacity: 0.10,
          shadow: const [
            BoxShadow(
              color: Color(0x73000000),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
          shadowSm: const [],
          shadowHover: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
          artShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 60,
              offset: Offset(0, 30),
            ),
          ],
          tiles: _darkTiles,
          calm: calm,
        )
      : RadioTokens(
          dark: false,
          ac: accent.color,
          act: accent.ink,
          bg: const Color(0xFFEEF0F4),
          sf: const Color(0xFFFFFFFF),
          sf2: const Color(0xFFFFFFFF),
          hov: const Color(0xFFE4E7ED),
          bd: const Color(0xFFDDE1E8),
          bd2: const Color(0xFFC9CFD8),
          panel: const Color(0xFFFFFFFF),
          tx: const Color(0xFF0E1116),
          tx2: const Color(0xFF2E3440),
          mu: const Color(0xFF596070),
          dim: const Color(0xFF8A91A0),
          orbit: const Color(0xFFC3C9D3),
          seg: const Color(0xFFE4E7ED),
          segOn: const Color(0xFFFFFFFF),
          navOn: const Color(0xFFFFFFFF),
          bar: const Color(0xFFFFFFFF),
          onAccent: const Color(0xFF0E1116),
          glowOpacity: 0.14,
          shadow: const [
            BoxShadow(
              color: Color(0x24101828),
              blurRadius: 40,
              offset: Offset(0, 18),
            ),
          ],
          shadowSm: const [
            BoxShadow(
              color: Color(0x0F101828),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
          shadowHover: const [
            BoxShadow(
              color: Color(0x1A101828),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
          artShadow: const [
            BoxShadow(
              color: Color(0x29101828),
              blurRadius: 60,
              offset: Offset(0, 30),
            ),
          ],
          tiles: _lightTiles,
          calm: calm,
        );

  final bool dark;

  /// Accent fill (`--ac`) and accent used for text/icons (`--act`).
  final Color ac, act;
  final Color bg, sf, sf2, hov, bd, bd2, panel, tx, tx2, mu, dim, orbit;
  final Color seg, segOn, navOn, bar, onAccent;
  final double glowOpacity;
  final List<BoxShadow> shadow, shadowSm, shadowHover, artShadow;
  final List<TilePalette> tiles;

  /// Reduced motion: from settings or the platform accessibility flag.
  final bool calm;

  Color get dangerText => dark ? danger : dangerInk;

  @override
  RadioTokens copyWith({bool? calm}) => RadioTokens(
    dark: dark,
    ac: ac,
    act: act,
    bg: bg,
    sf: sf,
    sf2: sf2,
    hov: hov,
    bd: bd,
    bd2: bd2,
    panel: panel,
    tx: tx,
    tx2: tx2,
    mu: mu,
    dim: dim,
    orbit: orbit,
    seg: seg,
    segOn: segOn,
    navOn: navOn,
    bar: bar,
    onAccent: onAccent,
    glowOpacity: glowOpacity,
    shadow: shadow,
    shadowSm: shadowSm,
    shadowHover: shadowHover,
    artShadow: artShadow,
    tiles: tiles,
    calm: calm ?? this.calm,
  );

  @override
  RadioTokens lerp(RadioTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    final next = t < 0.5 ? this : other;
    return RadioTokens(
      dark: next.dark,
      ac: c(ac, other.ac),
      act: c(act, other.act),
      bg: c(bg, other.bg),
      sf: c(sf, other.sf),
      sf2: c(sf2, other.sf2),
      hov: c(hov, other.hov),
      bd: c(bd, other.bd),
      bd2: c(bd2, other.bd2),
      panel: c(panel, other.panel),
      tx: c(tx, other.tx),
      tx2: c(tx2, other.tx2),
      mu: c(mu, other.mu),
      dim: c(dim, other.dim),
      orbit: c(orbit, other.orbit),
      seg: c(seg, other.seg),
      segOn: c(segOn, other.segOn),
      navOn: c(navOn, other.navOn),
      bar: c(bar, other.bar),
      onAccent: c(onAccent, other.onAccent),
      glowOpacity: glowOpacity + (other.glowOpacity - glowOpacity) * t,
      shadow: BoxShadow.lerpList(shadow, other.shadow, t)!,
      shadowSm: BoxShadow.lerpList(shadowSm, other.shadowSm, t)!,
      shadowHover: BoxShadow.lerpList(shadowHover, other.shadowHover, t)!,
      artShadow: BoxShadow.lerpList(artShadow, other.artShadow, t)!,
      tiles: [
        for (var i = 0; i < tiles.length; i++)
          (
            bg: c(tiles[i].bg, other.tiles[i].bg),
            fg: c(tiles[i].fg, other.tiles[i].fg),
          ),
      ],
      calm: next.calm,
    );
  }
}

extension RadioThemeContext on BuildContext {
  RadioTokens get rc => Theme.of(this).extension<RadioTokens>()!;

  /// True when decorative motion should be static.
  bool get calm => rc.calm || MediaQuery.disableAnimationsOf(this);
}

const display = 'Sora';
const mono = 'JetBrains Mono';

/// Sora heading with the design's tight tracking (-0.03em by default).
TextStyle heading(
  double size, {
  FontWeight weight = FontWeight.w600,
  double tracking = -0.03,
  double? height,
  Color? color,
}) => TextStyle(
  fontFamily: display,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: size * tracking,
  height: height,
  color: color,
);

TextStyle monoStyle(double size, {Color? color}) => TextStyle(
  fontFamily: mono,
  fontSize: size,
  fontWeight: FontWeight.w500,
  color: color,
);

/// Uppercase section label (`.lbl`).
TextStyle labelStyle(BuildContext context, {double size = 11}) => TextStyle(
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: size * 0.12,
  color: context.rc.mu,
);

ThemeData radioTheme({
  Brightness brightness = Brightness.dark,
  RadioAccent accent = RadioAccent.coral,
  bool calm = false,
}) {
  final dark = brightness == Brightness.dark;
  final t = RadioTokens.of(dark: dark, accent: accent, calm: calm);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t.ac,
    onPrimary: t.onAccent,
    secondary: t.act,
    onSecondary: t.onAccent,
    error: t.dangerText,
    onError: Colors.white,
    surface: t.sf,
    onSurface: t.tx,
    onSurfaceVariant: t.mu,
    outline: t.bd,
    outlineVariant: t.bd2,
    surfaceContainerHighest: t.sf2,
    surfaceContainerHigh: t.sf2,
    surfaceContainer: t.sf,
    surfaceContainerLow: t.sf,
    surfaceContainerLowest: t.bg,
    inverseSurface: t.tx,
    onInverseSurface: t.bg,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Manrope',
  );
  return base.copyWith(
    extensions: [t],
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    dividerColor: t.bd,
    splashFactory: InkSparkle.splashFactory,
    hoverColor: t.hov.withValues(alpha: 0.6),
    focusColor: t.ac.withValues(alpha: 0.18),
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(bodyColor: t.tx, displayColor: t.tx),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ac,
      selectionColor: t.ac.withValues(alpha: 0.3),
      selectionHandleColor: t.ac,
    ),
    sliderTheme: SliderThemeData(
      trackHeight: 4,
      activeTrackColor: t.ac,
      inactiveTrackColor: t.bd2,
      thumbColor: t.ac,
      overlayColor: t.ac.withValues(alpha: 0.16),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
      valueIndicatorColor: t.sf2,
      valueIndicatorTextStyle: TextStyle(color: t.tx),
    ),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        color: t.sf2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.bd2),
      ),
      textStyle: TextStyle(color: t.tx, fontSize: 12),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.sf2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: heading(20, color: t.tx),
      contentTextStyle: TextStyle(color: t.tx2, fontSize: 14, height: 1.5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: t.sf2,
      contentTextStyle: TextStyle(color: t.tx, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: t.sf2,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: t.bd2),
      ),
      textStyle: TextStyle(color: t.tx, fontSize: 14),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: t.act,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: t.ac,
      linearTrackColor: t.bd,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(t.bd2),
      radius: const Radius.circular(8),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
