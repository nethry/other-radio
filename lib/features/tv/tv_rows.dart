import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/station.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Horizontal content row (`ContentRow`). ←/→ move one item and keep the
/// focused item within the first four slots; the row remembers its column so
/// ↑/↓ between rows never resets the position. Focus never wraps.
class TvRow extends StatefulWidget {
  const TvRow({
    super.key,
    required this.count,
    required this.itemBuilder,
    required this.itemWidth,
    this.onLeftEdge,
  });
  final int count;
  final double itemWidth;
  final Widget Function(BuildContext context, int index, FocusNode node)
  itemBuilder;

  /// ← on the first item (opens the nav rail).
  final VoidCallback? onLeftEdge;

  @override
  State<TvRow> createState() => TvRowState();
}

class TvRowState extends State<TvRow> {
  final _scroll = ScrollController();
  final _nodes = <FocusNode>[];
  final _wrapper = FocusNode(
    debugLabel: 'row',
    canRequestFocus: false,
    skipTraversal: true,
  );
  int column = 0;

  bool get hasFocus => _wrapper.hasFocus;
  double get _step => widget.itemWidth + TvLayout.gutter;

  /// Focuses the remembered column.
  void focus() {
    if (widget.count == 0) return;
    column = column.clamp(0, widget.count - 1);
    _scrollTo(column);
    _nodes[column].requestFocus();
  }

  void _sync() {
    while (_nodes.length < widget.count) {
      final i = _nodes.length;
      final node = FocusNode(debugLabel: 'row item $i');
      node.addListener(() {
        if (node.hasFocus) column = i;
      });
      _nodes.add(node);
    }
  }

  void _scrollTo(int index) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final target = ((index - 3).clamp(0, index) * _step).clamp(
      0.0,
      position.maxScrollExtent,
    );
    final duration = TvMotion.of(context, TvMotion.screen);
    if (duration == Duration.zero) {
      _scroll.jumpTo(target);
    } else {
      _scroll.animateTo(target, duration: duration, curve: TvMotion.outCurve);
    }
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent event) {
    if (event is KeyUpEvent || widget.count == 0) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final int next;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (column == 0) {
        if (widget.onLeftEdge == null) return KeyEventResult.ignored;
        widget.onLeftEdge!();
        return KeyEventResult.handled;
      }
      next = column - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (column >= widget.count - 1) return KeyEventResult.handled;
      next = column + 1;
    } else {
      return KeyEventResult.ignored;
    }
    column = next;
    _scrollTo(next);
    _nodes[next].requestFocus();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _wrapper.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sync();
    return Focus(
      focusNode: _wrapper,
      onKeyEvent: _onKey,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          TvLayout.ringInset,
          TvLayout.ringInset,
          TvLayout.safeX,
          TvLayout.ringInset,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < widget.count; i++)
              Padding(
                padding: EdgeInsets.only(
                  right: i == widget.count - 1 ? 0 : TvLayout.gutter,
                ),
                child: widget.itemBuilder(context, i, _nodes[i]),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lazily built station grid with explicit D-pad movement, so focus also
/// reaches rows that are not built yet. ← on the first column and ↑ on the
/// first row are left to the page (rail, header, keyboard).
class TvStationGrid extends StatefulWidget {
  const TvStationGrid({
    super.key,
    required this.stations,
    required this.onTap,
    this.onLongPress,
    this.autofocus = true,
    this.numbered = false,
    this.lifted,
    this.onArrow,
    this.cardWidth = TvLayout.card,
  });
  final List<Station> stations;
  final void Function(Station station, int index) onTap;
  final void Function(Station station, int index)? onLongPress;
  final bool autofocus;
  final bool numbered;

  /// Id of the station being moved.
  final String? lifted;

  /// Intercepts arrows (move mode); returns true when consumed.
  final bool Function(int index, int columns, LogicalKeyboardKey key)? onArrow;

  /// Minimum card width; cards stretch to fill each row.
  final double cardWidth;

  @override
  State<TvStationGrid> createState() => TvStationGridState();
}

class TvStationGridState extends State<TvStationGrid> {
  static const _spacing = TvLayout.gutter;
  final _scroll = ScrollController();
  final _nodes = <String, FocusNode>{};
  int _columns = 1;
  double _rowExtent = 200;

  FocusNode _node(Station station) =>
      _nodes.putIfAbsent(station.id, () => FocusNode(debugLabel: station.name));

  /// Scrolls [index] into view and focuses it (after the frame when it was
  /// not built yet).
  Future<void> focusIndex(int index) async {
    if (widget.stations.isEmpty) return;
    index = index.clamp(0, widget.stations.length - 1);
    final node = _node(widget.stations[index]);
    if (_scroll.hasClients) {
      final position = _scroll.position;
      final top = (index ~/ _columns) * _rowExtent;
      final bottom = top + _rowExtent;
      const margin = TvLayout.ringInset;
      final offset = top < position.pixels + margin
          ? top - margin
          : bottom > position.pixels + position.viewportDimension - margin
          ? bottom - position.viewportDimension + margin
          : position.pixels;
      final target = offset.clamp(0.0, position.maxScrollExtent);
      final duration = TvMotion.of(context, TvMotion.screen);
      if (node.context == null || duration == Duration.zero) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(target, duration: duration, curve: TvMotion.outCurve);
      }
    }
    if (node.context == null) await WidgetsBinding.instance.endOfFrame;
    if (mounted) node.requestFocus();
  }

  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final count = widget.stations.length;
    final columns = _columns;
    if ({
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
    }.contains(key)) {
      if (widget.onArrow?.call(index, columns, key) ?? false) {
        return KeyEventResult.handled;
      }
    }
    final int target;
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (index % columns == 0) return KeyEventResult.ignored;
      target = index - 1;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      if (index % columns == columns - 1 || index == count - 1) {
        return KeyEventResult.handled;
      }
      target = index + 1;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final lastRow = (count - 1) ~/ columns;
      if (index ~/ columns >= lastRow) return KeyEventResult.handled;
      target = (index + columns).clamp(0, count - 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (index < columns) return KeyEventResult.ignored;
      target = index - columns;
    } else {
      return KeyEventResult.ignored;
    }
    focusIndex(target);
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _scroll.dispose();
    for (final node in _nodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const padding = EdgeInsets.fromLTRB(
        TvLayout.ringInset,
        TvLayout.ringInset,
        TvLayout.safeX,
        TvLayout.safeY + TvLayout.ringInset,
      );
      final width = constraints.maxWidth - padding.horizontal;
      _columns = ((width + _spacing) / (widget.cardWidth + _spacing))
          .floor()
          .clamp(1, 8);
      final cell = (width - _spacing * (_columns - 1)) / _columns;
      // Artwork, gap and two text lines.
      final extent = cell + 9 + 20 + 16;
      _rowExtent = extent + _spacing;
      final stations = widget.stations;
      return GridView.builder(
        controller: _scroll,
        padding: padding,
        clipBehavior: Clip.hardEdge,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisExtent: extent,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: _spacing,
        ),
        itemCount: stations.length,
        findChildIndexCallback: (key) {
          final index = stations.indexWhere(
            (s) => s.id == (key as ValueKey<String>).value,
          );
          return index < 0 ? null : index;
        },
        itemBuilder: (context, index) {
          final station = stations[index];
          return Focus(
            key: ValueKey(station.id),
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (_, event) => _onKey(index, event),
            child: TvStationCard(
              station: station,
              focusNode: _node(station),
              autofocus: widget.autofocus && index == 0,
              width: cell,
              number: widget.numbered ? index + 1 : null,
              lifted: widget.lifted == station.id,
              onTap: () => widget.onTap(station, index),
              onLongPress: widget.onLongPress == null
                  ? null
                  : () => widget.onLongPress!(station, index),
            ),
          );
        },
      );
    },
  );
}
