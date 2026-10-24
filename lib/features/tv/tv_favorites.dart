import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/models/station.dart';
import '../stations/station_controller.dart';
import 'tv_overlays.dart';
import 'tv_rows.dart';
import 'tv_shell.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Favourites grid. OK plays; hold OK → Odtwórz · Przenieś · Usuń.
/// "Przenieś" lifts the card: arrows move it, OK drops, Back cancels — the
/// remote replacement for drag-to-reorder.
class TvFavorites extends ConsumerStatefulWidget {
  const TvFavorites({super.key});

  @override
  ConsumerState<TvFavorites> createState() => _TvFavoritesState();
}

enum _Action { play, move, remove }

class _TvFavoritesState extends ConsumerState<TvFavorites> {
  final _grid = GlobalKey<TvStationGridState>();

  /// Working order while a card is lifted, and where it started.
  List<Station>? _moving;
  String? _lifted;
  int _from = 0;

  void _startMove(Station station) {
    final catalogue = ref.read(stationsProvider);
    catalogue.sortFavorites(FavoriteSort.own);
    final list = [...catalogue.favorites];
    setState(() {
      _moving = list;
      _lifted = station.id;
      _from = list.indexWhere((s) => s.id == station.id);
    });
    _grid.currentState?.focusIndex(_from);
  }

  bool _step(int index, int columns, LogicalKeyboardKey key) {
    final list = _moving;
    if (list == null) return false;
    final target = switch (key) {
      LogicalKeyboardKey.arrowLeft => index - 1,
      LogicalKeyboardKey.arrowRight => index + 1,
      LogicalKeyboardKey.arrowUp => index - columns,
      _ => index + columns,
    };
    if (target < 0 || target >= list.length) return true;
    setState(() => list.insert(target, list.removeAt(index)));
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _grid.currentState?.focusIndex(target),
    );
    return true;
  }

  void _drop() {
    final list = _moving!;
    final to = list.indexWhere((s) => s.id == _lifted);
    setState(() {
      _moving = null;
      _lifted = null;
    });
    if (to != _from) ref.read(stationsProvider).reorderFavorite(_from, to);
  }

  bool _onBack() {
    if (_moving == null) return false;
    final from = _from;
    setState(() {
      _moving = null;
      _lifted = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _grid.currentState?.focusIndex(from),
    );
    return true;
  }

  Future<void> _menu(Station station, int index, List<Station> list) async {
    final action = await showTvMenu<_Action?>(
      context,
      station: station,
      items: const [
        (
          value: _Action.play,
          icon: Icons.play_arrow_rounded,
          label: 'Odtwórz',
          danger: false,
        ),
        (
          value: _Action.move,
          icon: Icons.open_with_rounded,
          label: 'Przenieś',
          danger: false,
        ),
        (
          value: _Action.remove,
          icon: Icons.heart_broken_outlined,
          label: 'Usuń z ulubionych',
          danger: true,
        ),
        (
          value: null,
          icon: Icons.close_rounded,
          label: 'Anuluj',
          danger: false,
        ),
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _Action.play:
        ref
            .read(playbackProvider)
            .select(station, queue: list, source: 'Ulubionych');
        TvToast.show(context, '${context.tr('Teraz gra')}: ${station.name}');
      case _Action.move:
        _startMove(station);
      case _Action.remove:
        final remove = await confirmTv(
          context,
          title: 'Usunąć z ulubionych?',
          message:
              '„${station.name}” ${context.tr('zniknie z listy ulubionych. Możesz ją dodać ponownie w każdej chwili.')}',
          confirm: 'Usuń',
        );
        if (!remove || !mounted) return;
        await ref.read(stationsProvider).toggleFavorite(station);
        if (!mounted) return;
        TvToast.show(
          context,
          '${context.tr('Usunięto z ulubionych')}: ${station.name}',
        );
        // Focus the next card, or the previous one when the last went.
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _grid.currentState?.focusIndex(index),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    final lastPlayed = ref.watch(historyProvider.select((h) => h.lastPlayed));
    final list = _moving ?? catalogue.sortedFavorites(lastPlayed);
    final language = context.languageCode;
    final subtitle = _moving != null
        ? context.tr(
            'Strzałki przesuwają stację · OK upuszcza · Wstecz anuluje',
          )
        : '${stationCount(list.length, language: language)} · '
              '${context.tr('OK odtwarza · przytrzymaj OK, aby przenieść lub usunąć')}';
    return TvBackHandler(
      onBack: _onBack,
      child: TvPageFrame(
        title: 'Ulubione',
        subtitle: list.isEmpty ? null : subtitle,
        translateSubtitle: false,
        child: list.isEmpty
            ? TvEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Nie masz jeszcze ulubionych stacji',
                message: 'Przytrzymaj OK na dowolnej stacji i wybierz „Dodaj do ulubionych” — albo naciśnij serce w odtwarzaczu.',
                actions: [
                  TvButton(
                    label: 'Odkrywaj stacje',
                    icon: Icons.explore_outlined,
                    primary: true,
                    autofocus: true,
                    onTap: () => catalogue.navigate(AppPage.browse),
                  ),
                  TvButton(
                    label: 'Szukaj',
                    icon: Icons.search_rounded,
                    onTap: () => catalogue.navigate(AppPage.search),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TvLayout.ringInset,
                      TvLayout.ringInset,
                      TvLayout.safeX,
                      2,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (sort, label) in const [
                          (FavoriteSort.own, 'Moja kolejność'),
                          (FavoriteSort.az, 'A–Z'),
                          (FavoriteSort.recent, 'Ostatnio słuchane'),
                        ])
                          TvChip(
                            label: label,
                            selected: catalogue.favoriteSort == sort,
                            onTap: _moving == null
                                ? () => catalogue.sortFavorites(sort)
                                : null,
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TvStationGrid(
                      key: _grid,
                      stations: list,
                      numbered: true,
                      lifted: _lifted,
                      onArrow: _step,
                      onTap: (station, _) => _moving != null
                          ? _drop()
                          : tvActivate(
                              context,
                              ref,
                              station,
                              queue: list,
                              source: 'Ulubionych',
                            ),
                      onLongPress: (station, index) =>
                          _moving == null ? _menu(station, index, list) : null,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
