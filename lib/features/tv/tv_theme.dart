import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Android TV colours from the canvas's TV design-system board, as a theme
/// extension so the TV follows the theme (dark/light) and accent settings.
/// The dark teal palette is the canvas; other accents and the light variant
/// are derived from it and from the phone/desktop light tokens.
///
/// [accent] is for text, icons, rings and indicators (the darker accent ink on
/// light backgrounds, for contrast); [accentFill] is for large accent fills
/// with [onAccent] content (primary button, play button, "playing" badge).
@immutable
class TvColors extends ThemeExtension<TvColors> {
  const TvColors({
    required this.dark,
    required this.accentChoice,
    required this.bg,
    required this.bg2,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.outline,
    required this.outline2,
    required this.text,
    required this.text2,
    required this.muted,
    required this.accent,
    required this.accentFill,
    required this.accentDeep,
    required this.onAccent,
    required this.accentSoft,
    required this.heroSurface,
    required this.heroOutline,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
    required this.tiles,
  });

  factory TvColors.build({required bool dark, required RadioAccent accent}) {
    // The canvas teal is slightly brighter than the phone/desktop teal.
    final fill = accent == RadioAccent.teal
        ? const Color(0xFF5EE6CF)
        : accent.color;
    final onAccent = accent == RadioAccent.teal
        ? const Color(0xFF05211C)
        : Color.lerp(fill, Colors.black, 0.86)!;
    if (dark) {
      return TvColors(
        dark: true,
        accentChoice: accent,
        bg: const Color(0xFF0A0E13),
        bg2: const Color(0xFF0D1218),
        surface: const Color(0xFF121921),
        surface2: const Color(0xFF18212B),
        surface3: const Color(0xFF202B37),
        outline: const Color(0xFF25313E),
        outline2: const Color(0xFF33414F),
        text: const Color(0xFFF2F5F8),
        text2: const Color(0xFFC6D0D9),
        muted: const Color(0xFF8E9BA8),
        accent: fill,
        accentFill: fill,
        accentDeep: accent == RadioAccent.teal
            ? const Color(0xFF2FBFA9)
            : Color.lerp(fill, Colors.black, 0.2)!,
        onAccent: onAccent,
        accentSoft: fill.withValues(alpha: 0.14),
        heroSurface: Color.alphaBlend(
          fill.withValues(alpha: 0.07),
          const Color(0xFF0A0E13),
        ),
        heroOutline: Color.alphaBlend(
          fill.withValues(alpha: 0.16),
          const Color(0xFF0A0E13),
        ),
        warning: const Color(0xFFFFC857),
        onWarning: const Color(0xFF2A1E00),
        error: const Color(0xFFFF7A7A),
        onError: const Color(0xFF2A0606),
        tiles: _darkTiles,
      );
    }
    return TvColors(
      dark: false,
      accentChoice: accent,
      bg: const Color(0xFFEEF0F4),
      bg2: const Color(0xFFFFFFFF),
      surface: const Color(0xFFFFFFFF),
      surface2: const Color(0xFFE3E7ED),
      surface3: const Color(0xFFD6DCE4),
      outline: const Color(0xFFD3D9E1),
      outline2: const Color(0xFFB9C1CC),
      text: const Color(0xFF0E1116),
      text2: const Color(0xFF2E3440),
      muted: const Color(0xFF596070),
      accent: accent.ink,
      accentFill: fill,
      accentDeep: Color.lerp(accent.ink, Colors.black, 0.2)!,
      onAccent: onAccent,
      accentSoft: accent.ink.withValues(alpha: 0.12),
      heroSurface: Color.alphaBlend(fill.withValues(alpha: 0.14), Colors.white),
      heroOutline: Color.alphaBlend(fill.withValues(alpha: 0.4), Colors.white),
      warning: const Color(0xFFB45309),
      onWarning: Colors.white,
      error: const Color(0xFFC2262C),
      onError: Colors.white,
      tiles: RadioTokens.of(dark: false, accent: accent).tiles,
    );
  }

  /// Station artwork stand-ins (`.p0`–`.p7`) on the dark canvas.
  static const _darkTiles = <TilePalette>[
    (bg: Color(0xFF2A1C12), fg: Color(0xFFFFB27A)),
    (bg: Color(0xFF12243A), fg: Color(0xFF8FC6FF)),
    (bg: Color(0xFF28162F), fg: Color(0xFFE5A8FF)),
    (bg: Color(0xFF11291F), fg: Color(0xFF7FE3B2)),
    (bg: Color(0xFF2D2612), fg: Color(0xFFFFD978)),
    (bg: Color(0xFF311519), fg: Color(0xFFFF97A0)),
    (bg: Color(0xFF1A1F35), fg: Color(0xFFAAB5FF)),
    (bg: Color(0xFF0F2A2C), fg: Color(0xFF7FE0E8)),
  ];

  /// The TV colours of [context]'s theme (the dark teal canvas by default).
  static TvColors of(BuildContext context) =>
      Theme.of(context).extension<TvColors>() ??
      TvColors.build(dark: true, accent: RadioAccent.teal);

  final bool dark;
  final RadioAccent accentChoice;
  final Color bg, bg2, surface, surface2, surface3, outline, outline2;
  final Color text, text2, muted;
  final Color accent, accentFill, accentDeep, onAccent, accentSoft;
  final Color heroSurface, heroOutline;
  final Color warning, onWarning, error, onError;
  final List<TilePalette> tiles;

  @override
  TvColors copyWith() => this;

  @override
  TvColors lerp(TvColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    final next = t < 0.5 ? this : other;
    return TvColors(
      dark: next.dark,
      accentChoice: next.accentChoice,
      bg: c(bg, other.bg),
      bg2: c(bg2, other.bg2),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      outline: c(outline, other.outline),
      outline2: c(outline2, other.outline2),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      muted: c(muted, other.muted),
      accent: c(accent, other.accent),
      accentFill: c(accentFill, other.accentFill),
      accentDeep: c(accentDeep, other.accentDeep),
      onAccent: c(onAccent, other.onAccent),
      accentSoft: c(accentSoft, other.accentSoft),
      heroSurface: c(heroSurface, other.heroSurface),
      heroOutline: c(heroOutline, other.heroOutline),
      warning: c(warning, other.warning),
      onWarning: c(onWarning, other.onWarning),
      error: c(error, other.error),
      onError: c(onError, other.onError),
      tiles: [
        for (var i = 0; i < tiles.length; i++)
          (
            bg: c(tiles[i].bg, other.tiles[i].bg),
            fg: c(tiles[i].fg, other.tiles[i].fg),
          ),
      ],
    );
  }
}

extension TvThemeContext on BuildContext {
  /// TV colours for the current theme and accent.
  TvColors get tv => TvColors.of(this);
}

/// Layout tokens in dp.
abstract final class TvLayout {
  /// Overscan-safe margins (5 % of the screen).
  static const safeX = 48.0;
  static const safeY = 27.0;
  static const railCollapsed = 100.0;
  static const railOpen = 230.0;

  /// Left edge of page content; card rings get [ringInset] of room inside it.
  static const contentLeft = 112.0;
  static const ringInset = 12.0;
  static const headerHeight = 86.0;
  static const card = 140.0;
  static const gutter = 18.0;

  /// Focused rows sit this far down the scroll viewport.
  static const rowAnchor = 0.37;
}

/// Durations and curves from the motion board. Every animation is implicit,
/// so a new key press retargets it from its current value.
abstract final class TvMotion {
  static const focus = Duration(milliseconds: 180);
  static const screen = Duration(milliseconds: 320);
  static const railClose = Duration(milliseconds: 240);
  static const player = Duration(milliseconds: 420);
  static const playerClose = Duration(milliseconds: 280);
  static const dialog = Duration(milliseconds: 260);
  static const press = Duration(milliseconds: 90);
  static const longPress = Duration(milliseconds: 550);
  static const focusCurve = Cubic(0.2, 0.8, 0.2, 1);
  static const outCurve = Cubic(0.16, 1, 0.3, 1);

  /// [d], or zero when motion is reduced.
  static Duration of(BuildContext context, Duration d) =>
      context.calm ? Duration.zero : d;
}

/// Focus ring: a background-coloured gap, the accent ring and a drop shadow.
List<BoxShadow> tvRing(BuildContext context, {bool tight = false}) {
  final tv = context.tv;
  return [
    if (!tight)
      BoxShadow(
        color: Colors.black.withValues(alpha: tv.dark ? 0.55 : 0.18),
        blurRadius: 30,
        offset: const Offset(0, 14),
      ),
    BoxShadow(color: tv.accent, spreadRadius: tight ? 2 : 4.5),
    if (!tight) BoxShadow(color: tv.bg, spreadRadius: 2),
  ];
}

/// Display type. The canvas uses Outfit/Figtree; the bundled Sora/Manrope
/// stand in, because runtime font fetching would break offline startup.
/// A null [color] inherits the theme's text colour.
TextStyle tvHeading(double size, {Color? color, int? weight}) => heading(
  size,
  tracking: -0.02,
  height: 1.1,
  color: color,
  weight: weight == 700 ? FontWeight.w700 : FontWeight.w600,
);

TextStyle tvBody(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w600,
  double? height,
}) => TextStyle(
  // Explicit, so styles that replace rather than merge (animated text, the
  // toast host above the Navigator) keep the bundled family.
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: weight,
  color: color,
  height: height,
);

/// Uppercase section label (`.lbl`).
TextStyle tvLabel(Color color, {double size = 10}) => TextStyle(
  fontFamily: 'Manrope',
  fontSize: size,
  fontWeight: FontWeight.w700,
  letterSpacing: size * 0.16,
  color: color,
);
