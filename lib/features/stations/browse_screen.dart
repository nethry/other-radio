import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/ui/country_filter.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../core/ui/tv_input.dart';
import 'tv_browse_screen.dart';
import '../../data/models/station.dart';
import '../common.dart';
import 'station_controller.dart';

/// Catalogue page: genre chips, favourites strip and all stations.
class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  /// Page width below which the phone layout is used.
  static const compact = 640.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) => TvInput.of(context)
        ? const TvBrowseScreen()
        : constraints.maxWidth < compact
        ? const _MobileBrowse()
        : const _WideBrowse(),
  );
}

void _play(WidgetRef ref, Station s, List<Station> queue, String source) =>
    playFrom(ref, s, queue: queue, source: source);

class _MobileBrowse extends ConsumerWidget {
  const _MobileBrowse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final state = ref.watch(playbackProvider).state;
    final rc = context.rc;
    final list = catalogue.visible;
    final favorites = catalogue.favorites;
    final skeleton = catalogue.loading && catalogue.stations.isEmpty;
    final top = MediaQuery.paddingOf(context).top + 16;
    final bottom = ShellInsets.bottomOf(context) + 24;
    final ts = MediaQuery.textScalerOf(context);
    final stripHeight =
        10 + 112 + 10 + ts.scale(14) * 1.3 + 2 + ts.scale(12) * 1.3 + 26;

    return RefreshIndicator(
      onRefresh: catalogue.refresh,
      color: rc.ac,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(20, top, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Brand(),
                        ),
                      ),
                      const Spacer(),
                      IconBox(
                        icon: Icons.tune_rounded,
                        tooltip: 'Ustawienia',
                        onPressed: () => catalogue.navigate(AppPage.settings),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Semantics(
                    header: true,
                    child: TrText(
                      'Radio z całego świata,\nna żywo.',
                      style: heading(30, height: 1.1),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const LiveDot(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TrText(
                          'Stacje z całego świata w Radio Browser',
                          style: TextStyle(fontSize: 13, color: rc.mu),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SearchLink(onTap: () => catalogue.navigate(AppPage.search)),
                  const SizedBox(height: 16),
                  const CountryFilter(),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final (i, g) in Genre.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    RadioChip(
                      label: g.label,
                      selected: catalogue.genre == g,
                      onTap: () => catalogue.filter(g),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (favorites.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 12, 6),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: TrText('Ulubione', style: heading(17)),
                      ),
                    ),
                    TextButton(
                      onPressed: () => catalogue.navigate(AppPage.favorites),
                      child: const TrText(
                        'Pokaż wszystkie',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: stripHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                  itemCount: favorites.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => Rise(
                    index: i,
                    child: _FavoriteCard(
                      station: favorites[i],
                      state: state,
                      onTap: () =>
                          _play(ref, favorites[i], favorites, 'Ulubionych'),
                    ),
                  ),
                ),
              ),
            ),
          ],
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: TrText('Wszystkie stacje', style: heading(17)),
                        ),
                      ),
                      Text(
                        stationCount(
                          list.length,
                          language: context.languageCode,
                        ),
                        style: monoStyle(12, color: rc.mu),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const CatalogueStatus(),
                ],
              ),
            ),
          ),
          if (skeleton)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: 6,
                itemBuilder: (_, _) => const _SkeletonRow(),
              ),
            )
          else if (list.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.travel_explore_rounded,
                  title: 'Nie znaleziono stacji',
                  message: 'Zmień filtr lub odśwież listę.',
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, i) => Rise(
                  index: i,
                  child: _StationRow(
                    station: list[i],
                    state: state,
                    onTap: () => _play(ref, list[i], list, 'Katalogu'),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: bottom)),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({
    required this.station,
    required this.state,
    required this.onTap,
  });
  final Station station;
  final RadioSnapshot state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final playing = isPlaying(state, station);
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 132,
        child: HoverCard(
          onTap: onTap,
          selected: playing,
          radius: 20,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              StationTile(
                station: station,
                width: double.infinity,
                height: 112,
                radius: 14,
                fontSize: 26,
                overlay: playing
                    ? [
                        Positioned(
                          right: 10,
                          bottom: 10,
                          child: Eq(
                            playing: state.phase == RadioPhase.playing,
                            color: rc.tiles[paletteIndex(station.id)].fg,
                          ),
                        ),
                      ]
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                station.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: playing ? rc.act : rc.tx,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                place(station),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, height: 1.3, color: rc.mu),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({
    required this.station,
    required this.state,
    required this.onTap,
  });
  final Station station;
  final RadioSnapshot state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final playing = isPlaying(state, station);
    return Row(
      children: [
        Expanded(
          child: Tappable(
            onTap: onTap,
            pressScale: 0.985,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  StationTile(station: station, width: 48, fontSize: 13),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: playing ? rc.act : rc.tx,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle(station, language: context.languageCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: rc.mu),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (playing)
                    Eq(
                      bars: 4,
                      playing: state.phase == RadioPhase.playing,
                      color: rc.act,
                    )
                  else
                    Text(
                      formatShort(station),
                      style: monoStyle(11, color: rc.mu),
                    ),
                ],
              ),
            ),
          ),
        ),
        HeartButton(station: station),
      ],
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Shimmer(width: 48, height: 48, radius: 14),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.6,
                child: Shimmer(height: 12),
              ),
              SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.4,
                child: Shimmer(height: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _WideBrowse extends ConsumerWidget {
  const _WideBrowse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final state = ref.watch(playbackProvider).state;
    final rc = context.rc;
    final list = catalogue.visible;
    final skeleton = catalogue.loading && catalogue.stations.isEmpty;
    final ts = MediaQuery.textScalerOf(context);
    final extent =
        132 +
        12 +
        ts.scale(15) * 1.3 +
        3 +
        ts.scale(12) * 1.3 +
        8 +
        36 +
        // Card padding (2 × 12) and border (2 × 1) with a little slack.
        28;
    final grid = SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 230,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      mainAxisExtent: extent,
    );
    final top = MediaQuery.paddingOf(context).top + 24;
    final bottom = ShellInsets.bottomOf(context) + 40;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(32, top, 32, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SearchLink(
                        height: 48,
                        fontSize: 14,
                        onTap: () => catalogue.navigate(AppPage.search),
                        trailing: const Kbd('Ctrl K'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<BrowseSort>(
                      tooltip: context.tr('Sortowanie'),
                      initialValue: catalogue.browseSort,
                      onSelected: catalogue.sortBrowse,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: BrowseSort.popular,
                          child: TrText('Najpopularniejsze'),
                        ),
                        PopupMenuItem(
                          value: BrowseSort.az,
                          child: TrText('Nazwa A–Z'),
                        ),
                      ],
                      child: RadioChip(
                        label: catalogue.browseSort == BrowseSort.popular
                            ? 'Najpopularniejsze'
                            : 'Nazwa A–Z',
                        icon: Icons.sort_rounded,
                        dropdown: true,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconBox(
                      icon: Icons.refresh_rounded,
                      tooltip: 'Odśwież stacje',
                      size: 48,
                      onPressed: catalogue.loading ? null : catalogue.refresh,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: TrText(
                    'Radio z całego świata, na żywo.',
                    style: heading(40, tracking: -0.035, height: 1.05),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const LiveDot(),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${context.tr('Stacje z całego świata w Radio Browser')} · '
                        '${stationCount(list.length, language: Localizations.localeOf(context).languageCode)}',
                        style: TextStyle(fontSize: 14, color: rc.mu),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const CountryFilter(),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final g in Genre.values)
                      RadioChip(
                        label: g.label,
                        small: true,
                        height: 38,
                        selected: catalogue.genre == g,
                        onTap: () => catalogue.filter(g),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const CatalogueStatus(),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          sliver: skeleton
              ? SliverGrid.builder(
                  gridDelegate: grid,
                  itemCount: 8,
                  itemBuilder: (_, _) =>
                      const Shimmer(height: double.infinity, radius: 22),
                )
              : list.isEmpty
              ? const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.travel_explore_rounded,
                    title: 'Nie znaleziono stacji',
                    message: 'Zmień filtr lub odśwież listę.',
                  ),
                )
              : SliverGrid.builder(
                  gridDelegate: grid,
                  itemCount: list.length,
                  itemBuilder: (context, i) => Rise(
                    index: i,
                    child: _StationCard(
                      station: list[i],
                      state: state,
                      onTap: () => _play(ref, list[i], list, 'Katalogu'),
                    ),
                  ),
                ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }
}

class _StationCard extends StatelessWidget {
  const _StationCard({
    required this.station,
    required this.state,
    required this.onTap,
  });
  final Station station;
  final RadioSnapshot state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final playing = isPlaying(state, station);
    return HoverCard(
      onTap: onTap,
      semanticLabel: 'Odtwórz ${station.name}',
      selected: playing,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          StationTile(
            station: station,
            width: double.infinity,
            height: 132,
            radius: 16,
            fontSize: 34,
            overlay: playing
                ? [
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Eq(
                        bars: 4,
                        playing: state.phase == RadioPhase.playing,
                        color: rc.tiles[paletteIndex(station.id)].fg,
                      ),
                    ),
                  ]
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            station.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: playing ? rc.act : rc.tx,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle(station, language: context.languageCode),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.3, color: rc.mu),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    formatShort(station),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoStyle(11, color: rc.mu),
                  ),
                ),
                HeartButton(station: station, size: 36, iconSize: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
