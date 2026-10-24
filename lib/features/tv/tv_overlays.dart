import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../data/models/station.dart';
import 'tv_focusable.dart';
import 'tv_player.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

/// Shows a modal TV overlay. Back cancels (pops with `null`); focus returns
/// to the control that opened it afterwards.
Future<T?> showTvOverlay<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  final opener = FocusManager.instance.primaryFocus;
  final result = await showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.tr('Anuluj'),
    barrierColor: const Color(0xB8040609),
    transitionDuration: TvMotion.of(context, TvMotion.dialog),
    pageBuilder: (context, _, _) =>
        Material(type: MaterialType.transparency, child: builder(context)),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: TvMotion.outCurve,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  restoreTvFocus(opener);
  return result;
}

/// Returns focus to [node] after a route closes, if it still exists and its
/// route is on top again (a follow-up dialog keeps its own focus).
void restoreTvFocus(FocusNode? node) {
  if (node == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = node.context;
    if (context == null || !context.mounted || !node.canRequestFocus) return;
    if (ModalRoute.of(context)?.isCurrent == false) return;
    node.requestFocus();
  });
}

/// Dialog panel (`OrDialog`): at most two buttons, safe action first.
class TvDialog extends StatelessWidget {
  const TvDialog({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.body,
    this.translateTitle = true,
  });
  final String title;
  final String? message;
  final Widget? body;
  final List<Widget> actions;
  final bool translateTitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      constraints: const BoxConstraints(maxWidth: 430),
      margin: const EdgeInsets.symmetric(
        horizontal: TvLayout.safeX,
        vertical: TvLayout.safeY,
      ),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: context.tv.surface2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.tv.outline2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 60,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              translateTitle ? context.tr(title) : title,
              style: tvHeading(22),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: tvBody(13, color: context.tv.text2, height: 1.4),
            ),
          ],
          if (body != null) ...[const SizedBox(height: 12), body!],
          const SizedBox(height: 20),
          Wrap(spacing: 12, runSpacing: 12, children: actions),
        ],
      ),
    ),
  );
}

/// Two-button confirmation; [cancel] is focused by default.
Future<bool> confirmTv(
  BuildContext context, {
  required String title,
  required String confirm,
  String? message,
  String cancel = 'Anuluj',
  bool cancelPrimary = false,
}) async =>
    await showTvOverlay<bool>(
      context,
      builder: (context) => TvDialog(
        title: title,
        message: message,
        actions: [
          TvButton(
            label: cancel,
            primary: cancelPrimary,
            autofocus: true,
            onTap: () => Navigator.pop(context, false),
          ),
          TvButton(label: confirm, onTap: () => Navigator.pop(context, true)),
        ],
      ),
    ) ??
    false;

typedef TvMenuItem<T> = ({T value, IconData icon, String label, bool danger});

/// Context menu (`ContextMenu`) beside the rail. The first item is focused.
Future<T?> showTvMenu<T>(
  BuildContext context, {
  required Station station,
  required List<TvMenuItem<T>> items,
}) => showTvOverlay<T>(
  context,
  builder: (context) => Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: const EdgeInsets.only(left: 280, right: TvLayout.safeX),
      child: Container(
        width: 310,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.tv.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.tv.outline2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 60,
              offset: Offset(0, 20),
            ),
          ],
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                child: Row(
                  children: [
                    TvArt(station: station, size: 40, radius: 10),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tvBody(14, weight: FontWeight.w700),
                          ),
                          Text(
                            place(station),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tvBody(10, color: context.tv.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final (i, item) in items.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: _MenuRow(
                    item: item,
                    autofocus: i == 0,
                    onTap: () => Navigator.pop(context, item.value),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  ),
);

class _MenuRow<T> extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.autofocus,
    required this.onTap,
  });
  final TvMenuItem<T> item;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TvFocusable(
    autofocus: autofocus,
    onTap: onTap,
    semanticLabel: item.label,
    builder: (context, focused, pressed) {
      final fg = item.danger
          ? (focused ? context.tv.onError : context.tv.error)
          : focused
          ? context.tv.bg
          : context.tv.text2;
      return TvScale(
        focused: focused,
        pressed: pressed,
        scale: 1.02,
        child: AnimatedContainer(
          duration: TvMotion.of(context, TvMotion.focus),
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: focused
                ? (item.danger ? context.tv.error : context.tv.text)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 16, color: fg),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  context.tr(item.label),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tvBody(14, color: fg),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

typedef TvChoice<T> = ({T value, String label});

/// Choice dialog for settings: a focusable list with the current value
/// focused. Labels are already localized; [swatch] adds a colour dot.
Future<T?> showTvChoice<T>(
  BuildContext context, {
  required String title,
  required List<TvChoice<T>> options,
  required T selected,
  Color Function(T value)? swatch,
}) {
  const extent = 46.0;
  final index = options.indexWhere((o) => o.value == selected);
  return showTvOverlay<T>(
    context,
    builder: (context) => TvDialog(
      title: title,
      body: SizedBox(
        height: (options.length * extent).clamp(extent, 300),
        child: ListView.builder(
          controller: ScrollController(
            initialScrollOffset: index <= 2 ? 0 : (index - 2) * extent,
          ),
          itemExtent: extent,
          itemCount: options.length,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemBuilder: (context, i) {
            final option = options[i];
            final current = option.value == selected;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: TvFocusable(
                autofocus: i == (index < 0 ? 0 : index),
                selected: current,
                onTap: () => Navigator.pop(context, option.value),
                builder: (context, focused, pressed) => AnimatedContainer(
                  duration: TvMotion.of(context, TvMotion.focus),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: focused ? context.tv.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      if (swatch != null) ...[
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: swatch(option.value),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: focused
                                  ? context.tv.bg
                                  : context.tv.outline2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: Text(
                          option.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tvBody(
                            14,
                            color: focused
                                ? context.tv.bg
                                : current
                                ? context.tv.accent
                                : context.tv.text2,
                          ),
                        ),
                      ),
                      if (current)
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: focused ? context.tv.bg : context.tv.accent,
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [TvButton(label: 'Anuluj', onTap: () => Navigator.pop(context))],
    ),
  );
}

/// Starts [station] at once and stays on the page; OK on the station that is
/// already current opens the full player instead.
void tvActivate(
  BuildContext context,
  WidgetRef ref,
  Station station, {
  required List<Station> queue,
  required String source,
}) {
  final player = ref.read(playbackProvider);
  final state = player.state;
  if (state.station?.id == station.id &&
      state.phase != RadioPhase.error &&
      state.phase != RadioPhase.idle) {
    openTvPlayer(context);
    return;
  }
  player.select(station, queue: queue, source: source);
  TvToast.show(
    context,
    '${context.tr('Teraz gra')}: ${station.name} · '
    '${context.tr('OK ponownie otwiera odtwarzacz')}',
  );
}

/// Adds or removes a favourite; removal asks first. Focus returns to
/// [origin] (e.g. the card a menu was opened from) afterwards.
Future<void> tvToggleFavorite(
  BuildContext context,
  WidgetRef ref,
  Station station, {
  FocusNode? origin,
}) async {
  final catalogue = ref.read(stationsProvider);
  if (catalogue.isFavorite(station)) {
    final focus = origin ?? FocusManager.instance.primaryFocus;
    final remove = await confirmTv(
      context,
      title: 'Usunąć z ulubionych?',
      message:
          '„${station.name}” ${context.tr('zniknie z listy ulubionych. Możesz ją dodać ponownie w każdej chwili.')}',
      confirm: 'Usuń',
    );
    restoreTvFocus(focus);
    if (!remove || !context.mounted) return;
    await catalogue.toggleFavorite(station);
    if (context.mounted) {
      TvToast.show(
        context,
        '${context.tr('Usunięto z ulubionych')}: ${station.name}',
      );
    }
    return;
  }
  await catalogue.toggleFavorite(station);
  if (context.mounted) {
    TvToast.show(
      context,
      '${context.tr('Dodano do ulubionych')}: ${station.name}',
    );
  }
}

enum _StationAction { play, favorite, details }

/// Hold-OK menu for a station outside Favourites.
Future<void> showTvStationMenu(
  BuildContext context,
  WidgetRef ref,
  Station station, {
  required List<Station> queue,
  required String source,
}) async {
  final favorite = ref.read(stationsProvider).isFavorite(station);
  final origin = FocusManager.instance.primaryFocus;
  final action = await showTvMenu<_StationAction?>(
    context,
    station: station,
    items: [
      (
        value: _StationAction.play,
        icon: Icons.play_arrow_rounded,
        label: 'Odtwórz',
        danger: false,
      ),
      (
        value: _StationAction.favorite,
        icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label: favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
        danger: favorite,
      ),
      (
        value: _StationAction.details,
        icon: Icons.info_outline_rounded,
        label: 'Szczegóły stacji',
        danger: false,
      ),
      (value: null, icon: Icons.close_rounded, label: 'Anuluj', danger: false),
    ],
  );
  if (!context.mounted || action == null) return;
  switch (action) {
    case _StationAction.play:
      ref.read(playbackProvider).select(station, queue: queue, source: source);
      TvToast.show(context, '${context.tr('Teraz gra')}: ${station.name}');
    case _StationAction.favorite:
      await tvToggleFavorite(context, ref, station, origin: origin);
    case _StationAction.details:
      await showTvStationDetails(context, station);
      restoreTvFocus(origin);
  }
}

/// Station facts from Radio Browser.
Future<void> showTvStationDetails(BuildContext context, Station station) {
  final language = context.languageCode;
  final facts = <(String, String)>[
    ('Lokalizacja', place(station)),
    ('Tagi', tagLine(station, count: 5, language: language)),
    ('Strumień', formatLong(station)),
    ('Język', station.language),
    ('Strona internetowa', station.homepageUri?.host ?? ''),
  ].where((f) => f.$2.trim().isNotEmpty);
  return showTvOverlay<void>(
    context,
    builder: (context) => TvDialog(
      title: station.name,
      translateTitle: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      context.tr(label),
                      style: tvBody(12, color: context.tv.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: tvBody(12, color: context.tv.text),
                    ),
                  ),
                ],
              ),
            ),
          Text(
            context.tr('Dane stacji: Radio Browser'),
            style: tvBody(10, color: context.tv.muted),
          ),
        ],
      ),
      actions: [
        TvButton(
          label: 'Zamknij',
          autofocus: true,
          onTap: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}

/// Hosts short confirmations (`OrToast`) above every TV route.
class TvToastHost extends StatefulWidget {
  const TvToastHost({super.key, required this.child});
  final Widget child;

  @override
  State<TvToastHost> createState() => _TvToastHostState();
}

abstract final class TvToast {
  static void show(BuildContext context, String message) =>
      context.findAncestorStateOfType<_TvToastHostState>()?._show(message);
}

class _TvToastHostState extends State<TvToastHost> {
  String? _message;
  int _serial = 0;
  Timer? _timer;

  void _show(String message) {
    _timer?.cancel();
    setState(() {
      _message = message;
      _serial++;
    });
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_message != null)
        Positioned(
          left: TvLayout.safeX,
          right: TvLayout.safeX,
          bottom: 32,
          child: Center(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(_serial),
              tween: Tween(begin: 0, end: 1),
              duration: TvMotion.of(context, TvMotion.playerClose),
              curve: TvMotion.outCurve,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - t)),
                  child: child,
                ),
              ),
              child: Semantics(
                liveRegion: true,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: context.tv.surface3,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.tv.outline2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80000000),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 14,
                        color: context.tv.accent,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _message!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tvBody(
                            12,
                            color: context.tv.text,
                          ).copyWith(decoration: TextDecoration.none),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
