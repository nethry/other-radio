import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Android TV tokens from the canvas's TV design-system board. The canvas is
/// drawn at 1920 × 1080 px; a 1080p or 4K TV reports ≈ 960 × 540 dp, so every
/// value here is the canvas value ÷ 2. The TV palette is dark-only and uses
/// its own teal accent, independent of the phone/desktop accent setting.
abstract final class TvColors {
  static const bg = Color(0xFF0A0E13);
  static const bg2 = Color(0xFF0D1218);
  static const surface = Color(0xFF121921);
  static const surface2 = Color(0xFF18212B);
  static const surface3 = Color(0xFF202B37);
  static const outline = Color(0xFF25313E);
  static const outline2 = Color(0xFF33414F);
  static const text = Color(0xFFF2F5F8);
  static const text2 = Color(0xFFC6D0D9);
  static const muted = Color(0xFF8E9BA8);
  static const accent = Color(0xFF5EE6CF);
  static const accentDeep = Color(0xFF2FBFA9);
  static const onAccent = Color(0xFF05211C);
  static const accentSoft = Color(0x245EE6CF);
  static const heroSurface = Color(0xFF0F2224);
  static const heroOutline = Color(0xFF1D3A3B);
  static const warning = Color(0xFFFFC857);
  static const onWarning = Color(0xFF2A1E00);
  static const error = Color(0xFFFF7A7A);
  static const onError = Color(0xFF2A0606);

  /// Station artwork stand-ins (`.p0`–`.p7`) while a favicon loads.
  static const tiles = <TilePalette>[
    (bg: Color(0xFF2A1C12), fg: Color(0xFFFFB27A)),
    (bg: Color(0xFF12243A), fg: Color(0xFF8FC6FF)),
    (bg: Color(0xFF28162F), fg: Color(0xFFE5A8FF)),
    (bg: Color(0xFF11291F), fg: Color(0xFF7FE3B2)),
    (bg: Color(0xFF2D2612), fg: Color(0xFFFFD978)),
    (bg: Color(0xFF311519), fg: Color(0xFFFF97A0)),
    (bg: Color(0xFF1A1F35), fg: Color(0xFFAAB5FF)),
    (bg: Color(0xFF0F2A2C), fg: Color(0xFF7FE0E8)),
  ];
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

/// Focus ring: a background-coloured gap, the teal ring and a drop shadow.
List<BoxShadow> tvRing({bool tight = false}) => [
  if (!tight)
    const BoxShadow(
      color: Color(0x8C000000),
      blurRadius: 30,
      offset: Offset(0, 14),
    ),
  BoxShadow(color: TvColors.accent, spreadRadius: tight ? 2 : 4.5),
  if (!tight) const BoxShadow(color: TvColors.bg, spreadRadius: 2),
];

/// Display type. The canvas uses Outfit/Figtree; the bundled Sora/Manrope
/// stand in, because runtime font fetching would break offline startup.
TextStyle tvHeading(double size, {Color color = TvColors.text, int? weight}) =>
    heading(
      size,
      tracking: -0.02,
      height: 1.1,
      color: color,
      weight: weight == 700 ? FontWeight.w700 : FontWeight.w600,
    );

TextStyle tvBody(
  double size, {
  Color color = TvColors.text,
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
TextStyle tvLabel({Color color = TvColors.muted, double size = 10}) =>
    TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w700,
      letterSpacing: size * 0.16,
      color: color,
    );
