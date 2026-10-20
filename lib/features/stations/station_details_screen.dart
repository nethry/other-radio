import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/radio_audio_handler.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/art.dart';
import '../../core/ui/controls.dart';
import '../../core/ui/motion.dart';
import '../../data/models/station.dart';
import '../common.dart';

void openStation(BuildContext context, Station station) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => StationDetailsScreen(station: station),
    ),
  );
}

String countryLabel(Station s) {
  final code = s.countrycode.trim().toUpperCase();
  return code.isEmpty || code == 'PL' ? 'Polska (PL)' : code;
}

String languageLabel(Station s) =>
    s.language.trim().isEmpty ? 'nieznany' : s.language.trim();

String codecLabel(Station s) =>
    s.codec.trim().isEmpty ? 'nieznany' : s.codec.trim().toUpperCase();

String bitrateLabel(Station s) =>
    s.bitrate > 0 ? '${s.bitrate} kb/s' : 'nieznany';

/// `HTTPS · ICY` or, with [long], `HTTPS · metadane ICY`.
String streamLabel(Station s, {bool long = false}) {
  final scheme = s.streamUrl.startsWith('https://') ? 'HTTPS' : 'HTTP';
  return long ? '$scheme · metadane ICY' : '$scheme · ICY';
}

class StationDetailsScreen extends ConsumerWidget {
  const StationDetailsScreen({super.key, required this.station});
  final Station station;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    final player = ref.watch(playbackProvider);
    final catalogue = ref.watch(stationsProvider);
    final state = player.state;
    final current = state.station?.id == station.id;
    final playing = current && state.active;
    final favorite = catalogue.isFavorite(station);
    final homepage = station.homepageUri;

    final (label, icon, onPressed) = playing
        ? ('Gra teraz', Icons.pause_rounded, player.toggle)
        : current && state.phase == RadioPhase.paused
        ? ('Wznów', Icons.play_arrow_rounded, player.toggle)
        : (
            'Odtwórz',
            Icons.play_arrow_rounded,
            () =>
                player.select(station, source: 'Szczegółów', queue: [station]),
          );

    return Scaffold(
      backgroundColor: rc.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    IconBox(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Wstecz',
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'Szczegóły stacji',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
                const SizedBox(height: 20),
                Rise(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned(
                        left: -60,
                        right: 120,
                        top: -70,
                        height: 260,
                        child: Glow(),
                      ),
                      Row(
                        children: [
                          StationTile(
                            station: station,
                            width: 112,
                            radius: 32,
                            fontSize: 36,
                            shadow: true,
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station.name,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: heading(26, height: 1.1),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${place(station)} · Polska',
                                  style: TextStyle(fontSize: 13, color: rc.mu),
                                ),
                                if (playing) ...[
                                  const SizedBox(height: 6),
                                  LiveLabel(state: state),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Rise(
                  index: 1,
                  child: Row(
                    children: [
                      Expanded(
                        child: PillButton(
                          label: label,
                          icon: icon,
                          onPressed: onPressed,
                          padding: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PillButton(
                          label: favorite
                              ? 'W ulubionych'
                              : 'Dodaj do ulubionych',
                          icon: favorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          iconColor: favorite ? rc.act : null,
                          tone: ButtonTone.secondary,
                          padding: 12,
                          onPressed: () => catalogue.toggleFavorite(station),
                        ),
                      ),
                    ],
                  ),
                ),
                if (station.genres.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Rise(
                    index: 2,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [for (final g in station.genres) TagChip(g)],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Rise(
                  index: 3,
                  child: Group(
                    children: [
                      _Fact('Kraj', countryLabel(station)),
                      _Fact('Język', languageLabel(station)),
                      _Fact('Kodek', codecLabel(station), mono: true),
                      _Fact('Bitrate', bitrateLabel(station), mono: true),
                      _Fact('Strumień', streamLabel(station, long: true)),
                      if (homepage != null)
                        _Fact(
                          'Strona',
                          '${homepage.host} ↗',
                          link: true,
                          onTap: () => openLink(context, homepage),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'Dane stacji: Radio Browser',
                    style: TextStyle(fontSize: 12, color: rc.mu),
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

class _Fact extends StatelessWidget {
  const _Fact(
    this.label,
    this.value, {
    this.mono = false,
    this.link = false,
    this.onTap,
  });
  final String label;
  final String value;
  final bool mono;
  final bool link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final valueStyle = mono
        ? monoStyle(14, color: rc.tx)
        : TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: link ? rc.act : rc.tx,
          );
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: rc.mu)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ),
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
