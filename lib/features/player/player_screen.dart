import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import '../common.dart';
import '../stations/station_details_screen.dart';

void openPlayer(BuildContext context) {
  final calm = context.calm;
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: calm
          ? Duration.zero
          : const Duration(milliseconds: 420),
      reverseTransitionDuration: calm
          ? Duration.zero
          : const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// `(title, artist line)` for the current ICY metadata.
(String, String) trackInfo(RadioSnapshot state, {BuildContext? context}) {
  String tr(String value) => context?.tr(value) ?? value;
  final (title, artist) = splitTrack(state.title);
  if (title.isEmpty) {
    return (
      tr('Brak informacji o utworze'),
      tr('Stacja nie nadaje metadanych'),
    );
  }
  return (
    title,
    artist.isEmpty
        ? tr('z metadanych strumienia')
        : '$artist · ${tr('z metadanych strumienia')}',
  );
}

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final player = ref.watch(playbackProvider);
    final station = player.state.station;
    if (station == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).pop();
        }
      });
      return Scaffold(backgroundColor: rc.bg);
    }
    return Scaffold(
      backgroundColor: rc.bg,
      body: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 900
            ? _MobilePlayer(station: station)
            : _DesktopPlayer(station: station),
      ),
    );
  }
}

class _MobilePlayer extends ConsumerWidget {
  const _MobilePlayer({required this.station});
  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final player = ref.watch(playbackProvider);
    final state = player.state;
    final playing = state.phase == RadioPhase.playing;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, c) {
          final art = math.min(
            (c.maxHeight * 0.3).clamp(140.0, 236.0),
            c.maxWidth - 96,
          );
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: math.max(0, c.maxHeight - 36),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconBox(
                        icon: Icons.keyboard_arrow_down_rounded,
                        tooltip: 'Zamknij odtwarzacz',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            TrText(
                              'ODTWARZANE Z',
                              style: labelStyle(context)
                                  .copyWith(letterSpacing: 11 * 0.14),
                            ),
                            const SizedBox(height: 2),
                            TrText(
                              player.source,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconBox(
                        icon: Icons.info_outline_rounded,
                        tooltip: 'Informacje o stacji',
                        onPressed: () => openStation(context, station),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: art + 54,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        const Positioned(
                          left: -80,
                          right: -80,
                          top: -40,
                          bottom: -60,
                          child: Glow(),
                        ),
                        Aura(
                          size: art,
                          playing: playing,
                          child: Hero(
                            tag: 'art-${station.id}',
                            child: StationTile(
                              station: station,
                              width: double.infinity,
                              height: double.infinity,
                              circle: true,
                              caption: 'RADIO',
                              shadow: true,
                              fontSize: 64 * art / 236,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: heading(28, height: 1.1),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle(station, language: context.languageCode),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: rc.mu),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      HeartButton(station: station, ghost: false, round: true),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Group(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    children: [
                      _TrackCard(station: station, vizCount: 32, vizHeight: 48),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Center(child: PlayerControls()),
                  const SizedBox(height: 12),
                  const VolumeRow(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DesktopPlayer extends ConsumerWidget {
  const _DesktopPlayer({required this.station});
  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final state = ref.watch(playbackProvider).state;
    final playing = state.phase == RadioPhase.playing;
    final tags = station.genres.take(3).join(' · ');
    return Stack(
      children: [
        const Positioned(
          left: -120,
          top: 60,
          width: 720,
          height: 720,
          child: Glow(),
        ),
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 12),
                child: Row(
                  children: [
                    PillButton(
                      label: 'Biblioteka',
                      icon: Icons.chevron_left_rounded,
                      tone: ButtonTone.secondary,
                      height: 40,
                      radius: 999,
                      fontSize: 13,
                      padding: 16,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Center(child: LiveLabel(state: state, size: 12)),
                    ),
                    IconBox(
                      icon: Icons.info_outline_rounded,
                      tooltip: 'Informacje o stacji',
                      onPressed: () => openStation(context, station),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final available = c.maxWidth - 96;
                    final columnWidth = math.min(620.0, available);
                    final art = math.min(360.0, available);
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(48, 24, 48, 48),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, c.maxHeight - 72),
                        ),
                        child: Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 64,
                            runSpacing: 40,
                            children: [
                              Padding(
                                padding: EdgeInsets.all(art * 0.07),
                                child: Aura(
                                  size: art,
                                  playing: playing,
                                  child: Hero(
                                    tag: 'art-${station.id}',
                                    child: StationTile(
                                      station: station,
                                      width: double.infinity,
                                      height: double.infinity,
                                      circle: true,
                                      caption: 'RADIO',
                                      shadow: true,
                                      fontSize: 96 * art / 360,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: columnWidth,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      station.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: heading(
                                        56,
                                        tracking: -0.04,
                                        height: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      [
                                        place(station),
                                        stationCountryLabel(context, station),
                                        if (tags.isNotEmpty) tags,
                                      ].join(' · '),
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: rc.mu,
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Group(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        18,
                                        20,
                                        18,
                                      ),
                                      children: [
                                        _TrackCard(
                                          station: station,
                                          vizCount: 48,
                                          vizHeight: 72,
                                          vizGap: 4,
                                          large: true,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    const Row(
                                      children: [
                                        PlayerControls(
                                          playSize: 84,
                                          playRadius: 30,
                                          playIcon: 34,
                                          gap: 16,
                                        ),
                                        SizedBox(width: 24),
                                        Expanded(child: VolumeRow(height: 40)),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    _FactsGrid(station: station),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Live status, track metadata, error recovery and the visualizer.
class _TrackCard extends ConsumerWidget {
  const _TrackCard({
    required this.station,
    required this.vizCount,
    required this.vizHeight,
    this.vizGap = 3,
    this.large = false,
  });
  final Station station;
  final int vizCount;
  final double vizHeight;
  final double vizGap;
  final bool large;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final player = ref.watch(playbackProvider);
    final state = player.state;
    final (title, artist) = trackInfo(state, context: context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: LiveLabel(state: state)),
            const SizedBox(width: 12),
            Text(formatLong(station), style: monoStyle(11, color: rc.mu)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: large ? 18 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: large ? 14 : 13, color: rc.mu),
                  ),
                ],
              ),
            ),
            if (large) ...[
              const SizedBox(width: 12),
              HeartButton(station: station, ghost: false, round: true),
            ],
          ],
        ),
        if (state.phase == RadioPhase.error) ...[
          const SizedBox(height: 10),
          TrText(
            state.error ?? 'Stacja jest niedostępna.',
            style: TextStyle(color: rc.dangerText, fontSize: 13, height: 1.4),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: player.retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const TrText('Spróbuj ponownie'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Viz(
          count: vizCount,
          height: vizHeight,
          gap: vizGap,
          playing: state.phase == RadioPhase.playing,
        ),
      ],
    );
  }
}

class _FactsGrid extends StatelessWidget {
  const _FactsGrid({required this.station});
  final Station station;

  @override
  Widget build(BuildContext context) {
    final homepage = station.homepageUri;
    final facts = [
      ('Kodek', codecLabel(station), true, null),
      ('Bitrate', bitrateLabel(station), true, null),
      ('Strumień', streamLabel(station), false, null),
      ('Kraj', stationCountryLabel(context, station), false, null),
      ('Język', languageLabel(station), false, null),
      (
        'Strona',
        homepage == null ? 'brak' : '${homepage.host} ↗',
        false,
        homepage == null ? null : () => openLink(context, homepage),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 480 ? 3 : 2;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (i, f) in facts.indexed)
              SizedBox(
                width: width,
                child: Rise(
                  index: i,
                  child: _FactBox(
                    label: f.$1,
                    value: f.$2,
                    mono: f.$3,
                    onTap: f.$4,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FactBox extends StatelessWidget {
  const _FactBox({
    required this.label,
    required this.value,
    required this.mono,
    this.onTap,
  });
  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tappable(
      onTap: onTap,
      pressScale: 0.98,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: rc.sf,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rc.bd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(label).toUpperCase(),
              style: labelStyle(context, size: 10),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono
                  ? monoStyle(14, color: rc.tx)
                  : TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: onTap != null ? rc.act : rc.tx,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Previous / play-pause / next. Skipping needs a queue of two or more.
class PlayerControls extends ConsumerWidget {
  const PlayerControls({
    super.key,
    this.skipSize = 56,
    this.playSize = 80,
    this.playRadius = 28,
    this.playIcon = 32,
    this.gap = 20,
  });
  final double skipSize;
  final double playSize;
  final double playRadius;
  final double playIcon;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playbackProvider);
    final state = player.state;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBox(
          icon: Icons.skip_previous_rounded,
          tooltip: 'Poprzednia stacja',
          round: true,
          size: skipSize,
          iconSize: skipSize * 0.43,
          onPressed: player.canSkip ? player.previous : null,
        ),
        SizedBox(width: gap),
        PlayButton(
          playing: state.active,
          busy: state.busy,
          size: playSize,
          radius: playRadius,
          iconSize: playIcon,
          onPressed: state.station == null ? null : player.toggle,
        ),
        SizedBox(width: gap),
        IconBox(
          icon: Icons.skip_next_rounded,
          tooltip: 'Następna stacja',
          round: true,
          size: skipSize,
          iconSize: skipSize * 0.43,
          onPressed: player.canSkip ? player.next : null,
        ),
      ],
    );
  }
}

/// Volume slider with a numeric readout.
class VolumeRow extends ConsumerWidget {
  const VolumeRow({super.key, this.height = 44});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final player = ref.watch(playbackProvider);
    final volume = player.state.volume;
    return Row(
      children: [
        Icon(Icons.volume_up_rounded, size: 20, color: rc.mu),
        Expanded(
          child: SizedBox(
            height: height,
            child: Slider(
              value: volume,
              onChanged: player.volume,
              semanticFormatterCallback: (v) =>
                  context.tr('Głośność ${(v * 100).round()} procent'),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          child: Text(
            '${(volume * 100).round()}',
            textAlign: TextAlign.right,
            style: monoStyle(12, color: rc.mu),
          ),
        ),
      ],
    );
  }
}
