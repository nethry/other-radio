import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/common.dart';
import '../providers.dart';

/// Runs before focused buttons consume Space. Text editing and modal controls
/// keep their normal keyboard behavior, and TV keeps D-pad/OK activation.
class AppShortcuts extends ConsumerStatefulWidget {
  const AppShortcuts({
    super.key,
    required this.enabled,
    required this.navigatorKey,
    required this.child,
  });
  final bool enabled;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  ConsumerState<AppShortcuts> createState() => _AppShortcutsState();
}

class _AppShortcutsState extends ConsumerState<AppShortcuts> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleKey);
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleKey);
    super.dispose();
  }

  KeyEventResult _handleKey(KeyEvent event) {
    if (!widget.enabled || event is KeyUpEvent) return KeyEventResult.ignored;
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext != null && ModalRoute.of(focusContext) is PopupRoute) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isAltPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final control = keyboard.isControlPressed;
    final editing =
        focusContext?.findAncestorStateOfType<EditableTextState>() != null;
    // Ctrl+K intentionally focuses Search even when another text field is active.
    if (control && key == LogicalKeyboardKey.keyK) {
      if (event is KeyDownEvent) {
        widget.navigatorKey.currentState?.popUntil((route) => route.isFirst);
        ref.read(stationsProvider).focusSearch();
      }
      return KeyEventResult.handled;
    }
    if (editing) return KeyEventResult.ignored;
    final player = ref.read(playbackProvider);
    VoidCallback? action;
    if (!control &&
        key == LogicalKeyboardKey.space &&
        player.state.station != null) {
      action = player.toggle;
    } else if (control && key == LogicalKeyboardKey.arrowRight) {
      action = player.next;
    } else if (control && key == LogicalKeyboardKey.arrowLeft) {
      action = player.previous;
    } else if (control) {
      final index = key.keyId - LogicalKeyboardKey.digit1.keyId;
      if (index >= 0 && index < 9) {
        final catalogue = ref.read(stationsProvider);
        final favorites = catalogue.sortedFavorites(
          ref.read(historyProvider).lastPlayed,
        );
        if (index < favorites.length) {
          action = () => playFrom(
            ref,
            favorites[index],
            queue: favorites,
            source: 'Ulubionych',
          );
        }
      }
    }
    if (action == null) return KeyEventResult.ignored;
    // Holding a key must not rapidly alternate play/pause or skip many stations.
    if (event is KeyDownEvent) action();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
