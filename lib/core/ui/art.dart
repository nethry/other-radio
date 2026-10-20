import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/models/station.dart';
import '../format.dart';
import '../theme.dart';

/// Station artwork tile (`.tile.pN`). Shows the Radio Browser favicon on the
/// station's palette colour, falling back to a monogram while it loads or
/// when it is missing or undecodable (`.ico`/SVG favicons are common).
/// Pass [width] `double.infinity` for card art.
class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    required this.station,
    this.width = 48,
    this.height,
    this.radius = 14,
    this.fontSize,
    this.circle = false,
    this.overlay,
    this.caption,
    this.shadow = false,
  });
  final Station station;
  final double width;
  final double? height;
  final double radius;
  final double? fontSize;
  final bool circle;

  /// Positioned children drawn over the tile, e.g. an equalizer.
  final List<Widget>? overlay;

  /// Small mono label under the monogram (player art).
  final String? caption;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final palette = rc.tiles[paletteIndex(station.id)];
    final h = height ?? width;
    final art = station.artUri;
    final fallback = _Monogram(
      station: station,
      color: palette.fg,
      size: fontSize ?? (h.isFinite ? h * 0.27 : 24),
      // Large tiles name the variant (`ESKA` + `ROCK`) so siblings differ.
      caption: caption ?? (h >= 64 ? monogramCaption(station.name) : null),
    );
    final shape = circle
        ? const ShapeDecoration(shape: CircleBorder())
        : ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
          );
    return ExcludeSemantics(
      child: Container(
        width: width,
        height: h,
        decoration: BoxDecoration(
          color: palette.bg,
          shape: circle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circle ? null : BorderRadius.circular(radius),
          boxShadow: shadow ? rc.artShadow : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: art == null
                  ? fallback
                  : ClipPath(
                      clipper: ShapeBorderClipper(shape: shape.shape),
                      child: LayoutBuilder(
                        builder: (context, box) => _Logo(
                          url: art.toString(),
                          box: box.biggest,
                          circle: circle,
                          fallback: fallback,
                        ),
                      ),
                    ),
            ),
            ...?overlay,
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({
    required this.url,
    required this.box,
    required this.circle,
    required this.fallback,
  });
  final String url;
  final Size box;
  final bool circle;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final side = box.shortestSide;
    // A circle needs more inset so a square logo's corners stay inside it.
    final inset = side * (circle ? 0.2 : 0.12);
    final pixels = ((side - inset * 2) * MediaQuery.devicePixelRatioOf(context))
        .round();
    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: pixels > 0 ? pixels : null,
      fadeInDuration: context.calm
          ? Duration.zero
          : const Duration(milliseconds: 250),
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => fallback,
      errorWidget: (_, _, _) => fallback,
      imageBuilder: (context, image) => Padding(
        padding: EdgeInsets.all(inset),
        child: Image(
          image: image,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
    required this.station,
    required this.color,
    required this.size,
    this.caption,
  });
  final Station station;
  final Color color;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              monogram(station.name),
              maxLines: 1,
              style: heading(
                size,
                weight: FontWeight.w700,
                tracking: size > 30 ? -0.05 : -0.02,
                height: 1,
                color: color,
              ),
            ),
            if (caption != null) ...[
              SizedBox(height: size * 0.08),
              Opacity(
                opacity: 0.8,
                child: Text(
                  caption!,
                  style: monoStyle(
                    math.max(10, size * 0.17),
                    color: color,
                  ).copyWith(letterSpacing: size * 0.017),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// OtherRadio logo: waveform glyph and the `other`/`radio` wordmark, matching
/// the launcher icons in `assets/branding/`.
class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 22});

  /// Wordmark font size; the glyph scales with it.
  final double size;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final mint = rc.dark ? brandMint : brandMintInk;
    return Semantics(
      label: 'OtherRadio',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.graphic_eq_rounded, color: mint, size: size * 1.3),
          SizedBox(width: size * 0.4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'other',
                  style: TextStyle(fontWeight: FontWeight.w800, color: rc.tx),
                ),
                TextSpan(
                  text: 'radio',
                  style: TextStyle(fontWeight: FontWeight.w400, color: mint),
                ),
              ],
            ),
            style: TextStyle(
              fontSize: size,
              height: 1,
              letterSpacing: -size * 0.045,
            ),
          ),
        ],
      ),
    );
  }
}
