import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/motion.dart';
import 'tv_overlays.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Opens the full-screen player. Back closes it and returns focus to the
/// control that opened it (card, mini-player or rail item); audio is
/// untouched by navigation.
Future<void> openTvPlayer(BuildContext context) async {
  final opener = FocusManager.instance.primaryFocus;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: TvMotion.of(context, TvMotion.player),
      reverseTransitionDuration: TvMotion.of(context, TvMotion.playerClose),
      pageBuilder: (_, _, _) => const TvPlayerScreen(),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: TvMotion.outCurve,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
  restoreTvFocus(opener);
}

class TvPlayerScreen extends ConsumerStatefulWidget {
  const TvPlayerScreen({super.key});

  @override
  ConsumerState<TvPlayerScreen> createState() => _TvPlayerScreenState();
}

class _TvPlayerScreenState extends ConsumerState<TvPlayerScreen> {
  static const _controls = [
    'Ulubione',
    'Poprzednia stacja',
    '',
    'Następna stacja',
  ];
  int _control = 2;

  /// Still connecting after 10 s: say so rather than spin silently. The audio
  /// handler's own watchdog turns a stuck stream into an error.
  bool _stalled = false;
  Timer? _stall;

  @override
  void initState() {
    super.initState();
    _watch(ref.read(playbackProvider).state.busy);
  }

  void _watch(bool busy) {
    if (busy) {
      _stall ??= Timer(const Duration(seconds: 10), () {
        if (mounted) setState(() => _stalled = true);
      });
    } else {
      _stall?.cancel();
      _stall = null;
      _stalled = false;
    }
  }

  @override
  void dispose() {
    _stall?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      playbackProvider.select((p) => p.state.busy),
      (_, busy) => setState(() => _watch(busy)),
    );
    final playback = ref.watch(playbackProvider);
    final state = playback.state;
    final station = state.station;
    final size = MediaQuery.sizeOf(context);
    if (station == null) {
      return Scaffold(
        backgroundColor: context.tv.bg,
        body: TvEmptyState(
          icon: Icons.radio_rounded,
          title: 'Wybierz stację',
          message: 'Kliknij stację na liście, aby zacząć słuchać.',
          actions: [
            TvButton(
              label: 'Wstecz',
              autofocus: true,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      );
    }
    final favorite = ref.watch(
      stationsProvider.select((c) => c.isFavorite(station)),
    );
    final status = tvStatus(state.phase);
    final palette = context.tv.tiles[paletteIndex(station.id)];
    final art = (size.height - 190).clamp(160.0, 280.0);
    final artLeft = size.width < 900 ? 56.0 : 80.0;
    final textLeft = artLeft + art + 50;
    final statusText = switch (status) {
      TvStatus.live => '${context.tr('Na żywo')} · ${formatLong(station)}',
      TvStatus.connecting =>
        _stalled ? 'Nadal łączę…' : 'Łączenie ze strumieniem…',
      TvStatus.paused => 'Pauza',
      TvStatus.error => 'Strumień niedostępny',
      TvStatus.idle => 'Gotowe do odtwarzania',
    };
    final (track, artist) = splitTrack(state.title);
    final playLabel = state.active ? 'Wstrzymaj' : 'Odtwórz';
    return Scaffold(
      backgroundColor: context.tv.bg,
      body: Semantics(
        label: context.tr('Teraz gra'),
        explicitChildNodes: true,
        child: Stack(
          children: [
            Positioned(
              left: -50,
              top: 20,
              width: 550,
              height: 450,
              child: _Glow(color: palette.fg, opacity: 0.22),
            ),
            Positioned(
              right: -50,
              bottom: -100,
              width: 350,
              height: 300,
              child: _Glow(color: context.tv.accentDeep, opacity: 0.16),
            ),
            Positioned(
              left: TvLayout.safeX,
              right: TvLayout.safeX,
              top: TvLayout.safeY,
              child: Row(
                children: [
                  const TvWordmark(),
                  const Spacer(),
                  const TvHint('WSTECZ', 'Powrót do przeglądania'),
                ],
              ),
            ),
            Positioned(
              left: artLeft,
              top: (size.height - art) / 2 + 10,
              width: art,
              height: art,
              child: _Halo(
                playing: status == TvStatus.live,
                child: Hero(
                  tag: tvArtHero,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: context.tv.dark ? 0.6 : 0.16,
                          ),
                          blurRadius: 50,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: TvArt(station: station, size: art, radius: 32),
                  ),
                ),
              ),
            ),
            Positioned(
              left: textLeft,
              right: TvLayout.safeX,
              top: 72,
              bottom: TvLayout.safeY,
              child: LayoutBuilder(
                builder: (context, box) => Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: box.maxWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TvStatusChip(phase: state.phase, text: statusText),
                          const SizedBox(height: 13),
                          Text(
                            station.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tvHeading(44),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle(station, language: context.languageCode),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tvBody(14, color: context.tv.text2),
                          ),
                          const SizedBox(height: 13),
                          _TrackPanel(
                            track: track,
                            artist: artist,
                            playing: status == TvStatus.live,
                            connecting: status == TvStatus.connecting,
                          ),
                          const SizedBox(height: 14),
                          if (status == TvStatus.error)
                            _ErrorActions(error: state.error)
                          else ...[
                            Row(
                              children: [
                                for (final (i, button) in [
                                  TvIconButton(
                                    icon: favorite
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    label: favorite
                                        ? 'Usuń z ulubionych'
                                        : 'Dodaj do ulubionych',
                                    on: favorite,
                                    onTap: () =>
                                        tvToggleFavorite(context, ref, station),
                                    onFocusChange: (f) => _focus(f, 0),
                                  ),
                                  TvIconButton(
                                    icon: Icons.skip_previous_rounded,
                                    label: 'Poprzednia stacja',
                                    onTap: playback.previous,
                                    onFocusChange: (f) => _focus(f, 1),
                                  ),
                                  TvIconButton(
                                    icon: state.active
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    label: playLabel,
                                    big: true,
                                    busy: state.busy,
                                    autofocus: true,
                                    onTap: () => state.phase == RadioPhase.idle
                                        ? playback.select(station)
                                        : playback.toggle(),
                                    onFocusChange: (f) => _focus(f, 2),
                                  ),
                                  TvIconButton(
                                    icon: Icons.skip_next_rounded,
                                    label: 'Następna stacja',
                                    onTap: playback.next,
                                    onFocusChange: (f) => _focus(f, 3),
                                  ),
                                ].indexed) ...[
                                  if (i > 0) const SizedBox(width: 18),
                                  button,
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 18,
                              child: Text(
                                context.tr(
                                  _control == 2
                                      ? playLabel
                                      : _controls[_control],
                                ),
                                style: tvBody(12, color: context.tv.text2),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _focus(bool focused, int index) {
    if (focused && _control != index) setState(() => _control = index);
  }
}

class _TrackPanel extends StatelessWidget {
  const _TrackPanel({
    required this.track,
    required this.artist,
    required this.playing,
    required this.connecting,
  });
  final String track;
  final String artist;
  final bool playing;
  final bool connecting;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: context.tv.surface.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: context.tv.outline),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (track.isNotEmpty) ...[
          Text(
            context.tr('Teraz w eterze').toUpperCase(),
            style: tvLabel(context.tv.muted),
          ),
          const SizedBox(height: 4),
          Text(
            track,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tvBody(17, weight: FontWeight.w700),
          ),
          if (artist.isNotEmpty)
            Text(
              artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tvBody(13, color: context.tv.muted),
            ),
        ] else ...[
          Text(
            context.tr('Brak informacji o utworze'),
            style: tvBody(14, weight: FontWeight.w700, color: context.tv.text2),
          ),
          const SizedBox(height: 2),
          Text(
            context.tr('Ta stacja nie przesyła tytułów — słuchasz na żywo.'),
            style: tvBody(11, color: context.tv.muted),
          ),
        ],
        const SizedBox(height: 10),
        Opacity(
          opacity: connecting ? 0.45 : 1,
          child: Viz(
            count: 40,
            height: 40,
            gap: 3,
            playing: playing,
            color: context.tv.accent,
          ),
        ),
      ],
    ),
  );
}

class _ErrorActions extends ConsumerWidget {
  const _ErrorActions({this.error});
  final String? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.read(playbackProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr(
            error ?? 'Nie udało się połączyć ze strumieniem. Stacja może być chwilowo niedostępna.',
          ),
          style: tvBody(13, color: context.tv.text2, height: 1.4),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TvButton(
              label: 'Spróbuj ponownie',
              icon: Icons.refresh_rounded,
              primary: true,
              autofocus: true,
              onTap: playback.retry,
            ),
            TvButton(
              label: 'Następna stacja',
              icon: Icons.skip_next_rounded,
              onTap: playback.next,
            ),
          ],
        ),
      ],
    );
  }
}

/// Soft radial glow (`.glow`).
class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.opacity});
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    ),
  );
}

/// Two rounded rings expanding from the artwork while live (2.6 s, offset by
/// half a cycle). Static under reduced motion.
class _Halo extends StatefulWidget {
  const _Halo({required this.playing, required this.child});
  final bool playing;
  final Widget child;

  @override
  State<_Halo> createState() => _HaloState();
}

class _HaloState extends State<_Halo> with SingleTickerProviderStateMixin {
  late final _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  void _sync() {
    final go = widget.playing && !context.calm;
    if (go && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!go && _loop.isAnimating) {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Halo oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _loop,
    builder: (context, child) {
      Widget ring(double offset) {
        final t = (_loop.value + offset) % 1;
        final e = const Cubic(0.2, 0.6, 0.3, 1).transform(t);
        return Positioned.fill(
          child: Transform.scale(
            scale: 0.96 + 0.22 * e,
            child: Opacity(
              opacity: 0.6 * (1 - e),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: context.tv.accent, width: 1.5),
                ),
              ),
            ),
          ),
        );
      }

      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (_loop.isAnimating) ...[ring(0), ring(0.5)],
          Positioned.fill(child: child!),
        ],
      );
    },
    child: widget.child,
  );
}
