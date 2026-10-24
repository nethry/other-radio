import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/country_filter.dart';
import 'tv_theme.dart';

/// Android TV cold-start splash ("tuning in", canvas boards 0 · Ekran
/// startowy): a signal line, the waveform rising, radio waves, the wordmark,
/// then a loader only while the catalogue is still loading, and an exit into
/// [child] (the TV shell), which mounts underneath during the exit so focus
/// lands on Discover's default item.
///
/// The reveal always finishes (≈ 3.5 s) so the logo is never cut mid-wipe;
/// the wait is capped at 6 s, after which Discover shows cache/skeletons.
/// OK or Back skip to the exit; Back during the exit closes the app. Reduced
/// motion shows the static logo and fades out in 600 ms. A warm start keeps
/// this state, so the splash never replays.
class TvSplash extends ConsumerStatefulWidget {
  const TvSplash({super.key, required this.child});
  final Widget child;

  /// Splash stage colour, shared with the native launch theme
  /// (`values-television/styles.xml`) so the hand-off never flashes.
  static const stage = Color(0xFF05080B);

  @override
  ConsumerState<TvSplash> createState() => _TvSplashState();
}

class _TvSplashState extends ConsumerState<TvSplash>
    with TickerProviderStateMixin {
  static const _revealSeconds = 3.5;
  static const _maxWait = Duration(seconds: 6);
  static final _skipKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  late final _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3500),
  );

  /// Loader phase: equaliser dance and glow breathing.
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2240),
  );
  late final _dust = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );
  late final _cap = AnimationController(vsync: this, duration: _maxWait);
  late final _exit = AnimationController(vsync: this);
  final _focus = FocusNode(debugLabel: 'splash');

  bool _started = false;
  bool _calm = false;
  bool _sawLoading = false;
  bool _loader = false;
  bool _loaded = false;
  bool _exiting = false;
  bool _done = false;

  /// Stations to show, or a finished refresh (which may have failed — then
  /// Discover shows its error state).
  bool get _ready {
    final catalogue = ref.read(stationsProvider);
    return catalogue.stations.isNotEmpty || (_sawLoading && !catalogue.loading);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _calm = context.calm;
    _sawLoading = ref.read(stationsProvider).loading;
    _cap.forward().then((_) => _leave());
    if (_calm) {
      _reveal.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _afterReveal());
    } else {
      _dust.repeat();
      _reveal.forward().then((_) => _afterReveal());
    }
  }

  @override
  void dispose() {
    _reveal.dispose();
    _loop.dispose();
    _dust.dispose();
    _cap.dispose();
    _exit.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _afterReveal() {
    if (!mounted || _exiting) return;
    if (_ready) {
      _leave();
      return;
    }
    setState(() => _loader = true);
    if (!_calm) _loop.repeat();
  }

  void _leave() {
    if (!mounted || _exiting) return;
    _cap.stop();
    _loop.stop();
    setState(() {
      _exiting = true;
      _loaded = _ready;
    });
    _exit.duration = Duration(milliseconds: _calm ? 600 : 900);
    _exit.forward().then((_) {
      if (!mounted) return;
      _dust.stop();
      setState(() => _done = true);
    });
  }

  void _back() {
    if (_exiting) {
      SystemNavigator.pop();
    } else {
      _leave();
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (_exiting) return KeyEventResult.ignored;
    if (event is KeyDownEvent && _skipKeys.contains(event.logicalKey)) {
      _leave();
    }
    // Nothing behind the splash may react to the remote.
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(stationsProvider, (_, catalogue) {
      if (catalogue.loading) _sawLoading = true;
      if (_reveal.isCompleted && _ready) _leave();
    });
    return Stack(
      children: [
        if (_exiting)
          Positioned.fill(
            key: const ValueKey('app'),
            child: AnimatedBuilder(
              animation: _exit,
              builder: (context, child) {
                final t = _calm
                    ? 1.0
                    : const Interval(
                        0.31,
                        1,
                        curve: TvMotion.outCurve,
                      ).transform(_exit.value);
                return Transform.scale(scale: 0.96 + 0.04 * t, child: child);
              },
              child: widget.child,
            ),
          ),
        if (!_done)
          Positioned.fill(
            key: const ValueKey('splash'),
            child: IgnorePointer(
              ignoring: _exiting,
              child: PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _back();
                },
                child: Focus(
                  focusNode: _focus,
                  autofocus: true,
                  onKeyEvent: _onKey,
                  // Text styles need a Material ancestor (no debug
                  // underline); the shell's Scaffold is not built yet.
                  child: Material(
                    type: MaterialType.transparency,
                    child: _stage(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _stage(BuildContext context) {
    final country = ref.watch(stationsProvider.select((c) => c.countryCode));
    final tagline = switch (country) {
      'PL' => context.tr('Polskie radio · na żywo'),
      '' => context.tr('Radio z całego świata · na żywo'),
      _ => '${countryLabel(context, country)} · ${context.tr('na żywo')}',
    };
    final message = context.tr(_loaded ? 'Gotowe' : 'Wczytywanie stacji…');
    return Semantics(
      label: 'OtherRadio',
      value: _loader ? message : null,
      liveRegion: _loader,
      child: AnimatedBuilder(
        animation: Listenable.merge([_reveal, _loop, _exit, _dust]),
        builder: (context, _) => _Frame(
          seconds: _reveal.value * _revealSeconds,
          loop: _loop.isAnimating ? _loop.value : null,
          dust: _calm ? null : _dust.value,
          exit: _exit.value,
          calm: _calm,
          loader: _loader,
          loaded: _loaded,
          tagline: tagline,
          message: message,
        ),
      ),
    );
  }
}

/// One frame of the splash, a pure function of the timeline.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.seconds,
    required this.loop,
    required this.dust,
    required this.exit,
    required this.calm,
    required this.loader,
    required this.loaded,
    required this.tagline,
    required this.message,
  });
  final double seconds;
  final double? loop;
  final double? dust;
  final double exit;
  final bool calm;
  final bool loader;
  final bool loaded;
  final String tagline;
  final String message;

  static const _bars = [20.0, 41.0, 75.0, 41.0, 20.0];
  static const _barWidth = 9.0;
  static const _barGap = 8.0;
  static const _logoGap = 22.0;
  static const _wordSize = 75.0;

  /// Progress of [seconds] through `a…b` with [curve].
  double _iv(double a, double b, [Curve curve = TvMotion.outCurve]) =>
      curve.transform(((seconds - a) / (b - a)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Exit: logo scales up, blurs and fades; the stage colour gives way to
    // Discover underneath.
    final out = calm
        ? exit
        : const Interval(
            0,
            0.77,
            curve: Cubic(0.7, 0, 0.84, 0),
          ).transform(exit);
    final backdrop = calm ? exit : const Interval(0.35, 0.9).transform(exit);
    final background = Color.lerp(
      TvSplash.stage,
      TvColors.bg,
      const Interval(0, 0.5).transform(exit),
    )!;

    // Glow: breathes in with the bars, keeps breathing while loading.
    final glowIn = _iv(0.56, 1.54);
    final breath = loop == null ? 0.0 : math.sin(loop! * 2 * math.pi);
    final glowOpacity = (glowIn * 0.7 + breath * 0.08).clamp(0.0, 1.0);
    final glowScale = 0.55 + 0.45 * glowIn + breath * 0.02 + 0.3 * out;

    final style = heading(
      _wordSize,
      weight: FontWeight.w700,
      tracking: -0.035,
      height: 1,
      color: TvColors.text,
    );
    final wordWidth = (TextPainter(
      text: TextSpan(
        children: [
          TextSpan(text: 'other', style: style),
          TextSpan(
            text: 'radio',
            style: style.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout()).width;
    // The glyph starts centred on screen, then glides left of the name.
    final glide = 1 - _iv(1.54, 2.38);
    final radioIn = _iv(2.1, 2.8);
    final tagIn = _iv(2.8, 3.5);

    Widget stage = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset((wordWidth + _logoGap) / 2 * glide, 0),
              child: _glyph(),
            ),
            const SizedBox(width: _logoGap),
            ClipRect(
              clipper: _Wipe(_iv(1.68, 2.52)),
              // The word keeps its final width while "radio" is still widely
              // tracked, so the logo stays centred through the reveal.
              child: SizedBox(
                width: wordWidth,
                height: _wordSize * 1.1,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: _word(style, radioIn),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Opacity(
          opacity: tagIn,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - tagIn)),
            child: Text(
              tagline.toUpperCase(),
              textAlign: TextAlign.center,
              style: tvBody(
                13,
                color: TvColors.text2,
              ).copyWith(letterSpacing: 13 * (0.5 - 0.18 * tagIn)),
            ),
          ),
        ),
        const SizedBox(height: 28),
        AnimatedOpacity(
          opacity: loader ? 1 : 0,
          duration: Duration(milliseconds: calm ? 0 : 300),
          child: _Loader(
            calm: calm,
            active: loader,
            loaded: loaded,
            message: message,
          ),
        ),
      ],
    );
    if (exit > 0) {
      stage = Opacity(
        opacity: 1 - out,
        child: calm
            ? stage
            : Transform.scale(
                scale: 1 + 0.14 * out,
                child: out > 0.01
                    ? ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 5 * out,
                          sigmaY: 5 * out,
                        ),
                        child: stage,
                      )
                    : stage,
              ),
      );
    }

    final letterbox =
        size.height *
        75 /
        540 *
        (1 - _iv(0.28, 0.98, const Cubic(0.65, 0, 0.35, 1)));
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 1 - backdrop,
            child: ColoredBox(color: background),
          ),
          Center(
            child: Opacity(
              opacity: (glowOpacity * (1 - out)).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: glowScale,
                child: const SizedBox(
                  width: 550,
                  height: 380,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Color(0x6B5EE6CF),
                          Color(0x242FBFA9),
                          Color(0x000A0E13),
                        ],
                        stops: [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (dust != null && exit < 1)
            Opacity(
              opacity: 1 - out,
              child: CustomPaint(painter: _Dust(dust!)),
            ),
          if (!calm) _horizon(size),
          Center(child: stage),
          Opacity(
            opacity: 1 - backdrop,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1,
                  colors: [Color(0x00000000), Color(0xD9000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
          ),
          if (letterbox > 0) ...[
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: letterbox,
              child: const ColoredBox(color: Colors.black),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: letterbox,
              child: const ColoredBox(color: Colors.black),
            ),
          ],
        ],
      ),
    );
  }

  /// A teal line draws out from the centre, then collapses into a point.
  Widget _horizon(Size size) {
    final double scale;
    if (seconds < 0.21 || seconds > 1.19) return const SizedBox.shrink();
    if (seconds < 0.63) {
      scale = _iv(0.21, 0.63);
    } else if (seconds < 1.05) {
      scale = 1 - 0.92 * _iv(0.63, 1.05);
    } else {
      scale = 0.08 * (1 - _iv(1.05, 1.19));
    }
    final opacity = 0.9 * math.min(1.0, _iv(0.21, 0.42, Curves.linear));
    return Center(
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scaleX: scale,
          child: Container(
            width: math.min(750, size.width * 0.8),
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0x005EE6CF), TvColors.accent, Color(0x005EE6CF)],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Five bars rise with a springy overshoot (90 ms stagger), three rings
  /// ripple out (220 ms apart), and while loading the bars dance.
  Widget _glyph() {
    const dance = [1.0, 0.55, 1.0, 0.7, 1.0, 0.6, 1.0, 0.8, 1.0];
    double barScale(int i) {
      final start = 0.7 + 0.09 * i;
      final t = seconds - start;
      if (t <= 0) return 0;
      double scale;
      if (t < 0.21) {
        scale = 1.25 * Curves.easeOut.transform(t / 0.21);
      } else if (t < 0.42) {
        scale = 1.25 - 0.37 * Curves.easeInOut.transform((t - 0.21) / 0.21);
      } else if (t < 0.56) {
        scale = 0.88 + 0.12 * Curves.easeOut.transform((t - 0.42) / 0.14);
      } else {
        scale = 1;
      }
      if (loop != null) {
        final phase = (loop! - 0.04 * i) % 1 * (dance.length - 1);
        final k = phase.floor();
        scale = ui.lerpDouble(
          dance[k],
          dance[k + 1],
          Curves.easeInOut.transform(phase - k),
        )!;
      }
      return scale;
    }

    final rings = [
      for (var j = 0; j < 3; j++)
        () {
          final start = 1.05 + 0.22 * j;
          final t = seconds - start;
          if (t <= 0 || t >= 1.47) return const SizedBox.shrink();
          final grow = TvMotion.outCurve.transform(t / 1.47);
          final opacity = t < 0.14 ? 0.75 * t / 0.14 : 0.75 * (1 - grow);
          return Center(
            child: OverflowBox(
              maxWidth: 400,
              maxHeight: 400,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.3 + 3.1 * grow,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: TvColors.accent),
                    ),
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
    return SizedBox(
      width: _bars.length * _barWidth + (_bars.length - 1) * _barGap,
      height: 75,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ...rings,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, height) in _bars.indexed)
                Opacity(
                  opacity: (seconds - 0.7 - 0.09 * i) <= 0
                      ? 0
                      : math.min(1.0, (seconds - 0.7 - 0.09 * i) / 0.21),
                  child: Transform.scale(
                    scaleY: barScale(i),
                    child: Container(
                      width: _barWidth,
                      height: height,
                      decoration: BoxDecoration(
                        color: TvColors.accent,
                        borderRadius: BorderRadius.circular(_barWidth / 2),
                        boxShadow: const [
                          BoxShadow(color: Color(0x995EE6CF), blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// `other` + `radio`; "radio" rises and its tracking tightens.
  Widget _word(TextStyle style, double radioIn) => _shine(
    Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('other', style: style),
        Opacity(
          opacity: radioIn,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - radioIn)),
            child: Text(
              'radio',
              style: style.copyWith(
                fontWeight: FontWeight.w400,
                color: TvColors.accent,
                letterSpacing: _wordSize * (0.18 - 0.215 * radioIn),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  /// A light sweep across the wordmark once it has settled.
  Widget _shine(Widget child) {
    if (seconds <= 2.66 || seconds >= 3.5) return child;
    final x = -1.2 + 2.4 * Curves.easeInOut.transform((seconds - 2.66) / 0.84);
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) => LinearGradient(
        colors: const [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0x00FFFFFF)],
        stops: const [0.4, 0.5, 0.6],
        transform: _Slide(x),
      ).createShader(bounds),
      child: child,
    );
  }
}

class _Loader extends StatelessWidget {
  const _Loader({
    required this.calm,
    required this.active,
    required this.loaded,
    required this.message,
  });
  final bool calm;
  final bool active;
  final bool loaded;
  final String message;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 180,
        height: 2,
        decoration: BoxDecoration(
          color: const Color(0x295EE6CF),
          borderRadius: BorderRadius.circular(1),
        ),
        alignment: Alignment.centerLeft,
        // The catalogue reports no progress: ease towards 85 % while it
        // loads, fill on completion.
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: 0,
            end: loaded
                ? 1
                : active
                ? (calm ? 0.6 : 0.85)
                : 0,
          ),
          duration: Duration(
            milliseconds: calm
                ? 0
                : loaded
                ? 250
                : 4000,
          ),
          curve: Curves.easeOutCubic,
          builder: (context, fill, _) => FractionallySizedBox(
            widthFactor: fill,
            heightFactor: 1,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: TvColors.accent,
                boxShadow: [BoxShadow(color: TvColors.accent, blurRadius: 6)],
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 9),
      Text(
        message,
        style: tvBody(
          11,
          color: loaded ? TvColors.accent : TvColors.muted,
          weight: FontWeight.w500,
        ),
      ),
    ],
  );
}

class _Wipe extends CustomClipper<Rect> {
  _Wipe(this.t);
  final double t;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(-20, -20, (size.width + 20) * t, size.height + 40);

  @override
  bool shouldReclip(_Wipe old) => old.t != t;
}

class _Slide extends GradientTransform {
  const _Slide(this.x);
  final double x;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * x, 0, 0);
}

/// Slow teal dust rising across the stage.
class _Dust extends CustomPainter {
  _Dust(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = TvColors.accent;
    for (var k = 0; k < 18; k++) {
      final x = ((k * 113) % 1880 + 20) / 1920 * size.width;
      final y = (320 + (k * 197) % 640) / 1080 * size.height;
      final radius = (1 + (k % 3)) / 2;
      final duration = 9 + (k * 7) % 9;
      final delay = (k * 1.7) % 9;
      final opacity = 0.25 + (k % 4) * 0.12;
      final p = ((t * 18 + delay) / duration) % 1;
      final fade = p < 0.2
          ? p / 0.2
          : p > 0.8
          ? (1 - p) / 0.2
          : 1.0;
      paint.color = TvColors.accent.withValues(alpha: opacity * fade);
      canvas.drawCircle(Offset(x, y - 110 * p), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_Dust old) => old.t != t;
}
