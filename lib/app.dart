import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/theme.dart';
import 'features/shell/app_shell.dart';

class OtherRadioApp extends ConsumerWidget {
  const OtherRadioApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'OtherRadio',
      debugShowCheckedModeBanner: false,
      theme: radioTheme(
        brightness: Brightness.light,
        accent: settings.accent,
        calm: settings.reduceMotion,
      ),
      darkTheme: radioTheme(
        accent: settings.accent,
        calm: settings.reduceMotion,
      ),
      themeMode: settings.themeMode,
      themeAnimationDuration: settings.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 300),
      locale: const Locale('pl'),
      supportedLocales: const [Locale('pl')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AppShell(),
    );
  }
}
