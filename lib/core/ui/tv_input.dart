import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: MediaQuery.textScalerOf(context)
                          .clamp(minScaleFactor: 1.15),
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
  );
}
