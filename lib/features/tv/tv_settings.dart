import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/localization.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/country_filter.dart';
import '../common.dart';
import 'tv_focusable.dart';
import 'tv_overlays.dart';
import 'tv_shell.dart';
import 'tv_theme.dart';
import 'tv_widgets.dart';

enum _Category {
  locale('Język i region', Icons.language_rounded),
  motion('Wygląd i animacje', Icons.animation_rounded),
  data('Dane i sieć', Icons.cloud_sync_outlined),
  about('Informacje', Icons.info_outline_rounded);

  const _Category(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Two-pane settings: categories on the left, options on the right. Every
/// option is a full-width row; OK toggles or opens a choice list. Only
/// behaviour that works on TV is offered.
class TvSettings extends ConsumerStatefulWidget {
  const TvSettings({super.key});

  @override
  ConsumerState<TvSettings> createState() => _TvSettingsState();
}

class _TvSettingsState extends ConsumerState<TvSettings> {
  final _categories = {
    for (final c in _Category.values) c: FocusNode(debugLabel: c.label),
  };
  final _firstOption = FocusNode(debugLabel: 'first option');
  final _options = FocusNode(
    debugLabel: 'options',
    canRequestFocus: false,
    skipTraversal: true,
  );
  _Category _selected = _Category.locale;

  @override
  void dispose() {
    for (final node in _categories.values) {
      node.dispose();
    }
    _firstOption.dispose();
    _options.dispose();
    super.dispose();
  }

  void _enterOptions() {
    if (_firstOption.context != null) _firstOption.requestFocus();
  }

  bool _onBack() {
    if (!_options.hasFocus) return false;
    _categories[_selected]!.requestFocus();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final catalogue = ref.watch(stationsProvider);
    final language = context.languageCode;
    final options = switch (_selected) {
      _Category.locale => [
        _OptionRow(
          focusNode: _firstOption,
          title: 'Język aplikacji',
          subtitle: 'Język i kraj stacji są niezależne.',
          value: settings.language == 'en' ? 'English' : 'Polski',
          onTap: () async {
            final value = await showTvChoice<String>(
              context,
              title: 'Język aplikacji',
              selected: settings.language,
              options: const [
                (value: 'pl', label: 'Polski'),
                (value: 'en', label: 'English'),
              ],
            );
            if (value != null) settings.setLanguage(value);
          },
        ),
        _OptionRow(
          title: 'Domyślny kraj stacji',
          subtitle: 'Katalog stacji',
          value: countryLabel(context, settings.defaultCountry),
          onTap: () async {
            final value = await showTvChoice<String>(
              context,
              title: 'Domyślny kraj stacji',
              selected: settings.defaultCountry,
              options: _countries(context),
            );
            if (value == null) return;
            settings.setDefaultCountry(value);
            ref.read(stationsProvider).setCountry(value);
          },
        ),
      ],
      _Category.motion => [
        _OptionRow(
          focusNode: _firstOption,
          title: 'Ogranicz animacje',
          subtitle: 'Statyczny korektor, bez wejść list',
          toggle: settings.reduceMotion,
          onTap: () => settings.setReduceMotion(!settings.reduceMotion),
        ),
      ],
      _Category.data => [
        _OptionRow(
          focusNode: _firstOption,
          title: 'Katalog stacji',
          subtitle: catalogue.loading
              ? 'Pobieranie…'
              : '${stationCount(catalogue.stations.length, language: language)} · ${countryLabel(context, catalogue.countryCode)}',
          translateSubtitle: catalogue.loading,
          value: 'Odśwież',
          onTap: catalogue.loading ? null : catalogue.refresh,
        ),
      ],
      _Category.about => <Widget>[],
    };
    return TvBackHandler(
      onBack: _onBack,
      child: TvPageFrame(
        title: 'Ustawienia',
        subtitle: 'Zmiany zapisują się automatycznie',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TvLayout.ringInset,
            TvLayout.ringInset,
            TvLayout.safeX,
            TvLayout.safeY,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 240,
                      child: Focus(
                        canRequestFocus: false,
                        skipTraversal: true,
                        onKeyEvent: (_, event) {
                          if (event is KeyUpEvent ||
                              event.logicalKey !=
                                  LogicalKeyboardKey.arrowRight) {
                            return KeyEventResult.ignored;
                          }
                          _enterOptions();
                          return KeyEventResult.handled;
                        },
                        child: Column(
                          children: [
                            for (final c in _Category.values)
                              _CategoryRow(
                                category: c,
                                node: _categories[c]!,
                                selected: c == _selected,
                                autofocus: c == _Category.locale,
                                onFocus: () => setState(() => _selected = c),
                                onTap: _enterOptions,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 36),
                    Expanded(
                      child: Focus(
                        focusNode: _options,
                        onKeyEvent: (_, event) {
                          if (event is KeyUpEvent ||
                              event.logicalKey !=
                                  LogicalKeyboardKey.arrowLeft) {
                            return KeyEventResult.ignored;
                          }
                          _categories[_selected]!.requestFocus();
                          return KeyEventResult.handled;
                        },
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 0, 0, 8),
                                child: Text(
                                  context.tr(_selected.label).toUpperCase(),
                                  style: tvLabel(size: 9),
                                ),
                              ),
                              if (_selected == _Category.about)
                                const _About()
                              else
                                for (final option in options)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 5),
                                    child: option,
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const TvHint('OK', 'Przełącz / wybierz'),
                  const SizedBox(width: 16),
                  const TvHint('WSTECZ', 'Kategorie'),
                  const Spacer(),
                  const TvWordmark(size: 13, glyph: false),
                  const SizedBox(width: 8),
                  Text(
                    '$appVersion · radio-browser.info',
                    style: monoStyle(9, color: TvColors.muted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<TvChoice<String>> _countries(BuildContext context) {
    final names = CountryLocalizations.of(context);
    final countries = [
      for (final c in CountryService().getAll())
        (
          value: c.countryCode,
          label: names?.countryName(countryCode: c.countryCode) ?? c.name,
        ),
    ]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return [(value: '', label: context.tr('Cały świat')), ...countries];
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.node,
    required this.selected,
    required this.autofocus,
    required this.onFocus,
    required this.onTap,
  });
  final _Category category;
  final FocusNode node;
  final bool selected;
  final bool autofocus;
  final VoidCallback onFocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: TvFocusable(
      focusNode: node,
      autofocus: autofocus,
      selected: selected,
      semanticLabel: category.label,
      onTap: onTap,
      onFocusChange: (focused) {
        if (focused) onFocus();
      },
      builder: (context, focused, pressed) {
        final color = focused
            ? TvColors.text
            : selected
            ? TvColors.accent
            : TvColors.text2;
        return TvScale(
          focused: focused,
          pressed: pressed,
          scale: 1.02,
          pressedScale: 0.99,
          child: AnimatedContainer(
            duration: TvMotion.of(context, TvMotion.focus),
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              color: focused || selected
                  ? (focused ? TvColors.surface3 : TvColors.surface2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: focused
                  ? const [BoxShadow(color: TvColors.accent, spreadRadius: 2)]
                  : const [],
            ),
            child: Row(
              children: [
                Icon(category.icon, size: 18, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.tr(category.label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tvBody(14, color: color),
                  ),
                ),
                if (selected)
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Settings row (`SettingsRow`): title, explanation and a value or switch.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    required this.onTap,
    this.subtitle,
    this.translateSubtitle = true,
    this.value,
    this.toggle,
    this.focusNode,
  });
  final String title;
  final String? subtitle;
  final bool translateSubtitle;
  final String? value;
  final bool? toggle;
  final VoidCallback? onTap;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => TvFocusable(
    focusNode: focusNode,
    onTap: onTap,
    semanticLabel: title,
    selected: toggle,
    builder: (context, focused, pressed) => TvScale(
      focused: focused,
      pressed: pressed,
      scale: 1.02,
      pressedScale: 0.99,
      child: AnimatedContainer(
        duration: TvMotion.of(context, TvMotion.focus),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: focused ? TvColors.surface3 : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: focused
              ? const [BoxShadow(color: TvColors.accent, spreadRadius: 2)]
              : const [],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(title),
                    style: tvBody(
                      14,
                      color: focused ? TvColors.text : TvColors.text2,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      translateSubtitle ? context.tr(subtitle!) : subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tvBody(
                        10,
                        color: TvColors.muted,
                        weight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (toggle != null)
              TvSwitch(on: toggle!)
            else if (value != null) ...[
              Text(
                context.tr(value!),
                style: tvBody(12, color: TvColors.muted),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: TvColors.muted,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TvWordmark(size: 22),
        const SizedBox(height: 14),
        for (final (label, value) in [
          ('Wersja', appVersion),
          ('Dane stacji', 'Radio Browser · radio-browser.info'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    context.tr(label),
                    style: tvBody(12, color: TvColors.muted),
                  ),
                ),
                Text(value, style: tvBody(12)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Katalog stacji: Radio Browser. Transmisje i znaki towarowe należą do nadawców. Aplikacja nie hostuje strumieni audio.',
          ),
          style: tvBody(11, color: TvColors.muted, height: 1.5),
        ),
      ],
    ),
  );
}
