import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/motion.dart';
import '../../data/models/history_entry.dart';
import '../stations/station_controller.dart';
import 'tv_focusable.dart';
import 'tv_overlays.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// History grouped by day. OK resumes a station; → reaches its favourite
/// toggle (one level deep only). The playing row is marked separately from
/// focus.
class TvHistory extends ConsumerWidget {
  const TvHistory({super.key});

  /// Remote lists stay short; the full history remains on phone/desktop.
  static const _limit = 50;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final language = context.languageCode;
    final groups = <({String label, List<HistoryEntry> entries})>[];
    var count = 0;
    for (final group in history.groupsFor(language)) {
      if (count >= _limit) break;
      final entries = group.entries.take(_limit - count).toList();
      count += entries.length;
      groups.add((label: group.label, entries: entries));
    }
    final queue = [for (final g in groups) ...g.entries.map((e) => e.station)];
    return TvPageFrame(
      title: 'Historia',
      subtitle: 'Ostatnio słuchane stacje — zapisane tylko na tym urządzeniu',
      actions: [
        if (history.entries.isNotEmpty)
          TvChip(
            label: 'Wyczyść historię',
            icon: Icons.delete_outline_rounded,
            onTap: () async {
              final clear = await confirmTv(
                context,
                title: 'Wyczyścić historię?',
                message: context.tr(
                  'Lista ostatnio słuchanych stacji zostanie usunięta z tego urządzenia.',
                ),
                confirm: 'Wyczyść',
              );
              if (clear) await ref.read(historyProvider).clear();
            },
          ),
      ],
      child: groups.isEmpty
          ? TvEmptyState(
              icon: Icons.history_rounded,
              title: 'Historia jest pusta',
              message: 'Stacje, których posłuchasz, pojawią się tutaj.',
              actions: [
                TvButton(
                  label: 'Odkrywaj stacje',
                  icon: Icons.explore_outlined,
                  primary: true,
                  autofocus: true,
                  onTap: () =>
                      ref.read(stationsProvider).navigate(AppPage.browse),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                TvLayout.ringInset,
                4,
                TvLayout.safeX,
                TvLayout.safeY + 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 0, 4),
                      child: Text(
                        group.label.toUpperCase(),
                        style: tvLabel(context.tv.muted),
                      ),
                    ),
                    for (final entry in group.entries)
                      _HistoryRow(
                        entry: entry,
                        autofocus: identical(entry, groups.first.entries.first),
                        onTap: () => tvActivate(
                          context,
                          ref,
                          entry.station,
                          queue: queue,
                          source: 'Historii',
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _HistoryRow extends ConsumerWidget {
  const _HistoryRow({
    required this.entry,
    required this.autofocus,
    required this.onTap,
  });
  final HistoryEntry entry;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final station = entry.station;
    final open = history.isOpen(entry);
    final favorite = ref.watch(
      stationsProvider.select((c) => c.isFavorite(station)),
    );
    final language = context.languageCode;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: TvFocusable(
              autofocus: autofocus,
              onTap: onTap,
              onLongPress: () => showTvStationDetails(context, station),
              semanticLabel: open
                  ? '${station.name}, ${context.tr('słuchasz teraz')}'
                  : 'Odtwórz ponownie ${station.name}',
              builder: (context, focused, pressed) => TvScale(
                focused: focused,
                pressed: pressed,
                scale: 1.02,
                pressedScale: 0.99,
                child: AnimatedContainer(
                  duration: TvMotion.of(context, TvMotion.focus),
                  constraints: const BoxConstraints(minHeight: 60),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: focused ? context.tv.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: focused
                        ? [BoxShadow(color: context.tv.accent, spreadRadius: 2)]
                        : const [],
                  ),
                  child: Row(
                    children: [
                      TvArt(station: station, size: 44, radius: 11),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tvBody(
                                15,
                                weight: FontWeight.w700,
                                color: focused
                                    ? context.tv.text
                                    : context.tv.text2,
                              ),
                            ),
                            Text(
                              subtitle(station, language: language),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tvBody(10, color: context.tv.muted),
                            ),
                          ],
                        ),
                      ),
                      if (open) ...[
                        const SizedBox(width: 12),
                        Container(
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 9),
                          decoration: BoxDecoration(
                            color: context.tv.accentSoft,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Eq(color: context.tv.accent, height: 9),
                              const SizedBox(width: 6),
                              Text(
                                context.tr('słuchasz teraz').toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.9,
                                  color: context.tv.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 14),
                      SizedBox(
                        width: 48,
                        child: Text(
                          clock(entry.start),
                          textAlign: TextAlign.right,
                          style: monoStyle(11, color: context.tv.muted),
                        ),
                      ),
                      SizedBox(
                        width: 100,
                        child: Text(
                          context.tr(listenDuration(history.listened(entry))),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: tvBody(11, color: context.tv.muted),
                        ),
                      ),
                      if (focused) ...[
                        const SizedBox(width: 14),
                        Container(
                          height: 30,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: context.tv.accent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow_rounded,
                                size: 14,
                                color: context.tv.onAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.tr('Wznów'),
                                style: tvBody(
                                  11,
                                  weight: FontWeight.w700,
                                  color: context.tv.onAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          TvIconButton(
            icon: favorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
            on: favorite,
            size: 36,
            onTap: () => tvToggleFavorite(context, ref, station),
          ),
        ],
      ),
    );
  }
}
