import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../common.dart';
import 'player_screen.dart';

/// Floating card above the tab bar, or [docked] under the content on
/// mid-width windows (adds previous/next).
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, this.docked = false});
  final bool docked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playbackProvider);
    final state = player.state;
    final station = state.station;
    if (station == null) return const SizedBox.shrink();
    final rc = context.rc;
    final error = state.phase == RadioPhase.error;
    final (title, artist) = splitTrack(state.title);
    final line = error
        ? context.tr(state.error ?? 'Stacja jest niedostępna.')
        : title.isEmpty
        ? context.tr('Brak informacji o utworze')
        : artist.isEmpty
        ? title
        : '$artist — $title';

    final card = Container(
      constraints: const BoxConstraints(minHeight: 76),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rc.sf2,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: rc.bd2),
        boxShadow: docked ? null : rc.shadow,
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 2,
            child: ColoredBox(color: rc.ac.withValues(alpha: 0.55)),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Tappable(
                    onTap: () => openPlayer(context),
                    pressScale: 0.98,
                    borderRadius: BorderRadius.circular(16),
                    semanticLabel: 'Otwórz odtwarzacz',
                    child: Row(
                      children: [
                        Hero(
                          tag: 'art-${station.id}',
                          child: StationTile(
                            station: station,
                            width: 52,
                            radius: 14,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LiveLabel(state: state),
                              const SizedBox(height: 2),
                              Text(
                                station.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                line,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: error ? rc.dangerText : rc.mu,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (docked) ...[
                  IconBox(
                    icon: Icons.skip_previous_rounded,
                    tooltip: 'Poprzednia stacja',
                    ghost: true,
                    round: true,
                    color: rc.tx,
                    onPressed: player.canSkip ? player.previous : null,
                  ),
                  const SizedBox(width: 4),
                ],
                PlayButton(
                  playing: state.active,
                  busy: state.busy,
                  size: 52,
                  radius: 16,
                  iconSize: 22,
                  glow: false,
                  onPressed: player.toggle,
                ),
                if (docked) ...[
                  const SizedBox(width: 4),
                  IconBox(
                    icon: Icons.skip_next_rounded,
                    tooltip: 'Następna stacja',
                    ghost: true,
                    round: true,
                    color: rc.tx,
                    onPressed: player.canSkip ? player.next : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (!docked) return card;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: card,
      ),
    );
  }
}
