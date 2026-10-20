import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../data/models/history_entry.dart';
import '../../data/models/station.dart';
import '../common.dart';
import '../stations/station_details_screen.dart';
import 'history_controller.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  static Future<void> confirmClear(
    BuildContext context,
    HistoryController history,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wyczyścić historię?'),
        content: const Text(
          'Lista ostatnio słuchanych stacji zostanie usunięta z tego urządzenia.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Wyczyść'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await history.clear();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final groups = history.groups;
    final queue = <String, Station>{
      for (final e in history.entries) e.station.id: e.station,
    }.values.toList();
    final rc = context.rc;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 640;
        final width = constraints.maxWidth;
        final top = wide ? 32.0 : MediaQuery.paddingOf(context).top + 16;
        final side = wide ? 32.0 : 20.0;
        final bottom = ShellInsets.bottomOf(context) + (wide ? 32 : 24);
        final empty = history.entries.isEmpty;

        final Widget header;
        if (wide) {
          header = Wrap(
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
                    child: Text(
                      'Historia',
                      style: heading(40, tracking: -0.035, height: 1.05),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ostatnio słuchane stacje — zapisane tylko na tym urządzeniu',
                    style: TextStyle(fontSize: 14, color: rc.mu),
                  ),
                ],
              ),
              if (!empty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: 240,
                      child: SearchField(
                        height: 40,
                        radius: 999,
                        fontSize: 13,
                        hint: 'Filtruj historię',
                        onChanged: history.filter,
                      ),
                    ),
                    PillButton(
                      label: 'Wyczyść historię',
                      tone: ButtonTone.danger,
                      height: 40,
                      radius: 999,
                      fontSize: 13,
                      padding: 14,
                      onPressed: () => confirmClear(context, history),
                    ),
                  ],
                ),
            ],
          );
        } else {
          header = Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text('Historia', style: heading(30, height: 1.1)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ostatnio słuchane stacje',
                      style: TextStyle(fontSize: 13, color: rc.mu),
                    ),
                  ],
                ),
              ),
              if (!empty)
                IconBox(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Wyczyść historię',
                  onPressed: () => confirmClear(context, history),
                ),
            ],
          );
        }

        final slivers = <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, top, side, 0),
            sliver: SliverToBoxAdapter(child: header),
          ),
        ];

        if (empty) {
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 24),
              sliver: const SliverToBoxAdapter(
                child: EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Historia jest pusta',
                  message: 'Stacje, których posłuchasz, pojawią się tutaj.',
                ),
              ),
            ),
          );
        } else {
          final top = history.top(wide ? 4 : 3);
          if (top.isNotEmpty && history.query.trim().isEmpty) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Najczęściej w tym tygodniu'),
                      SizedBox(height: wide ? 12 : 10),
                      wide
                          ? _TopGridWide(top: top, queue: queue)
                          : _TopGridMobile(top: top, queue: queue),
                    ],
                  ),
                ),
              ),
            );
          }
          if (groups.isEmpty) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side, vertical: 16),
                sliver: const SliverToBoxAdapter(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Brak wyników',
                    message: 'Żadna stacja w historii nie pasuje do filtra.',
                  ),
                ),
              ),
            );
          }
          var k = 0;
          for (final group in groups) {
            final rows = <Widget>[
              for (final entry in group.entries)
                Rise(
                  index: k++,
                  child: wide
                      ? _WideRow(
                          entry: entry,
                          queue: queue,
                          showDuration: width >= 720,
                        )
                      : _MobileRow(entry: entry, queue: queue),
                ),
            ];
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(side, 24, side, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionLabel(group.label),
                      SizedBox(height: wide ? 10 : 6),
                      if (wide) Group(children: rows) else ...rows,
                    ],
                  ),
                ),
              ),
            );
          }
        }
        slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottom)));
        return CustomScrollView(slivers: slivers);
      },
    );
  }
}

class _TopGridMobile extends ConsumerWidget {
  const _TopGridMobile({required this.top, required this.queue});
  final List<TopStation> top;
  final List<Station> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) const SizedBox(width: 10),
        Expanded(
          child: i < top.length
              ? Rise(
                  index: i,
                  child: HoverCard(
                    padding: const EdgeInsets.all(8),
                    radius: 18,
                    semanticLabel: 'Odtwórz ${top[i].station.name}',
                    onTap: () => playFrom(
                      ref,
                      top[i].station,
                      queue: queue,
                      source: 'Historii',
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StationTile(
                          station: top[i].station,
                          width: double.infinity,
                          height: 72,
                          radius: 12,
                          fontSize: 18,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            top[i].station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ],
  );
}

class _TopGridWide extends ConsumerWidget {
  const _TopGridWide({required this.top, required this.queue});
  final List<TopStation> top;
  final List<Station> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 260).ceil().clamp(1, 4);
        final itemWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (i, t) in top.indexed)
              SizedBox(
                width: itemWidth,
                child: Rise(
                  index: i,
                  child: HoverCard(
                    padding: const EdgeInsets.all(10),
                    radius: 18,
                    semanticLabel: 'Odtwórz ${t.station.name}',
                    onTap: () => playFrom(
                      ref,
                      t.station,
                      queue: queue,
                      source: 'Historii',
                    ),
                    child: Row(
                      children: [
                        StationTile(
                          station: t.station,
                          width: 52,
                          radius: 14,
                          fontSize: 13,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.station.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                listenDuration(t.listened),
                                style: monoStyle(11, color: rc.mu),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MobileRow extends ConsumerWidget {
  const _MobileRow({required this.entry, required this.queue});
  final HistoryEntry entry;
  final List<Station> queue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final rc = context.rc;
    final station = entry.station;
    final open = history.isOpen(entry);
    return Row(
      children: [
        Expanded(
          child: Tappable(
            onTap: () => openStation(context, station),
            pressScale: 0.985,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  StationTile(
                    station: station,
                    width: 44,
                    radius: 13,
                    fontSize: 12,
                  ),
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
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: clock(entry.start),
                                style: monoStyle(12),
                              ),
                              TextSpan(
                                text:
                                    ' · ${open ? 'teraz' : listenDuration(history.listened(entry))}',
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: rc.mu),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconBox(
          icon: Icons.play_circle_outline_rounded,
          tooltip: 'Odtwórz ponownie ${station.name}',
          ghost: true,
          iconSize: 22,
          color: rc.act,
          onPressed: () =>
              playFrom(ref, station, queue: queue, source: 'Historii'),
        ),
      ],
    );
  }
}

class _WideRow extends ConsumerWidget {
  const _WideRow({
    required this.entry,
    required this.queue,
    required this.showDuration,
  });
  final HistoryEntry entry;
  final List<Station> queue;
  final bool showDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final rc = context.rc;
    final station = entry.station;
    final open = history.isOpen(entry);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => openStation(context, station),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    clock(entry.start),
                    style: monoStyle(13, color: rc.mu),
                  ),
                ),
                const SizedBox(width: 16),
                StationTile(
                  station: station,
                  width: 40,
                  radius: 12,
                  fontSize: 11,
                ),
                const SizedBox(width: 16),
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
                      const SizedBox(height: 2),
                      Text(
                        tagLine(station),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: rc.mu),
                      ),
                    ],
                  ),
                ),
                if (showDuration) ...[
                  const SizedBox(width: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 110),
                    child: Text(
                      open
                          ? 'słuchasz teraz'
                          : listenDuration(history.listened(entry)),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        color: open ? rc.act : rc.mu,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                IconBox(
                  icon: Icons.play_circle_outline_rounded,
                  tooltip: 'Odtwórz ponownie ${station.name}',
                  ghost: true,
                  iconSize: 22,
                  color: rc.act,
                  onPressed: () =>
                      playFrom(ref, station, queue: queue, source: 'Historii'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
