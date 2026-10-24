import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import 'tv_focusable.dart';
import 'tv_player.dart';
import 'tv_theme.dart';

/// Shared Hero tag: the mini-player artwork flies into the full player.
const tvArtHero = 'tv-now-playing-art';

/// Station artwork: the favicon on its palette colour, the monogram while it
/// loads, and a dashed waveform tile when there is no usable logo — never a
/// broken image.
class TvArt extends StatelessWidget {
  const TvArt({
    super.key,
    required this.station,
    required this.size,
    this.radius = 14,
    this.circle = false,
  });
  final Station station;
  final double size;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final palette = context.tv.tiles[paletteIndex(station.id)];
    final shape = circle
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final monogramTile = ColoredBox(
      color: palette.bg,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.08),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              monogram(station.name),
              maxLines: 1,
              style: heading(
                size * 0.23,
                weight: FontWeight.w700,
                tracking: -0.04,
                color: palette.fg,
              ),
            ),
          ),
        ),
      ),
    );
    final missing = _MissingArt(station: station, size: size, shape: shape);
    final art = station.artUri;
    final pixels = (size * 0.76 * MediaQuery.devicePixelRatioOf(context))
        .round();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: art == null
            ? missing
            : ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: CachedNetworkImage(
                  imageUrl: art.toString(),
                  memCacheWidth: pixels > 0 ? pixels : null,
                  fadeInDuration: TvMotion.of(
                    context,
                    const Duration(milliseconds: 250),
                  ),
                  fadeOutDuration: Duration.zero,
                  placeholder: (_, _) => monogramTile,
                  errorWidget: (_, _, _) => missing,
                  imageBuilder: (_, image) => ColoredBox(
                    color: palette.bg,
                    child: Padding(
                      padding: EdgeInsets.all(size * (circle ? 0.2 : 0.12)),
                      child: Image(
                        image: image,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _MissingArt extends StatelessWidget {
  const _MissingArt({
    required this.station,
    required this.size,
    required this.shape,
  });
  final Station station;
  final double size;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedBorder(shape, context.tv.outline2),
    child: ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: ColoredBox(
        color: context.tv.surface2,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: math.max(14, size * 0.2),
                  color: context.tv.muted,
                ),
                if (size >= 60)
                  Padding(
                    padding: EdgeInsets.only(top: size * 0.04),
                    child: Text(
                      monogram(station.name),
                      style: TextStyle(
                        fontSize: size * 0.11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: size * 0.002,
                        color: context.tv.text2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _DashedBorder extends CustomPainter {
  _DashedBorder(this.shape, this.color);
  final ShapeBorder shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.5);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in shape.getOuterPath(rect).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.shape != shape || old.color != color;
}

/// Playback state of the current station as the canvas names it.
enum TvStatus { idle, connecting, live, paused, error }

TvStatus tvStatus(RadioPhase phase) => switch (phase) {
  RadioPhase.idle => TvStatus.idle,
  RadioPhase.loading || RadioPhase.buffering => TvStatus.connecting,
  RadioPhase.playing => TvStatus.live,
  RadioPhase.paused => TvStatus.paused,
  RadioPhase.error => TvStatus.error,
};

/// Spinner that stays still under reduced motion (repeating animations would
/// also stall widget tests).
class TvSpinner extends StatelessWidget {
  const TvSpinner({super.key, this.size = 10, this.color, this.stroke = 1.6});
  final double size;
  final Color? color;
  final double stroke;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      value: context.calm ? 0.75 : null,
      strokeWidth: stroke,
      color: color ?? context.tv.warning,
    ),
  );
}

/// The badge on the current station's artwork. Focus never uses teal fills,
/// so "playing" and "focused" stay distinguishable.
class PhaseBadge extends StatelessWidget {
  const PhaseBadge({super.key, required this.phase});
  final RadioPhase phase;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (tvStatus(phase)) {
      TvStatus.live => ('GRA', context.tv.accent, context.tv.onAccent),
      TvStatus.connecting => (
        'ŁĄCZENIE',
        context.tv.warning,
        context.tv.onWarning,
      ),
      TvStatus.paused => ('PAUZA', context.tv.outline2, context.tv.text),
      TvStatus.error => ('BŁĄD', context.tv.error, context.tv.onError),
      TvStatus.idle => ('', context.tv.outline2, context.tv.text),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (phase == RadioPhase.playing || phase == RadioPhase.paused) ...[
            Eq(color: fg, height: 10, playing: phase == RadioPhase.playing),
            const SizedBox(width: 5),
          ],
          if (tvStatus(phase) == TvStatus.connecting) ...[
            TvSpinner(size: 9, color: fg, stroke: 1.4),
            const SizedBox(width: 5),
          ],
          Text(
            context.tr(label),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Station card (`StationCard`): artwork scales and gains the ring when
/// focused; the title brightens.
class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.focused,
    required this.pressed,
    this.width = TvLayout.card,
    this.phase,
    this.favorite = false,
    this.number,
    this.lifted = false,
  });
  final Station station;
  final bool focused;
  final bool pressed;
  final double width;

  /// Playback phase when this is the current station.
  final RadioPhase? phase;
  final bool favorite;

  /// Position badge in the favourites grid.
  final int? number;

  /// Being moved in the favourites grid.
  final bool lifted;

  @override
  Widget build(BuildContext context) {
    final language = context.languageCode;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSlide(
            offset: Offset(0, lifted ? -0.06 : 0),
            duration: TvMotion.of(context, TvMotion.focus),
            curve: TvMotion.focusCurve,
            child: TvScale(
              focused: focused || lifted,
              pressed: pressed,
              scale: lifted ? 1.12 : 1.08,
              pressedScale: 1.02,
              child: AnimatedContainer(
                duration: TvMotion.of(context, TvMotion.focus),
                curve: TvMotion.focusCurve,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: focused || lifted ? tvRing(context) : const [],
                ),
                child: Stack(
                  children: [
                    TvArt(station: station, size: width),
                    if (phase != null && phase != RadioPhase.idle)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: PhaseBadge(phase: phase!),
                      ),
                    if (favorite)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color(0xB80A0E13),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 11,
                            color: context.tv.accent,
                          ),
                        ),
                      ),
                    if (number != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xB80A0E13),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$number',
                            style: monoStyle(10, color: context.tv.text2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          AnimatedDefaultTextStyle(
            duration: TvMotion.of(context, TvMotion.focus),
            style: tvBody(
              13,
              weight: FontWeight.w700,
              color: focused ? context.tv.text : context.tv.text2,
            ),
            child: Text(
              station.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle(station, language: language),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tvBody(10, color: context.tv.muted, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Focusable station card wired to playback and favourites state.
class TvStationCard extends ConsumerWidget {
  const TvStationCard({
    super.key,
    required this.station,
    required this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.width = TvLayout.card,
    this.number,
    this.lifted = false,
  });
  final Station station;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;
  final double width;
  final int? number;
  final bool lifted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider.select((p) => p.state));
    final favorite = ref.watch(
      stationsProvider.select((c) => c.isFavorite(station)),
    );
    final current = state.station?.id == station.id;
    final status = current
        ? switch (tvStatus(state.phase)) {
            TvStatus.live => ', gra teraz',
            TvStatus.connecting => ', łączenie',
            TvStatus.paused => ', wstrzymano',
            TvStatus.error => ', błąd',
            TvStatus.idle => '',
          }
        : '';
    return Semantics(
      button: true,
      label:
          '${station.name}${context.tr(status)}'
          '${favorite ? context.tr(', ulubiona') : ''}',
      excludeSemantics: true,
      child: TvFocusable(
        focusNode: focusNode,
        autofocus: autofocus,
        reveal: false,
        onTap: onTap,
        onLongPress: onLongPress,
        builder: (context, focused, pressed) => StationCard(
          station: station,
          focused: focused,
          pressed: pressed,
          width: width,
          phase: current ? state.phase : null,
          favorite: favorite,
          number: number,
          lifted: lifted,
        ),
      ),
    );
  }
}

/// Pill button (`OrButton`): secondary fill turns white when focused, the
/// primary stays teal; both gain the ring.
class TvButton extends StatelessWidget {
  const TvButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.primary = false,
    this.focusNode,
    this.autofocus = false,
    this.onLongPress,
    this.height = 38,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool primary;
  final FocusNode? focusNode;
  final bool autofocus;
  final double height;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: focusNode,
    autofocus: autofocus,
    onTap: onTap,
    onLongPress: onLongPress,
    semanticLabel: label,
    builder: (context, focused, pressed) {
      final bg = onTap == null
          ? context.tv.surface3.withValues(alpha: 0.4)
          : primary
          ? context.tv.accent
          : focused
          ? context.tv.text
          : context.tv.surface3;
      final fg = primary
          ? context.tv.onAccent
          : focused
          ? context.tv.bg
          : context.tv.text;
      return TvScale(
        focused: focused,
        pressed: pressed,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.focus),
          curve: TvMotion.focusCurve,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height * 0.53),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: focused ? tvRing(context) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: height * 0.4, color: fg),
                SizedBox(width: height * 0.18),
              ],
              Flexible(
                child: Text(
                  context.tr(label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tvBody(
                    height * 0.34,
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Round icon button (`OrIconButton`); [big] is the teal play control.
class TvIconButton extends StatelessWidget {
  const TvIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
    this.on = false,
    this.busy = false,
    this.focusNode,
    this.autofocus = false,
    this.onFocusChange,
    this.size,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool big;
  final bool on;
  final bool busy;
  final FocusNode? focusNode;
  final bool autofocus;
  final ValueChanged<bool>? onFocusChange;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final side = size ?? (big ? 72.0 : 52.0);
    return TvFocusable(
      focusNode: focusNode,
      autofocus: autofocus,
      onTap: onTap,
      semanticLabel: label,
      selected: on ? true : null,
      onFocusChange: onFocusChange,
      builder: (context, focused, pressed) {
        final bg = big
            ? context.tv.accent
            : focused
            ? context.tv.text
            : context.tv.surface3;
        final fg = big
            ? context.tv.onAccent
            : on
            ? (focused ? context.tv.accentDeep : context.tv.accent)
            : focused
            ? context.tv.bg
            : context.tv.text;
        return TvScale(
          focused: focused,
          pressed: pressed,
          scale: 1.1,
          child: AnimatedContainer(
            duration: TvMotion.of(context, TvMotion.focus),
            curve: TvMotion.focusCurve,
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: focused ? tvRing(context) : const [],
            ),
            child: Center(
              child: busy
                  ? TvSpinner(size: side * 0.38, color: fg, stroke: 2.5)
                  : Icon(icon, size: side * 0.44, color: fg),
            ),
          ),
        );
      },
    );
  }
}

/// Pill chip (`.chip`); [selected] marks the active sort.
class TvChip extends StatelessWidget {
  const TvChip({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.icon,
    this.focusNode,
    this.autofocus = false,
    this.child,
    this.translate = true,
  });
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final IconData? icon;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Custom content, e.g. a highlighted suggestion.
  final Widget? child;

  /// App-owned labels are localized; queries and tags are shown as typed.
  final bool translate;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: focusNode,
    autofocus: autofocus,
    onTap: onTap,
    semanticLabel: translate ? label : null,
    selected: selected,
    builder: (context, focused, pressed) {
      final fg = focused
          ? context.tv.bg
          : selected
          ? context.tv.accent
          : context.tv.text2;
      return TvScale(
        focused: focused,
        pressed: pressed,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.focus),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: focused
                ? context.tv.text
                : selected
                ? context.tv.accentSoft
                : context.tv.surface2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused
                  ? Colors.transparent
                  : selected
                  ? context.tv.accent
                  : context.tv.outline,
            ),
            boxShadow: focused ? tvRing(context) : const [],
          ),
          child: DefaultTextStyle.merge(
            style: tvBody(12, color: fg),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: fg),
                  const SizedBox(width: 6),
                ],
                child ??
                    Text(
                      translate ? context.tr(label) : label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Remote key cap (`.kc`) in hints.
class TvKeyCap extends StatelessWidget {
  const TvKeyCap(this.text, {super.key, this.color});
  final String text;

  /// Highlight colour; a plain cap by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tv = context.tv;
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color ?? tv.outline2),
      ),
      child: Text(
        context.tr(text),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: color ?? tv.text2,
        ),
      ),
    );
  }
}

/// `[KEY] action` hint line.
class TvHint extends StatelessWidget {
  const TvHint(this.keyCap, this.text, {super.key});
  final String keyCap;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      TvKeyCap(keyCap),
      const SizedBox(width: 5),
      Text(context.tr(text), style: tvBody(10, color: context.tv.muted)),
    ],
  );
}

/// Status chip: live (teal, pulse) · connecting (amber spinner) · paused ·
/// error.
class TvStatusChip extends StatelessWidget {
  const TvStatusChip({super.key, required this.phase, required this.text});
  final RadioPhase phase;

  /// Localized source key.
  final String text;

  @override
  Widget build(BuildContext context) {
    final status = tvStatus(phase);
    final (bg, fg) = switch (status) {
      TvStatus.live => (context.tv.accentSoft, context.tv.accent),
      TvStatus.connecting => (
        context.tv.warning.withValues(alpha: 0.14),
        context.tv.warning,
      ),
      TvStatus.error => (
        context.tv.error.withValues(alpha: 0.14),
        context.tv.error,
      ),
      TvStatus.paused ||
      TvStatus.idle => (context.tv.surface3, context.tv.text2),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == TvStatus.live) ...[
            LiveDot(size: 6, color: fg),
            const SizedBox(width: 6),
          ],
          if (status == TvStatus.connecting) ...[
            TvSpinner(size: 10, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              context.tr(text).toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini-player (`MiniPlayer`): always in the page header while a station is
/// loaded; OK opens the full player.
class TvMiniPlayer extends ConsumerWidget {
  const TvMiniPlayer({super.key, this.focusNode});
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider.select((p) => p.state));
    final station = state.station;
    if (station == null) return const SizedBox.shrink();
    final status = tvStatus(state.phase);
    final (text, color) = switch (status) {
      TvStatus.live => ('Na żywo', context.tv.accent),
      TvStatus.connecting => ('Łączenie…', context.tv.warning),
      TvStatus.paused => ('Pauza', context.tv.text2),
      TvStatus.error => ('Błąd strumienia', context.tv.error),
      TvStatus.idle => ('GOTOWE', context.tv.muted),
    };
    return TvFocusable(
      focusNode: focusNode,
      reveal: false,
      semanticLabel: 'Otwórz odtwarzacz',
      onTap: () => openTvPlayer(context),
      builder: (context, focused, pressed) => TvScale(
        focused: focused,
        pressed: pressed,
        scale: 1.05,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.focus),
          height: 48,
          padding: const EdgeInsets.fromLTRB(8, 0, 14, 0),
          decoration: BoxDecoration(
            color: focused ? context.tv.surface3 : context.tv.surface2,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: focused ? Colors.transparent : context.tv.outline,
            ),
            boxShadow: focused ? tvRing(context) : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: tvArtHero,
                child: TvArt(station: station, size: 32, circle: true),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tvBody(12, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (status == TvStatus.live ||
                            status == TvStatus.paused) ...[
                          Eq(
                            color: color,
                            height: 8,
                            playing: status == TvStatus.live,
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (status == TvStatus.connecting) ...[
                          TvSpinner(size: 8, color: color, stroke: 1.2),
                          const SizedBox(width: 5),
                        ],
                        Flexible(
                          child: Text(
                            context.tr(text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (focused) ...[
                const SizedBox(width: 8),
                TvKeyCap('OK', color: context.tv.accent),
                const SizedBox(width: 5),
                Text(
                  context.tr('Pełny ekran'),
                  style: tvBody(10, color: context.tv.text2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// On/off switch (`.tg`) with a slight overshoot on the thumb.
class TvSwitch extends StatelessWidget {
  const TvSwitch({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: TvMotion.of(context, const Duration(milliseconds: 200)),
    width: 42,
    height: 24,
    padding: const EdgeInsets.all(2.5),
    decoration: BoxDecoration(
      color: on ? context.tv.accent : context.tv.outline2,
      borderRadius: BorderRadius.circular(12),
    ),
    child: AnimatedAlign(
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      duration: TvMotion.of(context, const Duration(milliseconds: 280)),
      curve: const Cubic(0.3, 0.7, 0.3, 1.3),
      child: Container(
        width: 19,
        height: 19,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}

/// Logo: waveform glyph + `other`/`radio` wordmark.
class TvWordmark extends StatelessWidget {
  const TvWordmark({super.key, this.size = 18, this.glyph = true});
  final double size;
  final bool glyph;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'OtherRadio',
    excludeSemantics: true,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (glyph) ...[
          Icon(
            Icons.graphic_eq_rounded,
            color: context.tv.accent,
            size: size * 1.15,
          ),
          SizedBox(width: size * 0.35),
        ],
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'other',
                style: heading(
                  size,
                  weight: FontWeight.w700,
                  color: context.tv.text,
                ),
              ),
              TextSpan(
                text: 'radio',
                style: heading(
                  size,
                  weight: FontWeight.w400,
                  color: context.tv.accent,
                ),
              ),
            ],
          ),
          maxLines: 1,
        ),
      ],
    ),
  );
}

/// Page scaffold: title, subtitle and the mini-player in an 86 dp header,
/// content below. [left] is the content edge (rail-aware by default).
class TvPageFrame extends StatelessWidget {
  const TvPageFrame({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.translateSubtitle = true,
    this.actions = const [],
    this.miniFocusNode,
    this.left = TvLayout.contentLeft,
  });
  final String title;
  final String? subtitle;
  final bool translateSubtitle;
  final List<Widget> actions;
  final FocusNode? miniFocusNode;
  final double left;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: left),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: TvLayout.headerHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              TvLayout.ringInset,
              24,
              TvLayout.safeX,
              0,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          context.tr(title),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvHeading(24),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          translateSubtitle ? context.tr(subtitle!) : subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvBody(11, color: context.tv.muted),
                        ),
                      ],
                    ],
                  ),
                ),
                for (final action in actions) ...[
                  action,
                  const SizedBox(width: 14),
                ],
                TvMiniPlayer(focusNode: miniFocusNode),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

/// Centered empty/error state with up to two actions.
class TvEmptyState extends StatelessWidget {
  const TvEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
    this.color,
  });
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  /// Icon colour; the accent by default.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? context.tv.accent;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          TvLayout.ringInset,
          12,
          TvLayout.safeX,
          TvLayout.safeY,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: color),
            ),
            const SizedBox(height: 14),
            Text(
              context.tr(title),
              textAlign: TextAlign.center,
              style: tvHeading(24),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Text(
                context.tr(message),
                textAlign: TextAlign.center,
                style: tvBody(14, color: context.tv.text2, height: 1.4),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 20),
              Wrap(spacing: 12, runSpacing: 12, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}
