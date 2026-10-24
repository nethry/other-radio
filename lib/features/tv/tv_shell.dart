import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/ui/motion.dart';
import '../stations/station_controller.dart';
import 'tv_discover.dart';
import 'tv_favorites.dart';
import 'tv_focusable.dart';
import 'tv_history.dart';
import 'tv_overlays.dart';
import 'tv_player.dart';
import 'tv_search.dart';
import 'tv_settings.dart';
import 'tv_theme.dart';

typedef _Section = ({AppPage? page, String label, IconData icon});

/// Rail order from the canvas: "Teraz gra" is the second way to the player.
const _sections = <_Section>[
  (page: null, label: 'Teraz gra', icon: Icons.play_circle_outline_rounded),
  (page: AppPage.browse, label: 'Odkrywaj', icon: Icons.explore_outlined),
  (page: AppPage.search, label: 'Szukaj', icon: Icons.search_rounded),
  (
    page: AppPage.favorites,
    label: 'Ulubione',
    icon: Icons.favorite_border_rounded,
  ),
  (page: AppPage.history, label: 'Historia', icon: Icons.history_rounded),
  (page: AppPage.settings, label: 'Ustawienia', icon: Icons.tune_rounded),
];

/// Android TV shell: collapsible nav rail over full-width pages.
///
/// Back stack: page-specific handlers first (e.g. Discover jumps back to its
/// hero), then the rail opens on the current section, and Back on the rail
/// asks before closing the app. Only that dialog's "Zamknij" stops audio.
class TvShell extends ConsumerStatefulWidget {
  const TvShell({super.key});

  @override
  ConsumerState<TvShell> createState() => _TvShellState();
}

/// Lets pages open the rail and claim Back before the shell does.
class TvShellScope extends InheritedWidget {
  const TvShellScope._(this._shell, {required super.child});
  final _TvShellState _shell;

  static _TvShellState? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvShellScope>()?._shell;

  /// Opens the rail with focus on the current section.
  static void openRail(BuildContext context) => _of(context)?.openRail();

  @override
  bool updateShouldNotify(TvShellScope oldWidget) => false;
}

/// Registers [onBack] while mounted; it returns true when it consumed Back.
class TvBackHandler extends StatefulWidget {
  const TvBackHandler({super.key, required this.onBack, required this.child});
  final bool Function() onBack;
  final Widget child;

  @override
  State<TvBackHandler> createState() => _TvBackHandlerState();
}

class _TvBackHandlerState extends State<TvBackHandler> {
  _TvShellState? _shell;

  bool _handle() => widget.onBack();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shell = TvShellScope._of(context);
    if (shell != _shell) {
      _shell?._backHandlers.remove(_handle);
      _shell = shell?.._backHandlers.add(_handle);
    }
  }

  @override
  void dispose() {
    _shell?._backHandlers.remove(_handle);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TvShellState extends ConsumerState<TvShell> {
  final _content = FocusScopeNode(debugLabel: 'tv content');
  final _rail = FocusScopeNode(debugLabel: 'tv rail');
  final _railItems = [
    for (final s in _sections) FocusNode(debugLabel: 'rail ${s.label}'),
  ];
  final _backHandlers = <bool Function()>[];
  bool _railOpen = false;

  @override
  void initState() {
    super.initState();
    _content.onKeyEvent = _contentKeys;
    _rail.onKeyEvent = _railKeys;
    _rail.addListener(_railFocus);
    // A page without focusable content yet (loading) still takes the remote.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_content.hasFocus && !_rail.hasFocus) {
        _content.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _rail.removeListener(_railFocus);
    _content.dispose();
    _rail.dispose();
    for (final node in _railItems) {
      node.dispose();
    }
    super.dispose();
  }

  void _railFocus() {
    if (_rail.hasFocus != _railOpen) setState(() => _railOpen = _rail.hasFocus);
  }

  int get _current {
    final page = ref.read(stationsProvider).page;
    return _sections.indexWhere((s) => s.page == page);
  }

  void openRail() => _railItems[_current].requestFocus();

  void _closeRail() => _content.requestFocus();

  static final _directions = {
    LogicalKeyboardKey.arrowLeft: TraversalDirection.left,
    LogicalKeyboardKey.arrowRight: TraversalDirection.right,
    LogicalKeyboardKey.arrowUp: TraversalDirection.up,
    LogicalKeyboardKey.arrowDown: TraversalDirection.down,
  };

  /// Arrows that no row/grid handled move spatially inside the content; ←
  /// with nothing further left opens the rail.
  KeyEventResult _contentKeys(FocusNode _, KeyEvent event) {
    final direction = _directions[event.logicalKey];
    if (event is KeyUpEvent || direction == null) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus;
    final moved =
        focus != null && focus != _content && focus.focusInDirection(direction);
    if (!moved && direction == TraversalDirection.left) openRail();
    return KeyEventResult.handled;
  }

  KeyEventResult _railKeys(FocusNode _, KeyEvent event) {
    final direction = _directions[event.logicalKey];
    if (event is KeyUpEvent || direction == null) return KeyEventResult.ignored;
    switch (direction) {
      case TraversalDirection.up || TraversalDirection.down:
        FocusManager.instance.primaryFocus?.focusInDirection(direction);
      case TraversalDirection.right:
        _closeRail();
      case TraversalDirection.left:
        break;
    }
    return KeyEventResult.handled;
  }

  void _select(int index) {
    final section = _sections[index];
    final page = section.page;
    if (page == null) {
      if (ref.read(playbackProvider).state.station == null) {
        TvToast.show(context, context.tr('Wybierz stację'));
      } else {
        openTvPlayer(context);
      }
      return;
    }
    final catalogue = ref.read(stationsProvider);
    if (catalogue.page == page) {
      _closeRail();
    } else {
      // The new page's default item autofocuses, which collapses the rail.
      catalogue.navigate(page);
    }
  }

  Future<void> _back() async {
    if (_rail.hasFocus) {
      await _confirmExit();
      return;
    }
    for (final handler in _backHandlers.reversed.toList()) {
      if (handler()) return;
    }
    openRail();
  }

  Future<void> _confirmExit() async {
    final player = ref.read(playbackProvider);
    final station = player.state.station;
    final close = await confirmTv(
      context,
      title: 'Zamknąć OtherRadio?',
      message: station != null && player.state.active
          ? '${context.tr('Odtwarzanie zostanie zatrzymane')}: ${station.name}'
          : null,
      cancel: 'Zostań',
      cancelPrimary: true,
      confirm: 'Zamknij',
    );
    if (!close) return;
    await player.stop();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(stationsProvider.select((c) => c.page));
    final current = _sections.indexWhere((s) => s.page == page);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: TvShellScope._(
        this,
        child: Scaffold(
          backgroundColor: context.tv.bg,
          body: Stack(
            children: [
              Positioned(
                right: -60,
                top: 20,
                width: 450,
                height: 350,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          context.tv.accentDeep.withValues(alpha: 0.14),
                          context.tv.accentDeep.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: FocusScope(
                  node: _content,
                  child: _Page(page: page),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _railOpen ? 1 : 0,
                    duration: TvMotion.of(context, TvMotion.screen),
                    child: const ColoredBox(color: Color(0x9905080B)),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: FocusScope(
                  node: _rail,
                  child: _Rail(
                    open: _railOpen,
                    current: current,
                    nodes: _railItems,
                    onSelect: _select,
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

/// The current page, entering with a fade and 12 dp rise. The previous page
/// is removed at once so its focus nodes never compete with the new page's
/// default item.
class _Page extends StatelessWidget {
  const _Page({required this.page});
  final AppPage page;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(page),
    tween: Tween(begin: 0, end: 1),
    duration: TvMotion.of(context, TvMotion.screen),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    ),
    child: switch (page) {
      AppPage.browse => const TvDiscover(),
      AppPage.search => const TvSearch(),
      AppPage.favorites => const TvFavorites(),
      AppPage.history => const TvHistory(),
      AppPage.settings => const TvSettings(),
    },
  );
}

class _Rail extends ConsumerWidget {
  const _Rail({
    required this.open,
    required this.current,
    required this.nodes,
    required this.onSelect,
  });
  final bool open;
  final int current;
  final List<FocusNode> nodes;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(playbackProvider.select((p) => p.state));
    return Semantics(
      container: true,
      label: context.tr('Główna nawigacja'),
      explicitChildNodes: true,
      child: AnimatedContainer(
        duration: TvMotion.of(
          context,
          open ? TvMotion.screen : TvMotion.railClose,
        ),
        curve: TvMotion.outCurve,
        width: open ? TvLayout.railOpen : TvLayout.railCollapsed,
        padding: const EdgeInsets.fromLTRB(32, TvLayout.safeY, 0, 0),
        decoration: BoxDecoration(
          color: open ? context.tv.bg2 : null,
          gradient: open
              ? null
              : LinearGradient(
                  colors: [
                    context.tv.bg,
                    context.tv.bg,
                    context.tv.bg.withValues(alpha: 0),
                  ],
                  stops: [0, 0.7, 1],
                ),
          boxShadow: open
              ? const [
                  BoxShadow(
                    color: Color(0x80000000),
                    blurRadius: 40,
                    offset: Offset(20, 0),
                  ),
                ]
              : null,
        ),
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            maxWidth: TvLayout.railOpen - 32,
            minWidth: TvLayout.railOpen - 32,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 48,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 13),
                    child: Row(
                      children: [
                        Icon(
                          Icons.graphic_eq_rounded,
                          size: 24,
                          color: context.tv.accent,
                        ),
                        const SizedBox(width: 8),
                        AnimatedOpacity(
                          opacity: open ? 1 : 0,
                          duration: TvMotion.of(context, TvMotion.focus),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'other',
                                  style: tvHeading(20, weight: 700),
                                ),
                                TextSpan(
                                  text: 'radio',
                                  style: tvHeading(
                                    20,
                                    color: context.tv.accent,
                                  ).copyWith(fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                for (final (i, section) in _sections.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _RailItem(
                      section: section,
                      node: nodes[i],
                      open: open,
                      current: i == current,
                      playing: i == 0 && state.active,
                      onTap: () => onSelect(i),
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.section,
    required this.node,
    required this.open,
    required this.current,
    required this.playing,
    required this.onTap,
  });
  final _Section section;
  final FocusNode node;
  final bool open;
  final bool current;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: node,
    reveal: false,
    onTap: onTap,
    semanticLabel: section.label,
    selected: current,
    builder: (context, focused, pressed) {
      final color = focused
          ? context.tv.bg
          : current
          ? context.tv.accent
          : context.tv.muted;
      return TvScale(
        focused: focused,
        pressed: pressed,
        scale: 1.04,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.screen),
          curve: TvMotion.outCurve,
          width: open ? 170 : 48,
          height: 40,
          decoration: BoxDecoration(
            color: focused ? context.tv.text : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                if (current && !focused)
                  Positioned(
                    left: 3,
                    top: 14,
                    child: Container(
                      width: 3,
                      height: 12,
                      decoration: BoxDecoration(
                        color: context.tv.accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  top: 10,
                  child: Icon(section.icon, size: 20, color: color),
                ),
                Positioned(
                  left: 45,
                  top: 0,
                  bottom: 0,
                  width: 120,
                  child: AnimatedOpacity(
                    opacity: open ? 1 : 0,
                    // Labels fade in after the width starts growing so text
                    // never clips mid-animation.
                    duration: TvMotion.of(
                      context,
                      const Duration(milliseconds: 240),
                    ),
                    curve: const Interval(0.33, 1),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.tr(section.label),
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: tvBody(13, color: color),
                          ),
                        ),
                        if (playing)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Eq(
                              color: focused
                                  ? context.tv.bg
                                  : context.tv.accent,
                              height: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
