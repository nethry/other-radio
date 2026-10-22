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
import '../../core/ui/tv_input.dart';
import '../common.dart';
import 'player_screen.dart';

/// Persistent "Teraz gra" column on wide windows.
class NowPanel extends ConsumerWidget {
  const NowPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final state = ref.watch(playbackProvider).state;
    final station = state.station;
    final playing = state.phase == RadioPhase.playing;

    final top = <Widget>[
      Row(
        children: [
          Expanded(
            child: station == null
                ? const SectionLabel('Teraz gra')
                : LiveLabel(state: state, prefix: 'TERAZ GRA · '),
          ),
          if (station != null)
            IconBox(
              icon: Icons.open_in_full_rounded,
              tooltip: 'Pełny ekran',
              ghost: true,
              size: 36,
              iconSize: 18,
              radius: 10,
              onPressed: () => openPlayer(context),
            ),
        ],
      ),
      const SizedBox(height: 20),
      SizedBox(
        height: 250,
        child: Center(
          child: Aura(
            size: 200,
            orbitInset: 12,
            inset: 16,
            playing: playing,
            child: station == null
                ? Container(
                    decoration: BoxDecoration(
                      color: rc.hov,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      size: 56,
                      color: rc.mu,
                    ),
                  )
                : StationTile(
                    station: station,
                    width: double.infinity,
                    height: double.infinity,
                    circle: true,
                    shadow: true,
                    fontSize: 52,
                  ),
          ),
        ),
      ),
      const SizedBox(height: 20),
      if (station == null) ...[
        TrText('Wybierz stację', style: heading(24)),
        const SizedBox(height: 6),
        TrText(
          'Kliknij stację na liście, aby zacząć słuchać.',
          style: TextStyle(fontSize: 13, color: rc.mu, height: 1.5),
        ),
      ] else ...[
        Text(
          station.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: heading(24, height: 1.15),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle(station, language: context.languageCode),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: rc.mu),
        ),
        const SizedBox(height: 20),
        Group(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          children: [_PanelTrack(state: state)],
        ),
        const SizedBox(height: 20),
        const Center(
          child: PlayerControls(
            skipSize: 48,
            playSize: 68,
            playRadius: 24,
            playIcon: 28,
            gap: 16,
          ),
        ),
        const SizedBox(height: 12),
        const VolumeRow(height: 36),
      ],
    ];

    final hints = Wrap(
      spacing: 16,
      runSpacing: 8,
      children: TvInput.of(context)
          ? const [_Hint('↑ ↓ ← →', 'Nawigacja'), _Hint('OK', 'Wybierz')]
          : const [
              _Hint('Spacja', 'odtwórz / pauza'),
              _Hint('Ctrl →', 'następna'),
              _Hint('Ctrl ←', 'poprzednia'),
            ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: rc.panel,
        border: Border(left: BorderSide(color: rc.bd)),
      ),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, c.maxHeight - 48),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: top,
                ),
                if (station != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: hints,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelTrack extends ConsumerWidget {
  const _PanelTrack({required this.state});
  final RadioSnapshot state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final (title, artist) = trackInfo(state, context: context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: rc.mu),
        ),
        if (state.phase == RadioPhase.error) ...[
          const SizedBox(height: 8),
          TrText(
            state.error ?? 'Stacja jest niedostępna.',
            style: TextStyle(fontSize: 12, color: rc.dangerText, height: 1.4),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: ref.read(playbackProvider).retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const TrText('Spróbuj ponownie'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Viz(count: 28, height: 40, playing: state.phase == RadioPhase.playing),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.keys, this.label);
  final String keys;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Kbd(keys),
      const SizedBox(width: 6),
      TrText(label, style: TextStyle(fontSize: 12, color: context.rc.mu)),
    ],
  );
}
