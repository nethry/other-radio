import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/radio_audio_handler.dart';
import '../core/providers.dart';
import '../core/theme.dart';
import '../core/ui/controls.dart';
import '../core/ui/motion.dart';
import '../data/models/station.dart';

/// Width breakpoints. Layouts depend on window width, never on platform.
abstract final class Breakpoints {
  /// Sidebar navigation instead of the bottom tab bar.
  static const sidebar = 760.0;

  /// Persistent "Teraz gra" panel on the right.
  static const nowPanel = 1180.0;
}

/// Uppercase status shown next to the live dot.
String statusLabel(RadioSnapshot state) => switch (state.phase) {
  RadioPhase.idle => 'GOTOWE',
  RadioPhase.loading => 'ŁĄCZENIE…',
  RadioPhase.buffering => 'BUFOROWANIE…',
  RadioPhase.playing => 'NA ŻYWO',
  RadioPhase.paused => 'WSTRZYMANO',
  RadioPhase.error => 'BŁĄD',
};

/// `NA ŻYWO` with the pulsing dot, coloured by playback phase.
class LiveLabel extends StatelessWidget {
  const LiveLabel({
    super.key,
    required this.state,
    this.size = 11,
    this.prefix = '',
  });
  final RadioSnapshot state;
  final double size;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final color = state.phase == RadioPhase.error ? rc.dangerText : rc.act;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LiveDot(
          size: size < 11 ? 6 : 7,
          active: state.phase == RadioPhase.playing,
          color: state.phase == RadioPhase.error ? rc.dangerText : null,
        ),
        SizedBox(width: size < 11 ? 6 : 8),
        Flexible(
          child: Text(
            '$prefix${statusLabel(state)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w800,
              letterSpacing: size * 0.1,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

/// Heart toggle that keeps the existing tooltips used by tests and screen
/// readers.
class HeartButton extends ConsumerWidget {
  const HeartButton({
    super.key,
    required this.station,
    this.ghost = true,
    this.round = false,
    this.size = 44,
    this.iconSize = 20,
  });
  final Station station;
  final bool ghost;
  final bool round;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final favorite = catalogue.isFavorite(station);
    final rc = context.rc;
    return IconBox(
      icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
      tooltip: favorite ? 'Usuń z ulubionych' : 'Dodaj do ulubionych',
      selected: favorite,
      ghost: ghost,
      round: round,
      size: size,
      iconSize: iconSize,
      color: favorite ? rc.act : (ghost ? rc.dim : rc.mu),
      onPressed: () => catalogue.toggleFavorite(station),
    );
  }
}

/// Whether [station] is the one currently loaded and producing sound.
bool isPlaying(RadioSnapshot state, Station station) =>
    state.station?.id == station.id && state.active;

/// Plays [station] picked from [queue] (shown as "Odtwarzane z [source]"),
/// or toggles it when it is already the current station.
void playFrom(
  WidgetRef ref,
  Station station, {
  required List<Station> queue,
  required String source,
}) {
  final player = ref.read(playbackProvider);
  if (player.state.station?.id == station.id &&
      player.state.phase != RadioPhase.error &&
      player.state.phase != RadioPhase.idle) {
    player.toggle();
  } else {
    player.select(station, queue: queue, source: source);
  }
}

/// Space the shell overlays at the bottom of a page (mobile mini player and
/// tab bar fade). Scrollable pages add it as trailing padding.
class ShellInsets extends InheritedWidget {
  const ShellInsets({super.key, required this.bottom, required super.child});
  final double bottom;

  static double bottomOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellInsets>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(ShellInsets old) => old.bottom != bottom;
}

/// Opens a web link, reporting failure in Polish.
Future<void> openLink(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      const SnackBar(content: Text('Nie udało się otworzyć strony.')),
    );
  }
}

/// Empty or error state with an icon, title and hint.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: rc.hov,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 26, color: rc.mu),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: heading(18)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: rc.mu, fontSize: 14, height: 1.5),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Catalogue refresh/error line shown above lists.
class CatalogueStatus extends ConsumerWidget {
  const CatalogueStatus({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    final rc = context.rc;
    if (catalogue.error == null) {
      return catalogue.loading && catalogue.stations.isNotEmpty
          ? const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: LinearProgressIndicator(minHeight: 2),
            )
          : const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: rc.sf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rc.bd),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: rc.mu),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              catalogue.error!,
              style: TextStyle(color: rc.tx2, fontSize: 13, height: 1.4),
            ),
          ),
          TextButton(
            onPressed: catalogue.loading ? null : catalogue.refresh,
            child: const Text('Ponów'),
          ),
        ],
      ),
    );
  }
}
