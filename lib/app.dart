import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'core/ui/tv_input.dart';
import 'core/ui/app_shortcuts.dart';
import 'features/shell/app_shell.dart';
import 'features/tv/tv_theme.dart';

class OtherRadioApp extends ConsumerStatefulWidget {
  const OtherRadioApp({super.key});
  @override
  ConsumerState<OtherRadioApp> createState() => _OtherRadioAppState();
}

class _OtherRadioAppState extends ConsumerState<OtherRadioApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Adds the Android TV palette (same brightness and accent) on TV.
  ThemeData _withTv(
    ThemeData theme, {
    required bool television,
    required RadioAccent accent,
  }) => !television
      ? theme
      : theme.copyWith(
          extensions: [
            ...theme.extensions.values,
            TvColors.build(
              dark: theme.brightness == Brightness.dark,
              accent: accent,
            ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final television = ref.watch(televisionProvider);
    return MaterialApp(
      title: 'OtherRadio',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: _withTv(
        radioTheme(
          brightness: Brightness.light,
          accent: settings.accent,
          calm: settings.reduceMotion,
        ),
        television: television,
        accent: settings.accent,
      ),
      darkTheme: _withTv(
        radioTheme(accent: settings.accent, calm: settings.reduceMotion),
        television: television,
        accent: settings.accent,
      ),
      themeMode: settings.themeMode,
      themeAnimationDuration: settings.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      locale: Locale(settings.language),
      supportedLocales: const [Locale('pl'), Locale('en')],
      localizationsDelegates: const [
        ...GlobalMaterialLocalizations.delegates,
        CountryLocalizations.delegate,
      ],
      builder: (context, child) => AppShortcuts(
        enabled: !television,
        navigatorKey: _navigatorKey,
        child: TelevisionFrame(enabled: television, child: child!),
      ),
      home: const AppShell(),
    );
  }
}
