import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/tv/tv_overlays.dart';

/// Remote input support covers Navigator routes, dialogs and country pickers.
/// TV detection changes input affordances only; pages retain width breakpoints.
class TvInput extends InheritedWidget {
  const TvInput({super.key, required this.enabled, required super.child});
  final bool enabled;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TvInput>()?.enabled ?? false;

  @override
  bool updateShouldNotify(TvInput oldWidget) => enabled != oldWidget.enabled;
}

/// Wraps every route on Android TV: Select/A activate the focused control,
/// arrows move spatially, and short confirmations appear above all routes.
/// The TV pages (`features/tv/`) apply their own overscan-safe margins and
/// TV-sized type, so nothing is padded or rescaled here.
class TelevisionFrame extends StatelessWidget {
  const TelevisionFrame({
    super.key,
    required this.enabled,
    required this.child,
  });
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => TvInput(
    enabled: enabled,
    child: !enabled
        ? child
        : Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
            },
            child: FocusTraversalGroup(
              policy: ReadingOrderTraversalPolicy(),
              child: TvToastHost(child: child),
            ),
          ),
  );
}
