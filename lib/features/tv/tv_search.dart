import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/models/station.dart';
import 'tv_focusable.dart';
import 'tv_overlays.dart';
import 'tv_rows.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Search with an on-screen keyboard (Polish letters included), so a remote
/// never needs the system IME. Results refresh after every letter and
/// suggestions appear after the first, so most searches take 2–3 presses.
/// The ⌫ key deletes; Back always leaves the page.
class TvSearch extends ConsumerWidget {
  const TvSearch({super.key});

  static const _rows = ['aąbcćdeę', 'fghijklł', 'mnńoóprs', 'śtuwyzźż'];
  static const _digits = '01234567';
  static const _popularCount = 30;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final query = catalogue.query;
    final q = query.trim().toLowerCase();
    final results = q.isEmpty
        ? catalogue.stations.take(_popularCount).toList()
        : catalogue.results;
    final suggestions = q.isEmpty
        ? const <String>[]
        : <String>{
            for (final tag in catalogue.popularTags(200))
              if (tag.contains(q) && tag != q) tag,
            for (final p in catalogue.places)
              if (p.toLowerCase().contains(q)) p,
          }.take(4).toList();
    void type(String text) => catalogue.search(query + text);
    return TvPageFrame(
      title: 'Szukaj',
      subtitle: 'Stacje, miasta i gatunki',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360 + TvLayout.ringInset * 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                TvLayout.ringInset,
                TvLayout.ringInset,
                TvLayout.ringInset,
                TvLayout.safeY,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _QueryBox(query: query),
                  const SizedBox(height: 14),
                  for (final (r, row) in _rows.indexed)
                    _KeyRow(
                      keys: [
                        for (final (c, char) in row.split('').indexed)
                          _Key(
                            label: char,
                            autofocus: r == 0 && c == 0,
                            onTap: () => type(char),
                          ),
                      ],
                    ),
                  _KeyRow(
                    keys: [
                      for (final char in _digits.split(''))
                        _Key(label: char, onTap: () => type(char)),
                    ],
                  ),
                  _KeyRow(
                    keys: [
                      _Key(label: '8', onTap: () => type('8')),
                      _Key(label: '9', onTap: () => type('9')),
                      _Key(
                        label: 'Spacja',
                        width: 77,
                        translate: true,
                        onTap: () => type(' '),
                      ),
                      _Key(
                        label: 'Usuń znak',
                        icon: Icons.backspace_outlined,
                        onTap: query.isEmpty
                            ? null
                            : () => catalogue.search(
                                query.characters.skipLast(1).toString(),
                              ),
                      ),
                      _Key(
                        label: 'Wyczyść',
                        width: 77,
                        translate: true,
                        onTap: query.isEmpty ? null : catalogue.clearSearch,
                      ),
                    ],
                  ),
                  if (catalogue.recentSearches.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      context.tr('Ostatnio wyszukiwane').toUpperCase(),
                      style: tvLabel(context.tv.muted, size: 9),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final recent in catalogue.recentSearches.take(4))
                          TvChip(
                            label: recent,
                            translate: false,
                            icon: Icons.history_rounded,
                            onTap: () => catalogue.search(recent),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (suggestions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TvLayout.ringInset,
                      TvLayout.ringInset,
                      TvLayout.safeX,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('Podpowiedzi').toUpperCase(),
                          style: tvLabel(context.tv.muted, size: 9),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in suggestions)
                              TvChip(
                                label: s,
                                translate: false,
                                onTap: () => catalogue.search(s),
                                child: _Highlighted(text: s, query: q),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TvLayout.ringInset,
                    14,
                    TvLayout.safeX,
                    0,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        context.tr(q.isEmpty ? 'Popularne' : 'Stacje'),
                        style: tvHeading(18),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          q.isEmpty
                              ? context.tr('Zacznij pisać, aby wyszukać')
                              : stationCount(
                                  results.length,
                                  language: context.languageCode,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvBody(11, color: context.tv.muted),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(
                            TvLayout.ringInset,
                            20,
                            TvLayout.safeX,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('Nie znaleziono stacji'),
                                style: tvBody(15, weight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.tr('Zmień wyszukiwanie lub filtry.'),
                                style: tvBody(12, color: context.tv.muted),
                              ),
                            ],
                          ),
                        )
                      : TvStationGrid(
                          // A new query starts at the top of its results.
                          key: ValueKey(q),
                          stations: results,
                          autofocus: false,
                          // Cards stretch to ≈ 115 dp, three across.
                          cardWidth: 110,
                          onTap: (station, _) => _play(
                            context,
                            ref,
                            station,
                            results,
                            remember: q.isNotEmpty,
                          ),
                          onLongPress: (station, _) => showTvStationMenu(
                            context,
                            ref,
                            station,
                            queue: results,
                            source: 'Wyszukiwania',
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _play(
    BuildContext context,
    WidgetRef ref,
    Station station,
    List<Station> results, {
    required bool remember,
  }) {
    if (remember) ref.read(stationsProvider).rememberSearch();
    tvActivate(
      context,
      ref,
      station,
      queue: results,
      source: remember ? 'Wyszukiwania' : 'Katalogu',
    );
  }
}

class _QueryBox extends StatelessWidget {
  const _QueryBox({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('Szukaj stacji'),
    value: query,
    child: Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: context.tv.surface2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.tv.accent, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: context.tv.muted),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              query.isEmpty
                  ? context.tr('Szukaj stacji, miast, gatunków')
                  : query,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: query.isEmpty
                  ? tvBody(14, color: context.tv.muted)
                  : tvBody(20),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(left: 2),
            width: 1.5,
            height: 22,
            color: context.tv.accent,
          ),
        ],
      ),
    ),
  );
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys});
  final List<Widget> keys;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        for (final (i, key) in keys.indexed) ...[
          if (i > 0) const SizedBox(width: 5),
          key,
        ],
      ],
    ),
  );
}

class _Key extends StatelessWidget {
  const _Key({
    required this.label,
    required this.onTap,
    this.autofocus = false,
    this.width = 36,
    this.icon,
    this.translate = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool autofocus;
  final double width;
  final IconData? icon;
  final bool translate;

  @override
  Widget build(BuildContext context) => TvFocusable(
    autofocus: autofocus,
    onTap: onTap,
    semanticLabel: translate || icon != null ? label : null,
    builder: (context, focused, pressed) {
      final fg = focused
          ? context.tv.bg
          : onTap == null
          ? context.tv.outline2
          : context.tv.text2;
      return TvScale(
        focused: focused,
        pressed: pressed,
        scale: 1.1,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.focus),
          width: width,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: focused ? context.tv.text : context.tv.surface2,
            borderRadius: BorderRadius.circular(11),
            boxShadow: focused ? tvRing(context, tight: true) : const [],
          ),
          child: icon != null
              ? Icon(icon, size: 17, color: fg)
              : Text(
                  translate ? context.tr(label) : label,
                  style: tvBody(translate ? 11 : 14, color: fg),
                ),
        ),
      );
    },
  );
}

/// Suggestion text with the typed part in teal.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});
  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final at = text.toLowerCase().indexOf(query);
    if (at < 0) return Text(text);
    final focused = DefaultTextStyle.of(context).style.color == context.tv.bg;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + query.length),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: focused ? context.tv.bg : context.tv.accent,
            ),
          ),
          TextSpan(text: text.substring(at + query.length)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
