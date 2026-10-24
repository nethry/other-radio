import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/ui/country_filter.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/controls.dart';
import '../common.dart';

const _themeOptions = <SegmentOption<ThemeMode>>[
  (value: ThemeMode.dark, label: 'Ciemny', icon: Icons.dark_mode_outlined),
  (value: ThemeMode.light, label: 'Jasny', icon: Icons.light_mode_outlined),
  (
    value: ThemeMode.system,
    label: 'Systemowy',
    icon: Icons.brightness_auto_outlined,
  ),
];

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rc = context.rc;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 640;
        final twoColumns = width >= 900;
        final top = wide ? 32.0 : MediaQuery.paddingOf(context).top + 16;
        final side = wide ? 32.0 : 20.0;
        final bottom = ShellInsets.bottomOf(context) + (wide ? 32 : 24);
        // Inline segmented control only when the row has room for it.
        final inlineSegment = width >= 640;

        final header = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: TrText(
                'Ustawienia',
                style: wide
                    ? heading(40, tracking: -0.035, height: 1.05)
                    : heading(30, height: 1.1),
              ),
            ),
            SizedBox(height: wide ? 6 : 4),
            TrText(
              'Zmiany zapisują się automatycznie',
              style: TextStyle(fontSize: wide ? 14 : 13, color: rc.mu),
            ),
          ],
        );

        final appearance = _Section(
          title: 'Wygląd',
          child: _AppearanceGroup(inlineSegment: inlineSegment),
        );
        const playback = _Section(
          title: 'Odtwarzanie',
          child: _PlaybackGroup(),
        );
        const data = _Section(title: 'Dane i sieć', child: _DataGroup());
        const info = _Section(title: 'Informacje', child: _InfoGroup());

        final Widget body;
        if (twoColumns) {
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [appearance, const SizedBox(height: 24), playback],
                ),
              ),
              const SizedBox(width: 24),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [data, SizedBox(height: 24), info],
                ),
              ),
            ],
          );
        } else {
          body = Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  appearance,
                  const SizedBox(height: 24),
                  playback,
                  const SizedBox(height: 24),
                  data,
                  const SizedBox(height: 24),
                  info,
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: EdgeInsets.fromLTRB(side, top, side, bottom),
          children: [
            header,
            const SizedBox(height: 24),
            const _LocaleGroup(),
            const SizedBox(height: 24),
            body,
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [SectionLabel(title), const SizedBox(height: 10), child],
  );
}

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup({required this.inlineSegment});
  final bool inlineSegment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final segment = Segmented<ThemeMode>(
      semanticLabel: 'Motyw',
      options: _themeOptions,
      selected: settings.themeMode,
      onChanged: settings.setThemeMode,
    );
    return Group(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final inline = inlineSegment && constraints.maxWidth >= 560;
            return SetRow(
              title: 'Motyw',
              subtitle: const TrText('Systemowy dopasuje się do urządzenia'),
              stacked: !inline,
              trailing: inline ? SizedBox(width: 300, child: segment) : segment,
            );
          },
        ),
        SetRow(
          title: 'Kolor akcentu',
          subtitle: const TrText('Przyciski, korektor, wskaźniki'),
          trailing: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final accent in RadioAccent.values)
                _Swatch(
                  accent: accent,
                  selected: settings.accent == accent,
                  onTap: () => settings.setAccent(accent),
                ),
            ],
          ),
        ),
        SetRow(
          title: 'Ogranicz animacje',
          subtitle: const TrText('Statyczny korektor, bez wejść list'),
          trailing: RadioSwitch(
            value: settings.reduceMotion,
            onChanged: settings.setReduceMotion,
            label: 'Ogranicz animacje',
          ),
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final RadioAccent accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Tappable(
      onTap: onTap,
      shape: const CircleBorder(),
      tooltip: accent.label,
      semanticLabel: accent.label,
      selected: selected,
      child: AnimatedContainer(
        duration: context.calm
            ? Duration.zero
            : const Duration(milliseconds: 200),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: accent.color,
          shape: BoxShape.circle,
          border: Border.all(color: rc.sf, width: 3),
          boxShadow: [
            BoxShadow(
              color: selected ? accent.color : Colors.transparent,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackGroup extends ConsumerWidget {
  const _PlaybackGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playbackProvider);
    final rc = context.rc;
    final volume = player.state.volume;
    return Group(
      children: [
        SetRow(
          title: 'Głośność',
          subtitle: const TrText(
            'Głośność i ostatnia stacja są zapamiętywane. Odtwarzanie uruchamiasz samodzielnie.',
          ),
          stacked: true,
          trailing: Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 20, color: rc.mu),
              Expanded(
                child: Slider(
                  value: volume,
                  onChanged: player.volume,
                  semanticFormatterCallback: (v) =>
                      context.tr('Głośność ${(v * 100).round()} procent'),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${(volume * 100).round()}',
                  textAlign: TextAlign.right,
                  style: monoStyle(12, color: rc.mu),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DataGroup extends ConsumerWidget {
  const _DataGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue = ref.watch(stationsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Group(
          children: [
            SetRow(
              title: 'Katalog stacji',
              subtitle: Text(
                catalogue.loading
                    ? context.tr('Pobieranie…')
                    : '${stationCount(catalogue.stations.length, language: Localizations.localeOf(context).languageCode)} · ${context.tr('dostępny także offline')}',
              ),
              trailing: Opacity(
                opacity: catalogue.loading ? 0.5 : 1,
                child: RadioChip(
                  label: 'Odśwież',
                  small: true,
                  icon: Icons.refresh_rounded,
                  onTap: catalogue.loading ? null : catalogue.refresh,
                ),
              ),
            ),
          ],
        ),
        if (catalogue.error != null) ...[
          const SizedBox(height: 10),
          const CatalogueStatus(),
        ],
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup();

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Group(
          children: [
            SetRow(
              title: 'Wersja',
              trailing: Text('0.2.1', style: monoStyle(13, color: rc.mu)),
            ),
            SetRow(
              title: 'Dane stacji',
              subtitle: const Text('radio-browser.info'),
              trailing: Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: rc.act,
              ),
              onTap: () => openLink(
                context,
                Uri.parse('https://www.radio-browser.info'),
              ),
            ),
            SetRow(
              title: 'Licencje open source',
              trailing: Icon(Icons.chevron_right_rounded, color: rc.mu),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'OtherRadio',
                applicationVersion: appVersion,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TrText(
          'Katalog stacji: Radio Browser. Transmisje i znaki towarowe należą do nadawców. Aplikacja nie hostuje strumieni audio.',
          style: TextStyle(fontSize: 12, color: rc.mu, height: 1.6),
        ),
      ],
    );
  }
}

class _LocaleGroup extends ConsumerWidget {
  const _LocaleGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Group(
      children: [
        SetRow(
          title: 'Język aplikacji',
          subtitle: const TrText('Język i kraj stacji są niezależne.'),
          stacked: true,
          trailing: Segmented<String>(
            semanticLabel: 'Język aplikacji',
            options: const [
              (value: 'pl', label: 'Polski', icon: null),
              (value: 'en', label: 'English', icon: null),
            ],
            selected: settings.language,
            onChanged: settings.setLanguage,
          ),
        ),
        SetRow(
          title: 'Domyślny kraj stacji',
          stacked: true,
          trailing: Align(
            alignment: Alignment.centerLeft,
            child: RadioChip(
              label: countryLabel(context, settings.defaultCountry),
              dropdown: true,
              onTap: () => pickStationCountry(context, (code) {
                settings.setDefaultCountry(code);
                ref.read(stationsProvider).setCountry(code);
              }),
            ),
          ),
        ),
      ],
    );
  }
}
