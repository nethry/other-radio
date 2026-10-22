import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization.dart';
import '../providers.dart';
import 'controls.dart';

String countryLabel(BuildContext context, String code) => code.isEmpty
    ? context.tr('Cały świat')
    : CountryLocalizations.of(context)?.countryName(countryCode: code) ?? code;

void pickStationCountry(BuildContext context, ValueChanged<String> onSelect) {
  showCountryPicker(
    context: context,
    showPhoneCode: false,
    showSearch: true,
    countryListTheme: CountryListThemeData(
      inputDecoration: InputDecoration(
        labelText: context.tr('Wybierz kraj'),
        prefixIcon: const Icon(Icons.search),
      ),
    ),
    onSelect: (country) => onSelect(country.countryCode),
  );
}

/// One catalogue scope shared by browse and search, independent of UI language.
class CountryFilter extends ConsumerWidget {
  const CountryFilter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stations = ref.watch(stationsProvider);
    final defaultCountry = ref.watch(settingsProvider).defaultCountry;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        RadioChip(
          label:
              '${context.tr('Kraj')}: ${countryLabel(context, stations.countryCode)}',
          icon: Icons.public,
          dropdown: true,
          onTap: () => pickStationCountry(context, stations.setCountry),
        ),
        RadioChip(
          label: 'Cały świat',
          selected: stations.countryCode.isEmpty,
          onTap: () => stations.setCountry(''),
        ),
        if (stations.countryCode != defaultCountry)
          RadioChip(
            label: 'Użyj domyślnego kraju',
            onTap: () => stations.setCountry(defaultCountry),
          ),
      ],
    );
  }
}
