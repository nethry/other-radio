import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../common.dart';
import '../history/history_screen.dart';
import '../player/mini_player.dart';
import '../player/now_panel.dart';
import '../settings/settings_screen.dart';
import '../stations/browse_screen.dart';
import '../stations/favorites_screen.dart';
import '../stations/search_screen.dart';
import '../stations/station_controller.dart';

typedef _Destination = ({AppPage page, String label, IconData icon});

const _destinations = <_Destination>[
  (page: AppPage.browse, label: 'Przeglądaj', icon: Icons.grid_view_rounded),
  (page: AppPage.search, label: 'Szukaj', icon: Icons.search_rounded),
  (
    page: AppPage.favorites,
    label: 'Ulubione',
    icon: Icons.favorite_border_rounded,
  ),
  (page: AppPage.history, label: 'Historia', icon: Icons.history_rounded),
  (page: AppPage.settings, label: 'Ustawienia', icon: Icons.settings_outlined),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _root = FocusNode(debugLabel: 'shell');

  @override
  void initState() {
    super.initState();
    // Start recording listening history from launch, not first visit.
    ref.read(historyProvider);
    Future.microtask(() {
      if (mounted) ref.read(stationsProvider).refresh();
    });
  }

  @override
  void dispose() {
    _root.dispose();
    super.dispose();
  }

  /// Space toggles playback only when no control or text field has focus,
  /// so it never steals activation from a focused button.
  bool get _nothingFocused {
    final focus = FocusManager.instance.primaryFocus;
    return focus == null || focus == _root || focus is FocusScopeNode;
  }

  void _playFavorite(int index) {
    final catalogue = ref.read(stationsProvider);
    final favorites = catalogue.sortedFavorites(
      ref.read(historyProvider).lastPlayed,
    );
    if (index < favorites.length) {
      playFrom(ref, favorites[index], queue: favorites, source: 'Ulubionych');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(stationsProvider.select((c) => c.page));
    final hasStation = ref.watch(
      playbackProvider.select((p) => p.state.station != null),
    );
    final player = ref.read(playbackProvider);
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.space): _ToggleIntent(),
      },
      child: Actions(
        actions: {
          _ToggleIntent: _ToggleAction(
            enabled: () => _nothingFocused && hasStation,
            run: () => unawaited(ref.read(playbackProvider).toggle()),
          ),
        },
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(
              LogicalKeyboardKey.arrowRight,
              control: true,
            ): () =>
                unawaited(player.next()),
            const SingleActivator(
              LogicalKeyboardKey.arrowLeft,
              control: true,
            ): () =>
                unawaited(player.previous()),
            const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
                ref.read(stationsProvider).navigate(AppPage.search),
            for (var i = 0; i < 9; i++)
              SingleActivator(
                LogicalKeyboardKey(LogicalKeyboardKey.digit1.keyId + i),
                control: true,
              ): () =>
                  _playFavorite(i),
          },
          child: Focus(
            focusNode: _root,
            autofocus: true,
            child: LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < Breakpoints.sidebar
                  ? _compact(page, hasStation)
                  : _wide(constraints.maxWidth, page, hasStation),
            ),
          ),
        ),
      ),
    );
  }

  Widget _compact(AppPage page, bool hasStation) {
    final rc = context.rc;
    return Scaffold(
      body: ShellInsets(
        bottom: hasStation ? 100 : 12,
        child: Stack(
          children: [
            Positioned.fill(child: _Pages(page: page)),
            if (hasStation) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 120,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [rc.bg, rc.bg.withValues(alpha: 0)],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: MiniPlayer(),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _TabBar(page: page),
    );
  }

  Widget _wide(double width, AppPage page, bool hasStation) {
    final panel = width >= Breakpoints.nowPanel;
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: width >= 1000 ? 256 : 220, child: _Sidebar(page)),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ShellInsets(bottom: 0, child: _Pages(page: page)),
                  ),
                  if (!panel && hasStation)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: MiniPlayer(docked: true),
                    ),
                ],
              ),
            ),
            if (panel)
              SizedBox(
                width: width >= 1400 ? 380 : 340,
                child: const NowPanel(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToggleIntent extends Intent {
  const _ToggleIntent();
}

class _ToggleAction extends Action<_ToggleIntent> {
  _ToggleAction({required this.enabled, required this.run});
  final bool Function() enabled;
  final VoidCallback run;

  @override
  bool isEnabled(_ToggleIntent intent) => enabled();

  @override
  Object? invoke(_ToggleIntent intent) {
    run();
    return null;
  }
}

class _Pages extends StatelessWidget {
  const _Pages({required this.page});
  final AppPage page;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: context.calm ? Duration.zero : const Duration(milliseconds: 220),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: KeyedSubtree(
      key: ValueKey(page),
      child: switch (page) {
        AppPage.browse => const BrowseScreen(),
        AppPage.search => const SearchScreen(),
        AppPage.favorites => const FavoritesScreen(),
        AppPage.history => const HistoryScreen(),
        AppPage.settings => const SettingsScreen(),
      },
    ),
  );
}

/// Bottom navigation (`MobileTabBar.dc.html`).
class _TabBar extends ConsumerWidget {
  const _TabBar({required this.page});
  final AppPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    return Semantics(
      container: true,
      label: 'Główna nawigacja',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: rc.bar,
          border: Border(top: BorderSide(color: rc.bd)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final d in _destinations)
                  Expanded(
                    child: _Tab(
                      key: ValueKey('nav-${d.page.name}'),
                      destination: d,
                      selected: d.page == page,
                      onTap: () => ref.read(stationsProvider).navigate(d.page),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final color = selected ? rc.act : rc.mu;
    final icon = selected && destination.page == AppPage.favorites
        ? Icons.favorite_rounded
        : destination.icon;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: Tappable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: context.calm
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              child: Container(
                width: 28,
                height: 3,
                decoration: BoxDecoration(
                  color: rc.ac,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  Icon(icon, size: 22, color: color),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      destination.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: color,
                      ),
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
}

/// Desktop sidebar (`DesktopSidebar.dc.html`).
class _Sidebar extends ConsumerWidget {
  const _Sidebar(this.page);
  final AppPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final catalogue = ref.watch(stationsProvider);
    final settings = ref.watch(settingsProvider);
    final playback = ref.watch(playbackProvider);
    final favorites = catalogue.favorites.take(6).toList();
    final brightness = switch (settings.themeMode) {
      ThemeMode.dark => ThemeMode.dark,
      ThemeMode.light => ThemeMode.light,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rc.panel,
        border: Border(right: BorderSide(color: rc.bd)),
      ),
      child: CustomScrollView(
        slivers: [
          // Padding inside the fill: a SliverPadding around it would add its
          // insets to the viewport height and always make the sidebar scroll.
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Brand(size: 21),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Semantics(
                    container: true,
                    label: 'Główna nawigacja',
                    child: Column(
                      children: [
                        for (final d in _destinations)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: _NavItem(
                              key: ValueKey('nav-${d.page.name}'),
                              destination: d,
                              selected: d.page == page,
                              onTap: () => catalogue.navigate(d.page),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (favorites.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: SectionLabel('Ulubione'),
                    ),
                    for (final s in favorites)
                      Tappable(
                        onTap: () => playFrom(
                          ref,
                          s,
                          queue: catalogue.favorites,
                          source: 'Ulubionych',
                        ),
                        borderRadius: BorderRadius.circular(12),
                        semanticLabel: 'Odtwórz ${s.name}',
                        child: SizedBox(
                          height: 48,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                StationTile(
                                  station: s,
                                  width: 30,
                                  radius: 9,
                                  fontSize: 9,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    s.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: rc.tx2,
                                    ),
                                  ),
                                ),
                                if (isPlaying(playback.state, s))
                                  Eq(
                                    color: rc.act,
                                    playing: playback.state.active,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                  const Spacer(),
                  const SizedBox(height: 24),
                  Segmented<ThemeMode>(
                    semanticLabel: 'Motyw',
                    iconOnly: true,
                    options: const [
                      (
                        value: ThemeMode.dark,
                        label: 'Ciemny',
                        icon: Icons.dark_mode_outlined,
                      ),
                      (
                        value: ThemeMode.light,
                        label: 'Jasny',
                        icon: Icons.light_mode_outlined,
                      ),
                    ],
                    selected: brightness,
                    onChanged: settings.setThemeMode,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final icon = selected && destination.page == AppPage.favorites
        ? Icons.favorite_rounded
        : destination.icon;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      excludeSemantics: true,
      child: Tappable(
        onTap: onTap,
        pressScale: 0.98,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: context.calm
              ? Duration.zero
              : const Duration(milliseconds: 200),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? rc.navOn : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? rc.shadowSm : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? rc.act : rc.tx2),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? rc.tx : rc.tx2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
