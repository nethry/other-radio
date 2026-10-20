import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Drives a repeating animation only while [running] and motion is allowed.
mixin _Looping<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  late final AnimationController loop = AnimationController(
    vsync: this,
    duration: loopDuration,
  );
  Duration get loopDuration;
  bool get running;

  void syncLoop() {
    final go = running && !context.calm;
    if (go && !loop.isAnimating) {
      loop.repeat();
    } else if (!go && loop.isAnimating) {
      loop.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncLoop();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncLoop();
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// Small equalizer (`.eq`): bars scale 0.3→1 with offset phases.
class Eq extends StatefulWidget {
  const Eq({
    super.key,
    this.bars = 3,
    this.playing = true,
    this.color,
    this.height = 14,
  });
  final int bars;
  final bool playing;
  final Color? color;
  final double height;

  @override
  State<Eq> createState() => _EqState();
}

class _EqState extends State<Eq> with TickerProviderStateMixin, _Looping {
  static const _durations = [0.9, 0.8, 1.05, 0.95];
  static const _delays = [0.0, -0.3, -0.6, -0.15];

  @override
  Duration get loopDuration => const Duration(seconds: 63);
  @override
  bool get running => widget.playing;

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color!;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            final seconds = loop.value * 63;
            final animate = loop.isAnimating || loop.value > 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < widget.bars; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                    child: Container(
                      width: 3,
                      height:
                          widget.height *
                          (animate
                              ? _scale(seconds, i)
                              : [0.55, 0.9, 0.4, 0.7][i % 4]),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _scale(double seconds, int i) {
    final d = _durations[i % 4];
    final phase = ((seconds - _delays[i % 4]) % d) / d;
    final eased = Curves.easeInOut.transform(
      phase < 0.5 ? phase * 2 : (1 - phase) * 2,
    );
    return 0.3 + 0.7 * eased;
  }
}

/// Pulsing live dot (`.live`).
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.size = 7, this.active = true, this.color});
  final double size;
  final bool active;
  final Color? color;
  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot>
    with TickerProviderStateMixin, _Looping {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1600);
  @override
  bool get running => widget.active;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: loop,
    builder: (context, _) {
      final t = loop.value;
      final opacity =
          1 - 0.65 * Curves.easeInOut.transform(t < 0.5 ? t * 2 : (1 - t) * 2);
      return Opacity(
        opacity: opacity,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color ?? context.rc.ac,
            shape: BoxShape.circle,
          ),
        ),
      );
    },
  );
}

/// Simulated spectrum (`.viz`). HLS/ICY streams expose no FFT, so bar heights
/// are synthetic and only suggest activity.
class Viz extends StatefulWidget {
  const Viz({
    super.key,
    this.count = 32,
    this.height = 48,
    this.gap = 3,
    this.playing = true,
  });
  final int count;
  final double height;
  final double gap;
  final bool playing;
  @override
  State<Viz> createState() => _VizState();
}

class _VizState extends State<Viz> with TickerProviderStateMixin, _Looping {
  @override
  Duration get loopDuration => const Duration(seconds: 60);
  @override
  bool get running => widget.playing;

  @override
  Widget build(BuildContext context) {
    final color = context.rc.ac;
    return ExcludeSemantics(
      child: SizedBox(
        height: widget.height,
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, _) {
            final seconds = loop.value * 60;
            return Row(
              children: [
                for (var k = 0; k < widget.count; k++) ...[
                  if (k > 0) SizedBox(width: widget.gap),
                  Expanded(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: _height(k, seconds),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: widget.playing
                                ? color
                                : color.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  double _height(int k, double seconds) {
    final peak = (30 + (k * 29) % 70) / 100;
    if (!widget.playing || context.calm) return peak * 0.45;
    final duration = 0.55 + ((k * 37) % 23) / 30;
    final delay = ((k * 53) % 17) / 17;
    // Alternate between 12% and 100% of the bar's peak, like the CSS keyframes.
    final cycle = ((seconds + delay) / duration) % 2;
    final t = cycle < 1 ? cycle : 2 - cycle;
    return peak * (0.12 + 0.88 * Curves.easeInOut.transform(t));
  }
}

/// List entrance: fade + 12 px rise, staggered 45 ms per item.
class Rise extends StatefulWidget {
  const Rise({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;
  @override
  State<Rise> createState() => _RiseState();
}

class _RiseState extends State<Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: const Cubic(0.2, 0.7, 0.3, 1),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.calm || widget.index > 14) {
      _c.value = 1;
    } else {
      Future<void>.delayed(Duration(milliseconds: 45 * widget.index), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _t,
    builder: (context, child) => Opacity(
      opacity: _t.value,
      child: Transform.translate(
        offset: Offset(0, 12 * (1 - _t.value)),
        child: child,
      ),
    ),
    child: widget.child,
  );
}

/// Loading skeleton block.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, this.width, required this.height, this.radius = 8});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with TickerProviderStateMixin, _Looping {
  @override
  Duration get loopDuration => const Duration(milliseconds: 1400);
  @override
  bool get running => true;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              colors: [rc.hov, rc.bd, rc.hov],
              begin: Alignment(-3 + 4 * (1 - loop.value), 0),
              end: Alignment(-1 + 4 * (1 - loop.value), 0),
            ),
          ),
        ),
      ),
    );
  }
}

/// Halo rings, rotating orbit and breathing artwork around [child].
class Aura extends StatefulWidget {
  const Aura({
    super.key,
    required this.size,
    required this.child,
    this.playing = true,
    this.inset,
    this.orbitInset,
  });

  /// Outer diameter of the halo box.
  final double size;
  final Widget child;
  final bool playing;

  /// Gap between the halo box and the artwork (default 7.5% of [size]).
  final double? inset;

  /// How far the orbit ring sits outside the halo box.
  final double? orbitInset;
  @override
  State<Aura> createState() => _AuraState();
}

class _AuraState extends State<Aura> with TickerProviderStateMixin, _Looping {
  // One 14.4 s master clock: 6 halo cycles (2.4 s), 3 breaths (4.8 s).
  // The orbit uses its own 18 s rotation below.
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  Duration get loopDuration => const Duration(milliseconds: 14400);
  @override
  bool get running => widget.playing;

  @override
  void syncLoop() {
    super.syncLoop();
    final go = running && !context.calm;
    if (go && !_orbit.isAnimating) {
      _orbit.repeat();
    } else if (!go && _orbit.isAnimating) {
      _orbit.stop();
    }
  }

  @override
  void dispose() {
    _orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final size = widget.size;
    final inset = widget.inset ?? size * 0.075;
    final orbitInset = widget.orbitInset ?? size * 0.06;
    return ExcludeSemantics(
      excluding: false,
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: Listenable.merge([loop, _orbit]),
          builder: (context, child) {
            final ms = loop.value * 14400;
            final still = !loop.isAnimating && loop.value == 0;
            Widget halo(double offsetMs) {
              final t = ((ms + offsetMs) % 2400) / 2400;
              final e = const Cubic(0.2, 0.6, 0.3, 1).transform(t);
              return Transform.scale(
                scale: still ? 1.0 : 0.82 + 0.5 * e,
                child: Opacity(
                  opacity: still ? 0.25 : 0.75 * (1 - e),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: rc.ac, width: 1.5),
                    ),
                  ),
                ),
              );
            }

            final breath = still
                ? 1.0
                : 1 +
                      0.025 *
                          Curves.easeInOut.transform(
                            1 - ((ms % 4800) / 2400 - 1).abs(),
                          );
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(child: halo(0)),
                if (!still) Positioned.fill(child: halo(1200)),
                Positioned.fill(
                  left: -orbitInset,
                  top: -orbitInset,
                  right: -orbitInset,
                  bottom: -orbitInset,
                  child: Transform.rotate(
                    angle: _orbit.value * 2 * math.pi,
                    child: CustomPaint(painter: _OrbitPainter(rc.orbit, rc.ac)),
                  ),
                ),
                Positioned.fill(
                  left: inset,
                  top: inset,
                  right: inset,
                  bottom: inset,
                  child: Transform.scale(scale: breath, child: child),
                ),
              ],
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.ring, this.dot);
  final Color ring;
  final Color dot;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final circumference = 2 * math.pi * radius;
    final dashes = (circumference / 9).floor();
    final sweep = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
    canvas.drawCircle(
      Offset(center.dx, center.dy - radius),
      4.5,
      Paint()..color = dot,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.ring != ring || old.dot != dot;
}

/// Soft accent glow behind hero content (`.glow`).
class Glow extends StatelessWidget {
  const Glow({super.key});
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              rc.ac.withValues(alpha: rc.glowOpacity * 1.6),
              rc.ac.withValues(alpha: rc.glowOpacity * 0.6),
              rc.ac.withValues(alpha: 0),
            ],
            stops: const [0, 0.4, 1],
          ),
        ),
      ),
    );
  }
}
