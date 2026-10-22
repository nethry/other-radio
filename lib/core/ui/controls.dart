import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../localization.dart';
import 'tv_input.dart';

/// Ink + focus + a slight press scale (`:active { transform: scale(.96) }`).
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.shape,
    this.pressScale = 0.96,
    this.tooltip,
    this.semanticLabel,
    this.selected,
    this.focusNode,
    this.autofocus = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final ShapeBorder? shape;
  final double pressScale;
  final String? tooltip;
  final String? semanticLabel;
  final bool? selected;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final focusShape = widget.shape is OutlinedBorder
        ? widget.shape! as OutlinedBorder
        : RoundedRectangleBorder(borderRadius: widget.borderRadius);
    Widget result = AnimatedScale(
      scale: _down && !context.calm ? widget.pressScale : 1,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onFocusChange: (focused) => setState(() => _focused = focused),
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => _down = v),
          borderRadius: widget.shape == null ? widget.borderRadius : null,
          customBorder: widget.shape,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: focusShape.copyWith(
                side: BorderSide(
                  color:
                      _focused &&
                          (TvInput.of(context) ||
                              FocusManager.instance.highlightMode ==
                                  FocusHighlightMode.traditional)
                      ? context.rc.act
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
    if (widget.semanticLabel != null || widget.selected != null) {
      result = Semantics(
        button: true,
        label: widget.semanticLabel == null
            ? null
            : context.tr(widget.semanticLabel!),
        selected: widget.selected,
        excludeSemantics: widget.semanticLabel != null,
        child: result,
      );
    }
    if (widget.tooltip != null) {
      result = Tooltip(message: context.tr(widget.tooltip!), child: result);
    }
    return result;
  }
}

/// Square icon button (`.ib`, `.ib.ghost`, `.ib.round`).
class IconBox extends StatelessWidget {
  const IconBox({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.ghost = false,
    this.round = false,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    this.radius = 14,
    this.selected,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool ghost;
  final bool round;
  final double size;
  final double iconSize;
  final Color? color;
  final double radius;
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final shape = round
        ? const CircleBorder()
        : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return Tappable(
      onTap: onPressed,
      shape: shape,
      tooltip: tooltip,
      semanticLabel: tooltip,
      selected: selected,
      child: Ink(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: ghost ? Colors.transparent : rc.sf,
          shadows: ghost ? null : rc.shadowSm,
          shape: round
              ? CircleBorder(
                  side: BorderSide(color: ghost ? Colors.transparent : rc.bd),
                )
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radius),
                  side: BorderSide(color: ghost ? Colors.transparent : rc.bd),
                ),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: onPressed == null ? rc.dim : color ?? (ghost ? rc.mu : rc.tx),
        ),
      ),
    );
  }
}

/// Accent play/pause button with a soft accent shadow.
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.playing,
    required this.onPressed,
    this.size = 80,
    this.radius = 28,
    this.iconSize = 32,
    this.busy = false,
    this.glow = true,
  });
  final bool playing;
  final bool busy;
  final VoidCallback? onPressed;
  final double size;
  final double radius;
  final double iconSize;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    // The glow sits outside the ink layer, which would clip its blur.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: glow && onPressed != null
            ? [
                BoxShadow(
                  color: rc.ac.withValues(alpha: 0.35),
                  blurRadius: size * 0.45,
                  offset: Offset(0, size * 0.2),
                ),
              ]
            : null,
      ),
      child: Tappable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        tooltip: playing ? 'Wstrzymaj' : 'Odtwórz',
        semanticLabel: playing ? 'Wstrzymaj' : 'Odtwórz',
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: onPressed == null ? rc.bd2 : rc.ac,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Center(
            child: busy
                ? SizedBox(
                    width: iconSize * 0.7,
                    height: iconSize * 0.7,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: rc.onAccent,
                    ),
                  )
                : Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: iconSize * 1.15,
                    color: rc.onAccent,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Pill chip (`.chip`, `.chip.sm`, `.chip.on`).
class RadioChip extends StatelessWidget {
  const RadioChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.small = false,
    this.dropdown = false,
    this.icon,
    this.height,
  });
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool small;
  final bool dropdown;
  final IconData? icon;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final fg = selected ? rc.onAccent : rc.tx2;
    final duration = context.calm
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      selected: selected,
      child: AnimatedContainer(
        duration: duration,
        height: height ?? (small ? 34 : 40),
        padding: EdgeInsets.symmetric(horizontal: small ? 12 : 16),
        decoration: BoxDecoration(
          color: selected ? rc.ac : rc.sf,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? rc.ac : rc.bd),
          boxShadow: rc.shadowSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: TrText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: small ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (dropdown) ...[
              const SizedBox(width: 4),
              Icon(Icons.expand_more_rounded, size: 16, color: fg),
            ],
          ],
        ),
      ),
    );
  }
}

enum ButtonTone { primary, secondary, danger }

/// Text button (`.btn`, `.btn.sec`, `.btn.danger`).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.onPressed,
    this.tone = ButtonTone.primary,
    this.height = 48,
    this.radius = 16,
    this.fontSize = 15,
    this.padding = 20,
  });
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onPressed;
  final ButtonTone tone;
  final double height;
  final double radius;
  final double fontSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final (bg, fg, border) = switch (tone) {
      ButtonTone.primary => (rc.ac, rc.onAccent, rc.ac),
      ButtonTone.secondary => (rc.sf, rc.tx, rc.bd),
      ButtonTone.danger => (Colors.transparent, rc.dangerText, rc.bd),
    };
    return Tappable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(radius),
      pressScale: 0.97,
      child: Ink(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: padding),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: fontSize + 4, color: iconColor ?? fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: TrText(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef SegmentOption<T> = ({T value, String label, IconData? icon});

/// Segmented control (`.seg`).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.semanticLabel,
    this.iconOnly = false,
  });
  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final String? semanticLabel;

  /// Shows only icons; labels become tooltips and screen-reader names.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final duration = context.calm
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Semantics(
      container: true,
      label: semanticLabel == null ? null : context.tr(semanticLabel!),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: rc.seg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: rc.bd),
        ),
        child: Row(
          children: [
            for (final (i, o) in options.indexed) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: Tappable(
                  onTap: () => onChanged(o.value),
                  borderRadius: BorderRadius.circular(10),
                  selected: o.value == selected,
                  tooltip: iconOnly ? o.label : null,
                  semanticLabel: iconOnly ? o.label : null,
                  child: AnimatedContainer(
                    duration: duration,
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: o.value == selected
                          ? rc.segOn
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: o.value == selected ? rc.shadowSm : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (o.icon != null) ...[
                          Icon(
                            o.icon,
                            size: iconOnly ? 18 : 16,
                            color: o.value == selected ? rc.tx : rc.mu,
                          ),
                          if (!iconOnly) const SizedBox(width: 6),
                        ],
                        if (!iconOnly)
                          Flexible(
                            child: TrText(
                              o.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: o.value == selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: o.value == selected ? rc.tx : rc.mu,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Toggle (`.sw`) with an overshooting thumb.
class RadioSwitch extends StatelessWidget {
  const RadioSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final duration = context.calm
        ? Duration.zero
        : const Duration(milliseconds: 300);
    return Semantics(
      toggled: value,
      label: context.tr(label),
      excludeSemantics: true,
      child: Tappable(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: duration,
          width: 52,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? rc.ac : rc.bd2,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: duration,
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded settings group (`.group`) with dividers between children.
class Group extends StatelessWidget {
  const Group({super.key, required this.children, this.padding});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: rc.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rc.bd),
        boxShadow: rc.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: rc.bd),
            child,
          ],
        ],
      ),
    );
  }
}

/// Row inside a [Group] (`.set`). With [stacked], the trailing control sits
/// below the text (used for segmented controls on narrow screens).
class SetRow extends StatelessWidget {
  const SetRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.stacked = false,
    this.minHeight = 64,
  });
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool stacked;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TrText(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          DefaultTextStyle.merge(
            style: TextStyle(fontSize: 12, color: rc.mu),
            child: subtitle!,
          ),
        ],
      ],
    );
    final content = ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: stacked
            ? const EdgeInsets.fromLTRB(16, 14, 16, 14)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [text, const SizedBox(height: 10), ?trailing],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  if (trailing != null) ...[
                    const SizedBox(width: 16),
                    trailing!,
                  ],
                ],
              ),
      ),
    );
    return onTap == null
        ? content
        : Material(
            type: MaterialType.transparency,
            child: InkWell(onTap: onTap, child: content),
          );
  }
}

/// Keyboard hint (`.kbd`).
class Kbd extends StatelessWidget {
  const Kbd(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: rc.bd2),
      ),
      child: TrText(text, style: monoStyle(11, color: rc.tx2)),
    );
  }
}

/// Small rounded tag (`.tag`).
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.icon, this.onTap});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tappable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: rc.hov,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: rc.tx2),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: rc.tx2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Uppercase section label (`.lbl`).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.size = 11});
  final String text;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      context.tr(text).toUpperCase(),
      style: labelStyle(context, size: size),
    ),
  );
}

/// Search input (`.field`) with an accent focus ring.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Szukaj stacji, miast, gatunków',
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.height = 52,
    this.radius = 16,
    this.fontSize = 15,
    this.autofocus = false,
    this.fieldKey,
    this.semanticLabel = 'Szukaj stacji',
  });
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final double height;
  final double radius;
  final double fontSize;
  final bool autofocus;
  final Key? fieldKey;
  final String semanticLabel;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _focus.removeListener(_changed);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: context.calm
          ? Duration.zero
          : const Duration(milliseconds: 200),
      height: widget.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: rc.sf,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: focused ? rc.ac : rc.bd),
        boxShadow: focused
            ? [BoxShadow(color: rc.ac.withValues(alpha: 0.22), spreadRadius: 4)]
            : rc.shadowSm,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: rc.mu),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              textInputAction: TextInputAction.search,
              style: TextStyle(fontSize: widget.fontSize, color: rc.tx),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: context.tr(widget.hint),
                hintStyle: TextStyle(fontSize: widget.fontSize, color: rc.mu),
              ),
              inputFormatters: [LengthLimitingTextInputFormatter(80)],
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}

/// Field look-alike that opens search when tapped.
class SearchLink extends StatelessWidget {
  const SearchLink({
    super.key,
    required this.onTap,
    this.height = 52,
    this.fontSize = 15,
    this.trailing,
  });
  final VoidCallback onTap;
  final double height;
  final double fontSize;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tappable(
      onTap: onTap,
      pressScale: 0.99,
      borderRadius: BorderRadius.circular(16),
      semanticLabel: 'Szukaj stacji, miast, gatunków',
      child: Ink(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: rc.sf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rc.bd),
          boxShadow: rc.shadowSm,
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 20, color: rc.mu),
            const SizedBox(width: 10),
            Expanded(
              child: TrText(
                'Szukaj stacji, miast, gatunków',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: fontSize, color: rc.mu),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// Card surface (`.card`) that lifts on hover and outlines when [selected].
class HoverCard extends StatefulWidget {
  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(12),
    this.radius = 22,
    this.semanticLabel,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final double radius;
  final String? semanticLabel;

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final calm = context.calm;
    final radius = BorderRadius.circular(widget.radius);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: calm ? Duration.zero : const Duration(milliseconds: 250),
        curve: const Cubic(0.2, 0.7, 0.3, 1),
        transform: Matrix4.translationValues(
          0,
          _hover && !calm && widget.onTap != null ? -4 : 0,
          0,
        ),
        decoration: BoxDecoration(
          color: rc.sf,
          borderRadius: radius,
          border: Border.all(color: widget.selected ? rc.ac : rc.bd),
          boxShadow: _hover ? rc.shadowHover : rc.shadowSm,
        ),
        child: Tappable(
          onTap: widget.onTap,
          pressScale: 0.98,
          borderRadius: radius,
          semanticLabel: widget.semanticLabel,
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );
  }
}
