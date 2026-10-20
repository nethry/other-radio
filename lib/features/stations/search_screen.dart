import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import '../common.dart';
import 'station_controller.dart';
import 'station_details_screen.dart';

/// Search across the fetched catalogue by name, tag and region.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  /// Page width below which the phone layout is used.
  static const compact = 640.0;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _text;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: ref.read(stationsProvider).query);
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    _text.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    ref.read(stationsProvider).search(value);
  }

  void _clear() => _setQuery('');

  void _cancel() {
    final catalogue = ref.read(stationsProvider);
    _text.clear();
    _focus.unfocus();
    catalogue.clearSearch();
    catalogue.navigate(AppPage.browse);
  }

  void _play(Station s, List<Station> results) {
    final catalogue = ref.read(stationsProvider);
    catalogue.rememberSearch();
    playFrom(ref, s, queue: results, source: 'Wyszukiwania');
  }

  void _details(Station s) {
    ref.read(stationsProvider).rememberSearch();
    openStation(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    // Keep the field in step when the query changes elsewhere (e.g. a tag tap
    // or clearSearch). Changing the controller during build would notify the
    // field mid-build, so defer it.
    if (_text.text != catalogue.query) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _text.text != ref.read(stationsProvider).query) {
          final q = ref.read(stationsProvider).query;
          _text.value = TextEditingValue(
            text: q,
            selection: TextSelection.collapsed(offset: q.length),
          );
        }
      });
    }
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clear},
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= SearchScreen.compact;
          return wide
              ? _buildWide(context, constraints.maxWidth)
              : _buildMobile(context);
        },
      ),
    );
  }

  Widget _clearButton() {
    final rc = context.rc;
    return Tappable(
      onTap: _clear,
      shape: const CircleBorder(),
      tooltip: 'Wyczyść',
      semanticLabel: 'Wyczyść',
      child: Ink(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: rc.hov, shape: BoxShape.circle),
        child: Icon(Icons.close_rounded, size: 14, color: rc.mu),
      ),
    );
  }

  Widget _field({required bool wide}) {
    final catalogue = ref.read(stationsProvider);
    final hasText = _text.text.isNotEmpty || catalogue.query.isNotEmpty;
    return SearchField(
      fieldKey: const ValueKey('station-search'),
      controller: _text,
      focusNode: _focus,
      autofocus: wide,
      height: wide ? 56 : 52,
      fontSize: wide ? 16 : 15,
      onChanged: catalogue.search,
      onSubmitted: (_) => catalogue.rememberSearch(),
      trailing: hasText
          ? _clearButton()
          : wide
          ? const Kbd('Esc')
          : null,
    );
  }

  List<Widget> _filters(StationController catalogue) {
    final genre = catalogue.searchGenre;
    final region = catalogue.searchPlace;
    return [
      PopupMenuButton<String>(
        tooltip: 'Gatunek',
        onSelected: (v) => catalogue.setSearchGenre(v.isEmpty ? null : v),
        itemBuilder: (_) => [
          const PopupMenuItem(value: '', child: Text('Dowolny')),
          for (final tag in catalogue.popularTags())
            PopupMenuItem(value: tag, child: Text(tag)),
        ],
        child: RadioChip(
          label: genre == null ? 'Gatunek' : 'Gatunek: $genre',
          selected: genre != null,
          small: true,
          dropdown: true,
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Miasto',
        onSelected: (v) => catalogue.setSearchPlace(v.isEmpty ? null : v),
        itemBuilder: (_) => [
          const PopupMenuItem(value: '', child: Text('Dowolne')),
          for (final p in catalogue.places)
            PopupMenuItem(value: p, child: Text(p)),
        ],
        child: RadioChip(
          label: region == null ? 'Miasto' : 'Miasto: $region',
          selected: region != null,
          small: true,
          dropdown: true,
        ),
      ),
      RadioChip(
        label: 'Jakość ≥ 128 kb/s',
        selected: catalogue.highQuality,
        small: true,
        onTap: catalogue.toggleHighQuality,
      ),
      RadioChip(
        label: 'Tylko HTTPS',
        selected: catalogue.httpsOnly,
        small: true,
        onTap: catalogue.toggleHttpsOnly,
      ),
    ];
  }

  /// Recent searches and popular genres, shown before the user types.
  Widget _suggestions(StationController catalogue) {
    final recent = catalogue.recentSearches;
    final popular = catalogue.popularTags(10);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: SectionLabel('Ostatnio wyszukiwane')),
              TextButton(
                onPressed: catalogue.clearRecentSearches,
                child: const Text('Wyczyść', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                TagChip(
                  q,
                  icon: Icons.history_rounded,
                  onTap: () => _setQuery(q),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (popular.isNotEmpty) ...[
          const SectionLabel('Popularne gatunki'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in popular)
                TagChip(tag, onTap: () => _setQuery(tag)),
            ],
          ),
        ],
      ],
    );
  }

  String _title(StationController catalogue) {
    final q = catalogue.query.trim();
    return q.isEmpty ? 'Wyniki' : 'Wyniki dla „$q”';
  }

  Widget _empty() => const EmptyState(
    icon: Icons.travel_explore_rounded,
    title: 'Nie znaleziono stacji',
    message: 'Zmień wyszukiwanie lub filtry.',
  );

  Widget _buildMobile(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    final state = ref.watch(playbackProvider).state;
    final rc = context.rc;
    final results = catalogue.results;
    final q = catalogue.query.trim();
    final top = MediaQuery.paddingOf(context).top + 16;
    final bottom = ShellInsets.bottomOf(context) + 24;
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20, top, 12, 0),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(child: _field(wide: false)),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Anuluj', style: TextStyle(fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                for (final (i, chip) in _filters(catalogue).indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  chip,
                ],
              ],
            ),
          ),
        ),
        if (!catalogue.searching)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(child: _suggestions(catalogue)),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CatalogueStatus(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _title(catalogue),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: heading(17),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'pokazano ${results.length}',
                        style: monoStyle(12, color: rc.mu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (catalogue.loading && catalogue.stations.isEmpty)
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _SkeletonRow()),
            )
          else if (results.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: _empty()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: SliverList.builder(
                itemCount: results.length,
                itemBuilder: (context, i) {
                  final s = results[i];
                  return Rise(
                    index: i,
                    child: _ResultRow(
                      station: s,
                      query: q,
                      state: state,
                      onTap: () => _details(s),
                      onPlay: () => _play(s, results),
                    ),
                  );
                },
              ),
            ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }

  Widget _buildWide(BuildContext context, double width) {
    final catalogue = ref.watch(stationsProvider);
    final state = ref.watch(playbackProvider).state;
    final rc = context.rc;
    final results = catalogue.results;
    final q = catalogue.query.trim();
    final columns = width >= 820;
    final top = MediaQuery.paddingOf(context).top + 24;
    final bottom = ShellInsets.bottomOf(context) + 40;
    final related = catalogue.searching
        ? catalogue.relatedTags(results)
        : const <String>[];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(32, top, 32, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(wide: true),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _filters(catalogue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          'Sortuj:',
                          style: TextStyle(fontSize: 13, color: rc.mu),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<SearchSort>(
                      tooltip: 'Sortowanie',
                      initialValue: catalogue.searchSort,
                      onSelected: catalogue.setSearchSort,
                      itemBuilder: (_) => [
                        for (final s in SearchSort.values)
                          PopupMenuItem(value: s, child: Text(s.label)),
                      ],
                      child: RadioChip(
                        label: catalogue.searchSort.label,
                        small: true,
                        dropdown: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        if (!catalogue.searching)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            sliver: SliverToBoxAdapter(child: _suggestions(catalogue)),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CatalogueStatus(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            _title(catalogue),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: heading(28),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'pokazano ${results.length}',
                        style: monoStyle(12, color: rc.mu),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (results.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: SliverToBoxAdapter(child: _empty()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              sliver: DecoratedSliver(
                decoration: BoxDecoration(
                  color: rc.sf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: rc.bd),
                  boxShadow: rc.shadowSm,
                ),
                sliver: SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
                  sliver: SliverList.builder(
                    itemCount: results.length + 1,
                    itemBuilder: (context, i) {
                      if (i == 0) return _TableHeader(columns: columns);
                      final s = results[i - 1];
                      return _TableRow(
                        station: s,
                        query: q,
                        state: state,
                        columns: columns,
                        last: i == results.length,
                        onPlay: () => _play(s, results),
                        onDetails: () => _details(s),
                      );
                    },
                  ),
                ),
              ),
            ),
          if (related.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 22, 32, 0),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: SectionLabel('Podobne gatunki'),
                    ),
                    for (final tag in related)
                      TagChip(tag, onTap: () => _setQuery(tag)),
                  ],
                ),
              ),
            ),
        ],
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }
}

/// Up to three tags, putting those that match [query] first.
String _tagsFor(Station s, String query) {
  final q = query.toLowerCase();
  final genres = s.genres;
  if (genres.isEmpty) return 'radio internetowe';
  final ordered = q.isEmpty
      ? genres
      : [
          ...genres.where((g) => g.contains(q)),
          ...genres.where((g) => !g.contains(q)),
        ];
  return ordered.take(3).join(' · ');
}

/// Text with every case-insensitive occurrence of [query] emphasised.
TextSpan _highlight(String text, String query, TextStyle hit) {
  final q = query.toLowerCase();
  if (q.isEmpty) return TextSpan(text: text);
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final i = lower.indexOf(q, start);
    if (i < 0) break;
    if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
    spans.add(TextSpan(text: text.substring(i, i + q.length), style: hit));
    start = i + q.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return TextSpan(children: spans);
}

TextStyle _hitStyle(BuildContext context) =>
    TextStyle(color: context.rc.act, fontWeight: FontWeight.w800);

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.station,
    required this.query,
    required this.state,
    required this.onTap,
    required this.onPlay,
  });
  final Station station;
  final String query;
  final RadioSnapshot state;
  final VoidCallback onTap;
  final VoidCallback onPlay;

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
                  StationTile(station: station, width: 48, fontSize: 12),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          _highlight(station.name, query, _hitStyle(context)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: playing ? rc.act : rc.tx,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text.rich(
                          _highlight(
                            '${place(station)} · ${_tagsFor(station, query)}',
                            query,
                            _hitStyle(context),
                          ),
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
        IconBox(
          icon: Icons.play_circle_outline_rounded,
          tooltip: 'Odtwórz ${station.name}',
          ghost: true,
          iconSize: 24,
          color: rc.act,
          onPressed: onPlay,
        ),
      ],
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns});
  final bool columns;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final style = labelStyle(context).copyWith(letterSpacing: 1.1);
    Widget cell(String text, {TextAlign align = TextAlign.left}) => Text(
      text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: align,
      style: style,
    );
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: rc.bd)),
        ),
        child: Row(
          children: [
            Expanded(flex: 4, child: cell('Stacja')),
            if (columns) ...[
              Expanded(flex: 2, child: cell('Miasto')),
              Expanded(flex: 3, child: cell('Tagi')),
            ],
            Expanded(flex: 2, child: cell('Kodek')),
            SizedBox(width: 84, child: cell('Akcje', align: TextAlign.right)),
          ],
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({
    required this.station,
    required this.query,
    required this.state,
    required this.columns,
    required this.last,
    required this.onPlay,
    required this.onDetails,
  });
  final Station station;
  final String query;
  final RadioSnapshot state;
  final bool columns;
  final bool last;
  final VoidCallback onPlay;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final playing = isPlaying(state, station);
    final muted = TextStyle(fontSize: 14, color: rc.mu);
    return Container(
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: rc.bd)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Tappable(
              onTap: onPlay,
              pressScale: 0.985,
              borderRadius: BorderRadius.circular(12),
              tooltip: 'Odtwórz ${station.name}',
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    StationTile(
                      station: station,
                      width: 40,
                      radius: 12,
                      fontSize: 11,
                      overlay: playing
                          ? [
                              Positioned(
                                right: -4,
                                bottom: -4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: rc.ac,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Eq(
                                    height: 12,
                                    playing: state.phase == RadioPhase.playing,
                                    color: rc.onAccent,
                                  ),
                                ),
                              ),
                            ]
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        _highlight(station.name, query, _hitStyle(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: playing ? rc.act : rc.tx,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (columns) ...[
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  place(station),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text.rich(
                  _highlight(
                    _tagsFor(station, query),
                    query,
                    _hitStyle(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: muted,
                ),
              ),
            ),
          ],
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                formatLong(station),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: monoStyle(12, color: rc.mu),
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconBox(
                  icon: Icons.info_outline_rounded,
                  tooltip: 'Szczegóły: ${station.name}',
                  ghost: true,
                  size: 36,
                  iconSize: 18,
                  onPressed: onDetails,
                ),
                const SizedBox(width: 4),
                HeartButton(station: station, size: 36, iconSize: 18),
              ],
            ),
          ),
        ],
      ),
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
