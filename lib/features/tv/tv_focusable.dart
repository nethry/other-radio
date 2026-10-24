import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/localization.dart';
import 'tv_theme.dart';

/// The single remote-focusable primitive (`OrFocusable`). It owns focus,
/// press and semantics; [builder] draws the focused/pressed visuals.
///
/// OK fires on key-up so a hold can be told apart from a press: holding OK
/// for [TvMotion.longPress], or pressing the Menu key, calls [onLongPress].
class TvFocusable extends StatefulWidget {
  const TvFocusable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
    this.selected,
    this.reveal = true,
    this.onFocusChange,
  });

  final Widget Function(BuildContext context, bool focused, bool pressed)
  builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Localized source key read by screen readers.
  final String? semanticLabel;
  final bool? selected;

  /// Scroll into view when focused. Rows and grids that manage their own
  /// scrolling turn this off.
  final bool reveal;
  final ValueChanged<bool>? onFocusChange;

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

final _selectKeys = {
  LogicalKeyboardKey.select,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
  LogicalKeyboardKey.gameButtonA,
};

class _TvFocusableState extends State<TvFocusable> {
  FocusNode? _own;
  FocusNode get _node =>
      widget.focusNode ??
      (_own ??= FocusNode(debugLabel: widget.semanticLabel));
  bool _focused = false;
  bool _pressed = false;

  /// OK went down on this control (a stray key-up from a hold elsewhere is
  /// ignored).
  bool _down = false;
  bool _held = false;
  Timer? _hold;

  @override
  void dispose() {
    _hold?.cancel();
    _own?.dispose();
    super.dispose();
  }

  void _reset() {
    _hold?.cancel();
    _down = false;
    _held = false;
    if (_pressed) setState(() => _pressed = false);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.contextMenu && widget.onLongPress != null) {
      if (event is KeyDownEvent) widget.onLongPress!();
      return KeyEventResult.handled;
    }
    if (!_selectKeys.contains(key) ||
        (widget.onTap == null && widget.onLongPress == null)) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent():
        _hold?.cancel();
        _down = true;
        _held = false;
        setState(() => _pressed = true);
        final hold = widget.onLongPress;
        if (hold != null) {
          _hold = Timer(TvMotion.longPress, () {
            if (!mounted || !_down) return;
            _held = true;
            setState(() => _pressed = false);
            hold();
          });
        }
      case KeyRepeatEvent():
        if (!_down) return KeyEventResult.ignored;
      case KeyUpEvent():
        if (!_down) return KeyEventResult.ignored;
        final tap = !_held;
        _reset();
        if (tap) widget.onTap?.call();
    }
    return KeyEventResult.handled;
  }

  void _onFocus(bool focused) {
    if (!focused) _reset();
    setState(() => _focused = focused);
    widget.onFocusChange?.call(focused);
    if (focused && widget.reveal) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        duration: TvMotion.of(context, TvMotion.screen),
        curve: TvMotion.outCurve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onFocusChange: _onFocus,
      onKeyEvent: _onKey,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap == null
            ? null
            : () {
                _node.requestFocus();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: widget.builder(context, _focused, _pressed),
      ),
    );
    if (widget.semanticLabel != null || widget.selected != null) {
      result = Semantics(
        button: widget.onTap != null,
        label: widget.semanticLabel == null
            ? null
            : context.tr(widget.semanticLabel!),
        selected: widget.selected,
        excludeSemantics: widget.semanticLabel != null,
        child: result,
      );
    }
    return result;
  }
}

/// Focus/press scale (`1.08` cards, `1.06` buttons, `1.10` icons).
class TvScale extends StatelessWidget {
  const TvScale({
    super.key,
    required this.focused,
    required this.pressed,
    required this.child,
    this.scale = 1.06,
    this.pressedScale = 0.97,
  });
  final bool focused;
  final bool pressed;
  final double scale;
  final double pressedScale;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed
        ? pressedScale
        : focused
        ? scale
        : 1,
    duration: TvMotion.of(context, pressed ? TvMotion.press : TvMotion.focus),
    curve: pressed ? Curves.easeOut : TvMotion.focusCurve,
    child: child,
  );
}
