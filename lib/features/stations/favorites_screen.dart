import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/ui/tv_input.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import '../common.dart';
import 'station_controller.dart';

const _sortOptions = <SegmentOption<FavoriteSort>>[
  (value: FavoriteSort.own, label: 'Moja kolejność', icon: null),
  (value: FavoriteSort.az, label: 'A–Z', icon: null),
  (value: FavoriteSort.recent, label: 'Ostatnio', icon: null),
];

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});
  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool editing = false;

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    final lastPlayed = ref.watch(historyProvider).lastPlayed;
    final favorites = catalogue.sortedFavorites(lastPlayed);
    final rc = context.rc;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final top = wide ? 32.0 : MediaQuery.paddingOf(context).top + 16;
        final side = wide ? 32.0 : 20.0;
        final bottom = ShellInsets.bottomOf(context) + (wide ? 32 : 24);
        final editChip = RadioChip(
          label: editing ? 'Gotowe' : 'Edytuj',
          small: true,
          selected: editing,
          onTap: favorites.isEmpty && !editing
              ? null
              : () => setState(() => editing = !editing),
        );
        final count = stationCount(
          favorites.length,
          language: Localizations.localeOf(context).languageCode,
        );
        final header = wide
            ? Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: TrText(
                          'Ulubione',
                          style: heading(40, tracking: -0.035, height: 1.05),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '$count · ',
                            style: TextStyle(fontSize: 14, color: rc.mu),
                          ),
                          const Kbd('Ctrl 1–9'),
                          TrText(
                            ' szybki wybór',
                            style: TextStyle(fontSize: 14, color: rc.mu),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: SizedBox(
                          width: 320,
                          child: Segmented<FavoriteSort>(
                            semanticLabel: 'Sortowanie',
                            options: _sortOptions,
                            selected: catalogue.favoriteSort,
                            onChanged: catalogue.sortFavorites,
                          ),
                        ),
                      ),
                      editChip,
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Semantics(
                              header: true,
                              child: TrText(
                                'Ulubione',
                                style: heading(30, height: 1.1),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$count · ${context.tr('zapisane na tym urządzeniu')}',
                              style: TextStyle(fontSize: 13, color: rc.mu),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      editChip,
                    ],
                  ),
                  const SizedBox(height: 20),
                  Segmented<FavoriteSort>(
                    semanticLabel: 'Sortowanie',
                    options: _sortOptions,
                    selected: catalogue.favoriteSort,
                    onChanged: catalogue.sortFavorites,
                  ),
                ],
              );

        final slivers = <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, top, side, 0),
            sliver: SliverToBoxAdapter(child: header),
          ),
        ];

        if (favorites.isEmpty) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 24, side, bottom),
              sliver: SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'Twoje ulubione czekają na odkrycie',
                  message: 'Naciśnij serce przy stacji, aby zapisać ją tutaj.',
                  action: PillButton(
                    label: 'Przeglądaj stacje',
                    onPressed: () => catalogue.navigate(AppPage.browse),
                  ),
                ),
              ),
            ),
          );
        } else if (editing) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 20, side, 0),
              sliver: _EditList(favorites: catalogue.favorites),
            ),
          );
        } else if (wide) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 24, side, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 230,
                  mainAxisExtent: _FavoriteCard.extent(context, compact: false),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => i == favorites.length
                      ? Rise(index: i, child: const _AddTile())
                      : Rise(
                          index: i,
                          child: _FavoriteCard(
                            station: favorites[i],
                            queue: favorites,
                            number: i < 9 ? i + 1 : null,
                            tileHeight: 140,
                          ),
                        ),
                  childCount: favorites.length + 1,
                ),
              ),
            ),
          );
        } else {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 20, side, 0),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: constraints.maxWidth < 340 ? 1 : 2,
                  mainAxisExtent: _FavoriteCard.extent(context, compact: true),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => Rise(
                    index: i,
                    child: _FavoriteCard(
                      station: favorites[i],
                      queue: favorites,
                      tileHeight: 118,
                      compact: true,
                    ),
                  ),
                  childCount: favorites.length,
                ),
              ),
            ),
          );
        }

        if (favorites.isNotEmpty && (!wide || editing)) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(side, 20, side, 0),
              sliver: const SliverToBoxAdapter(child: _Hint()),
            ),
          );
        }
        slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottom)));
        return CustomScrollView(slivers: slivers);
      },
    );
  }
}

class _FavoriteCard extends ConsumerWidget {
  const _FavoriteCard({
    required this.station,
    required this.queue,
    required this.tileHeight,
    this.number,
    this.compact = false,
  });
  final Station station;
  final List<Station> queue;
  final double tileHeight;
  final int? number;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider).state;
    final playing = isPlaying(state, station);
    final rc = context.rc;
    return HoverCard(
      selected: playing,
      padding: EdgeInsets.all(compact ? 10 : 12),
      radius: 22,
      semanticLabel: 'Odtwórz ${station.name}',
      onTap: () => playFrom(ref, station, queue: queue, source: 'Ulubionych'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StationTile(
            station: station,
            width: double.infinity,
            height: tileHeight,
            radius: 16,
            fontSize: compact ? 30 : 36,
            overlay: [
              if (number != null)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rc.sf,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('$number', style: monoStyle(11, color: rc.tx2)),
                  ),
                ),
              if (playing)
                Positioned(
                  left: compact ? 12 : null,
                  right: compact ? null : 12,
                  bottom: 12,
                  child: Eq(
                    bars: compact ? 3 : 4,
                    playing: state.phase == RadioPhase.playing,
                    color: rc.tiles[paletteIndex(station.id)].fg,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 10 : 12),
          Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 14 : 15,
              height: 1.3,
              color: playing ? rc.act : rc.tx,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            compact
                ? tagLine(station, language: context.languageCode)
                : subtitle(station, language: context.languageCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.3, color: rc.mu),
          ),
        ],
      ),
    );
  }

  /// Grid cell height: padding, border, tile, gap and two text lines.
  static double extent(BuildContext context, {required bool compact}) {
    final ts = MediaQuery.textScalerOf(context);
    final padding = compact ? 10.0 : 12.0;
    final tile = compact ? 118.0 : 140.0;
    return (padding * 2 +
            2 +
            tile +
            (compact ? 10 : 12) +
            ts.scale(compact ? 14 : 15) * 1.3 +
            2 +
            ts.scale(12) * 1.3 +
            2)
        .ceilToDouble();
  }
}

class _EditList extends ConsumerWidget {
  const _EditList({required this.favorites});
  final List<Station> favorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.read(stationsProvider);
    final rc = context.rc;
    return SliverReorderableList(
      itemCount: favorites.length,
      // onReorderItem already adjusts `to` for the removed item.
      onReorderItem: catalogue.reorderFavorite,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 0,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: rc.shadow,
          ),
          child: child,
        ),
      ),
      itemBuilder: (context, i) {
        final station = favorites[i];
        return Padding(
          key: ValueKey(station.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            decoration: BoxDecoration(
              color: rc.sf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: rc.bd),
            ),
            child: Row(
              children: [
                Tooltip(
                  message: context.tr('Usuń ${station.name} z ulubionych'),
                  child: Semantics(
                    button: true,
                    label: context.tr('Usuń ${station.name} z ulubionych'),
                    excludeSemantics: true,
                    child: Tappable(
                      onTap: () => catalogue.toggleFavorite(station),
                      shape: const CircleBorder(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: danger,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.remove_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StationTile(station: station, width: 48, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tagLine(station, language: context.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: rc.mu),
                      ),
                    ],
                  ),
                ),
                if (TvInput.of(context))
                  PopupMenuButton<int>(
                    tooltip: context.tr('Zmień kolejność'),
                    icon: const Icon(Icons.swap_vert_rounded),
                    onSelected: (to) => catalogue.reorderFavorite(i, to),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: i - 1,
                        enabled: i > 0,
                        child: const TrText('Przenieś wyżej'),
                      ),
                      PopupMenuItem(
                        value: i + 1,
                        enabled: i < favorites.length - 1,
                        child: const TrText('Przenieś niżej'),
                      ),
                    ],
                  )
                else
                  ReorderableDragStartListener(
                    index: i,
                    child: Tooltip(
                      message: context.tr('Przeciągnij, aby zmienić kolejność'),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.drag_indicator_rounded, color: rc.mu),
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
}

class _AddTile extends ConsumerWidget {
  const _AddTile();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    return Tappable(
      onTap: () => ref.read(stationsProvider).navigate(AppPage.browse),
      borderRadius: BorderRadius.circular(22),
      semanticLabel: 'Dodaj stację. Przeglądaj katalog',
      child: CustomPaint(
        painter: DashedBorderPainter(color: rc.bd2, radius: 22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: rc.hov,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.add_rounded, color: rc.mu),
              ),
              const SizedBox(height: 10),
              TrText(
                'Dodaj stację',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: rc.mu,
                ),
              ),
              TrText(
                'Przeglądaj katalog',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: rc.mu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return CustomPaint(
      painter: DashedBorderPainter(color: rc.bd2, radius: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_rounded, size: 18, color: rc.mu),
            const SizedBox(width: 10),
            Expanded(
              child: TrText(
                'Dodawaj stacje sercem — w liście, wyszukiwarce lub odtwarzaczu.',
                style: TextStyle(fontSize: 13, color: rc.mu, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dashed rounded-rectangle outline.
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.75),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
