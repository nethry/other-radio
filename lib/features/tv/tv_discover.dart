import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/country_filter.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import '../stations/station_controller.dart';
import 'tv_focusable.dart';
import 'tv_overlays.dart';
import 'tv_rows.dart';
import 'tv_shell.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Discover (`Odkrywaj`): featured station, then Favourites, Recently played,
/// Popular and Genres rows.
///
/// Default focus is the hero's "Słuchaj teraz", so one press starts music.
/// ↑/↓ move between rows (each keeps its column), ↑ from the hero reaches
/// the mini-player, Back from deep content returns to the hero.
class TvDiscover extends ConsumerStatefulWidget {
  const TvDiscover({super.key});

  @override
  ConsumerState<TvDiscover> createState() => _TvDiscoverState();
}

enum _Row { favorites, recent, popular, genres }

class _TvDiscoverState extends ConsumerState<TvDiscover> {
  final _scroll = ScrollController();
  final _mini = FocusNode(debugLabel: 'mini player');
  final _heroPlay = FocusNode(debugLabel: 'hero play');
  final _heroFavorite = FocusNode(debugLabel: 'hero favorite');
  final _rows = {for (final row in _Row.values) row: GlobalKey<TvRowState>()};

  static const _popularCount = 24;
  static const _recentCount = 12;

  @override
  void dispose() {
    _scroll.dispose();
    _mini.dispose();
    _heroPlay.dispose();
    _heroFavorite.dispose();
    super.dispose();
  }

  /// Rows that can take focus, in screen order (`null` is the hero).
  List<_Row?> _focusable() => [
    null,
    for (final row in _Row.values)
      if (_rows[row]!.currentWidget case TvRow(:final count) when count > 0)
        row,
  ];

  void _focusHero() {
    _heroPlay.requestFocus();
    _scrollTo(0);
  }

  void _focusRow(_Row row) {
    final key = _rows[row]!;
    key.currentState?.focus();
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !_scroll.hasClients) return;
    final top = RenderAbstractViewport.of(box).getOffsetToReveal(box, 0).offset;
    _scrollTo(top - _scroll.position.viewportDimension * TvLayout.rowAnchor);
  }

  void _scrollTo(double offset) {
    if (!_scroll.hasClients) return;
    final target = offset.clamp(0.0, _scroll.position.maxScrollExtent);
    final duration = TvMotion.of(context, TvMotion.screen);
    if (duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: duration, curve: TvMotion.outCurve);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final down = key == LogicalKeyboardKey.arrowDown;
    if (!down && key != LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.ignored;
    }
    if (_mini.hasFocus) {
      if (down) _focusHero();
      return KeyEventResult.handled;
    }
    final order = _focusable();
    final hero = _heroPlay.hasFocus || _heroFavorite.hasFocus;
    final index = hero
        ? 0
        : order.indexWhere(
            (r) => r != null && _rows[r]!.currentState!.hasFocus,
          );
    if (index < 0) return KeyEventResult.ignored;
    final target = index + (down ? 1 : -1);
    if (target < 0) {
      if (_mini.context != null) _mini.requestFocus();
    } else if (target < order.length) {
      final row = order[target];
      row == null ? _focusHero() : _focusRow(row);
    }
    return KeyEventResult.handled;
  }

  /// Back from deep content returns to the hero; on the hero the shell opens
  /// the rail.
  bool _onBack() {
    if (_heroPlay.hasFocus || _heroPlay.context == null) return false;
    _focusHero();
    return true;
  }

  void _menu(Station station, List<Station> queue, String source) =>
      showTvStationMenu(context, ref, station, queue: queue, source: source);

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    final history = ref.watch(historyProvider);
    final language = context.languageCode;
    final stations = catalogue.stations;
    final country = countryLabel(context, catalogue.countryCode);
    final subtitle =
        catalogue.error ??
        (catalogue.loading && stations.isEmpty
            ? 'Wczytywanie stacji z Radio Browser…'
            : '${context.tr('Stacje z Radio Browser')} · $country');
    final Widget body;
    if (stations.isEmpty && catalogue.loading) {
      body = const _Skeleton();
    } else if (stations.isEmpty) {
      body = TvEmptyState(
        icon: Icons.cloud_off_rounded,
        color: TvColors.warning,
        title: 'Nie znaleziono stacji',
        message:
            catalogue.error ??
            'Nie udało się pobrać katalogu stacji. Spróbuj ponownie.',
        actions: [
          TvButton(
            label: 'Spróbuj ponownie',
            icon: Icons.refresh_rounded,
            primary: true,
            autofocus: true,
            onTap: catalogue.refresh,
          ),
        ],
      );
    } else {
      final favorites = catalogue.sortedFavorites(history.lastPlayed);
      final seen = <String>{};
      final recent = [
        for (final entry in history.entries)
          if (seen.add(entry.station.id)) entry.station,
      ].take(_recentCount).toList();
      final popular = stations.take(_popularCount).toList();
      body = SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.only(bottom: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Hero(
              station: stations.first,
              playNode: _heroPlay,
              favoriteNode: _heroFavorite,
              onLongPress: () => _menu(stations.first, stations, 'Katalogu'),
            ),
            _Section(
              title: 'Ulubione',
              note: favorites.isEmpty
                  ? null
                  : '${stationCount(favorites.length, language: language)} · '
                        '${context.tr('przytrzymaj OK, aby zarządzać')}',
              child: favorites.isEmpty
                  ? const _EmptyFavorites()
                  : _stationRow(_Row.favorites, favorites, 'Ulubionych'),
            ),
            if (recent.isNotEmpty)
              _Section(
                title: 'Ostatnio słuchane',
                note: context.tr('Wznów jednym kliknięciem'),
                child: _stationRow(_Row.recent, recent, 'Historii'),
              ),
            _Section(
              title: 'Popularne',
              note: '$country · ${context.tr('według Radio Browser')}',
              child: _stationRow(_Row.popular, popular, 'Katalogu'),
            ),
            _Section(
              title: 'Gatunki',
              child: TvRow(
                key: _rows[_Row.genres],
                count: Genre.values.length,
                itemWidth: 150,
                onLeftEdge: () => TvShellScope.openRail(context),
                itemBuilder: (context, i, node) => _GenreTile(
                  genre: Genre.values[i],
                  node: node,
                  onTap: () => openTvStations(context, Genre.values[i]),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return TvBackHandler(
      onBack: _onBack,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _onKey,
        child: TvPageFrame(
          title: 'Odkrywaj',
          subtitle: subtitle,
          miniFocusNode: _mini,
          child: body,
        ),
      ),
    );
  }

  Widget _stationRow(_Row row, List<Station> stations, String source) => TvRow(
    key: _rows[row],
    count: stations.length,
    itemWidth: TvLayout.card,
    onLeftEdge: () => TvShellScope.openRail(context),
    itemBuilder: (context, i, node) => TvStationCard(
      station: stations[i],
      focusNode: node,
      onTap: () => tvActivate(
        context,
        ref,
        stations[i],
        queue: stations,
        source: source,
      ),
      onLongPress: () => _menu(stations[i], stations, source),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.note});
  final String title;
  final String? note;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            TvLayout.ringInset,
            0,
            TvLayout.safeX,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                header: true,
                child: Text(context.tr(title), style: tvHeading(19)),
              ),
              if (note != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tvBody(11, color: TvColors.muted),
                  ),
                ),
              ],
            ],
          ),
        ),
        child,
      ],
    ),
  );
}

class _Hero extends ConsumerWidget {
  const _Hero({
    required this.station,
    required this.playNode,
    required this.favoriteNode,
    required this.onLongPress,
  });
  final Station station;
  final FocusNode playNode;
  final FocusNode favoriteNode;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider.select((p) => p.state));
    final favorite = ref.watch(
      stationsProvider.select((c) => c.isFavorite(station)),
    );
    final current =
        state.station?.id == station.id &&
        state.phase != RadioPhase.error &&
        state.phase != RadioPhase.idle;
    final stations = ref.read(stationsProvider).stations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TvLayout.ringInset,
        TvLayout.ringInset,
        TvLayout.safeX,
        0,
      ),
      child: Container(
        height: 210,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: TvColors.heroSurface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: TvColors.heroOutline),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              right: -30,
              top: -20,
              width: 260,
              height: 210,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x2E5EE6CF), Color(0x005EE6CF)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Polecana stacja').toUpperCase(),
                          style: tvLabel(color: TvColors.accent),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          station.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvHeading(38),
                        ),
                        const SizedBox(height: 9),
                        Text(
                          subtitle(station, language: context.languageCode),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvBody(13, color: TvColors.text2),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            TvButton(
                              label: current
                                  ? 'Otwórz odtwarzacz'
                                  : 'Słuchaj teraz',
                              icon: Icons.play_arrow_rounded,
                              primary: true,
                              focusNode: playNode,
                              autofocus: true,
                              onLongPress: onLongPress,
                              onTap: () => tvActivate(
                                context,
                                ref,
                                station,
                                queue: stations,
                                source: 'Katalogu',
                              ),
                            ),
                            TvButton(
                              label: favorite
                                  ? 'W ulubionych'
                                  : 'Dodaj do ulubionych',
                              icon: favorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              focusNode: favoriteNode,
                              onTap: () =>
                                  tvToggleFavorite(context, ref, station),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  TvArt(
                    station: station,
                    size: MediaQuery.sizeOf(context).width < 900 ? 130 : 160,
                    radius: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      TvLayout.ringInset,
      TvLayout.ringInset,
      TvLayout.safeX,
      TvLayout.ringInset,
    ),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 450),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TvColors.outline2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.favorite_border_rounded,
            size: 24,
            color: TvColors.accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              context.tr(
                'Brak ulubionych. Przytrzymaj OK na dowolnej stacji i wybierz „Dodaj do ulubionych”.',
              ),
              style: tvBody(13, color: TvColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.genre,
    required this.node,
    required this.onTap,
  });
  final Genre genre;
  final FocusNode node;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: node,
    reveal: false,
    onTap: onTap,
    semanticLabel: genre == Genre.all ? 'Wszystkie stacje' : genre.label,
    builder: (context, focused, pressed) => TvScale(
      focused: focused,
      pressed: pressed,
      child: AnimatedContainer(
        duration: TvMotion.of(context, TvMotion.focus),
        width: 150,
        height: 75,
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: TvColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: focused ? Colors.transparent : TvColors.outline,
          ),
          boxShadow: focused ? tvRing() : const [],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(
                genre == Genre.all
                    ? Icons.grid_view_rounded
                    : Icons.graphic_eq_rounded,
                size: 18,
                color: TvColors.accent,
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                context.tr(
                  genre == Genre.all ? 'Wszystkie stacje' : genre.label,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tvHeading(15),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Skeletons in the final layout (no spinner on browse), so nothing jumps
/// when the catalogue arrives.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        TvLayout.ringInset,
        TvLayout.ringInset,
        0,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: TvLayout.safeX),
            child: Shimmer(height: 210, radius: 22),
          ),
          const SizedBox(height: 26),
          const Shimmer(width: 130, height: 17, radius: 5),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < 6; i++)
                  const Padding(
                    padding: EdgeInsets.only(right: TvLayout.gutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Shimmer(
                          width: TvLayout.card,
                          height: TvLayout.card,
                          radius: 14,
                        ),
                        SizedBox(height: 9),
                        Shimmer(width: 100, height: 11, radius: 4),
                        SizedBox(height: 5),
                        Shimmer(width: 70, height: 8, radius: 4),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Full list for a genre (or every station) as a lazy grid. Back returns to
/// the genre tile.
Future<void> openTvStations(BuildContext context, Genre genre) async {
  final opener = FocusManager.instance.primaryFocus;
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: TvMotion.of(context, TvMotion.screen),
      reverseTransitionDuration: TvMotion.of(context, TvMotion.focus),
      pageBuilder: (_, _, _) => _TvStationsScreen(genre: genre),
      transitionsBuilder: (context, animation, _, child) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.03), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
          child: child,
        ),
      ),
    ),
  );
  restoreTvFocus(opener);
}

class _TvStationsScreen extends ConsumerWidget {
  const _TvStationsScreen({required this.genre});
  final Genre genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final stations = catalogue.stations.where(genre.matches).toList();
    const source = 'Katalogu';
    return Scaffold(
      backgroundColor: TvColors.bg,
      body: TvPageFrame(
        left: TvLayout.safeX - TvLayout.ringInset,
        title: genre == Genre.all ? 'Wszystkie stacje' : genre.label,
        subtitle:
            '${stationCount(stations.length, language: context.languageCode)}'
            ' · ${countryLabel(context, catalogue.countryCode)}',
        translateSubtitle: false,
        child: stations.isEmpty
            ? TvEmptyState(
                icon: Icons.radio_rounded,
                title: 'Nie znaleziono stacji',
                message: 'Zmień filtr lub odśwież listę.',
                actions: [
                  TvButton(
                    label: 'Wstecz',
                    autofocus: true,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              )
            : TvStationGrid(
                stations: stations,
                onTap: (station, _) => tvActivate(
                  context,
                  ref,
                  station,
                  queue: stations,
                  source: source,
                ),
                onLongPress: (station, _) => showTvStationMenu(
                  context,
                  ref,
                  station,
                  queue: stations,
                  source: source,
                ),
              ),
      ),
    );
  }
}
