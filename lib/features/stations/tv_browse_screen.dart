import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/country_filter.dart';
import '../common.dart';
import 'station_controller.dart';

/// Remote-first catalogue: a small fixed toolbar and independently scrolling
/// stations. Explicit grid movement also reaches lazily built rows.
class TvBrowseScreen extends ConsumerStatefulWidget {
  const TvBrowseScreen({super.key});

  @override
  ConsumerState<TvBrowseScreen> createState() => _TvBrowseScreenState();
}

class _TvBrowseScreenState extends ConsumerState<TvBrowseScreen> {
  final _scroll = ScrollController();
  final _nodes = <String, FocusNode>{};
  static const _rowExtent = 88.0;

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _move(int index, int columns, String id) async {
    final top = (index ~/ columns) * _rowExtent;
    final position = _scroll.position;
    final offset = top < position.pixels
        ? top
        : top + _rowExtent > position.pixels + position.viewportDimension
        ? top + _rowExtent - position.viewportDimension
        : position.pixels;
    _scroll.jumpTo(offset.clamp(0.0, position.maxScrollExtent));
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) _nodes[id]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final catalogue = ref.watch(stationsProvider);
    final list = catalogue.visible;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrText('Wszystkie stacje', style: heading(22)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SearchLink(
                  height: 44,
                  onTap: () => catalogue.navigate(AppPage.search),
                ),
              ),
              const SizedBox(width: 8),
              IconBox(
                icon: Icons.refresh_rounded,
                tooltip: 'Odśwież stacje',
                onPressed: catalogue.loading ? null : catalogue.refresh,
              ),
            ],
          ),
          const SizedBox(height: 8),
          const CountryFilter(),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final genre in Genre.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: RadioChip(
                      label: genre.label,
                      selected: catalogue.genre == genre,
                      onTap: () => catalogue.filter(genre),
                      small: true,
                      height: 36,
                    ),
                  ),
              ],
            ),
          ),
          const CatalogueStatus(),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: catalogue.loading
                        ? const CircularProgressIndicator()
                        : const TrText('Nie znaleziono stacji'),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = (constraints.maxWidth / 280)
                          .floor()
                          .clamp(1, 6);
                      return GridView.builder(
                        controller: _scroll,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: _rowExtent,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final station = list[index];
                          final node = _nodes.putIfAbsent(
                            station.id,
                            () => FocusNode(debugLabel: station.name),
                          );
                          return Focus(
                            canRequestFocus: false,
                            onKeyEvent: (_, event) {
                              if (event is KeyUpEvent) {
                                return KeyEventResult.ignored;
                              }
                              final key = event.logicalKey;
                              int target;
                              if (key == LogicalKeyboardKey.arrowLeft) {
                                if (index % columns == 0) {
                                  return KeyEventResult.ignored;
                                }
                                target = index - 1;
                              } else if (key == LogicalKeyboardKey.arrowRight) {
                                if (index % columns == columns - 1) {
                                  return KeyEventResult.handled;
                                }
                                target = index + 1;
                              } else if (key == LogicalKeyboardKey.arrowDown) {
                                target = index + columns;
                              } else if (key == LogicalKeyboardKey.arrowUp) {
                                if (index < columns) {
                                  return KeyEventResult.ignored;
                                }
                                target = index - columns;
                              } else {
                                return KeyEventResult.ignored;
                              }
                              if (target < list.length) {
                                _move(target, columns, list[target].id);
                              }
                              return KeyEventResult.handled;
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Tappable(
                                focusNode: node,
                                semanticLabel: 'Odtwórz ${station.name}',
                                onTap: () => playFrom(
                                  ref,
                                  station,
                                  queue: list,
                                  source: 'Katalogu',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      StationTile(
                                        station: station,
                                        width: 48,
                                        fontSize: 14,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          station.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
