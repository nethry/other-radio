import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smtc_windows/smtc_windows.dart';

import 'app.dart';
import 'audio/radio_audio_handler.dart';
import 'audio/smtc_service.dart';
import 'core/providers.dart';
import 'core/device_capabilities.dart';
import 'core/localization.dart';
import 'core/theme.dart';
import 'data/api/radio_browser_client.dart';
import 'data/local/radio_storage.dart';
import 'data/repositories/station_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Manrope', 'manrope'),
      ('Sora', 'sora'),
      ('JetBrains Mono', 'jetbrainsmono'),
    ]) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
    }
  });
  var language = 'pl';
  try {
    final preferences = await SharedPreferences.getInstance();
    language = preferences.getString('language') ?? 'pl';
    final television = await DeviceCapabilities.isTelevision();
    await Hive.initFlutter();
    final storage = RadioStorage(
      await Hive.openBox<String>('radio'),
      preferences,
    );
    final client = RadioBrowserClient(
      Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
          headers: {
            'User-Agent': 'OtherRadio/0.2.1 (Worldwide internet radio; pl.otherradio.other_radio)',
          },
        ),
      ),
    );
    if (Platform.isWindows) {
      JustAudioMediaKit.ensureInitialized(windows: true, linux: false);
      await SMTCWindows.initialize();
    }
    final handler = Platform.isAndroid
        ? await AudioService.init<RadioAudioHandler>(
            builder: () => RadioAudioHandler(client, storage),
            config: AudioServiceConfig(
              androidNotificationChannelId: 'pl.otherradio.playback',
              androidNotificationChannelName: language == 'en'
                  ? 'Radio playback'
                  : 'Odtwarzanie radia',
              androidNotificationOngoing: false,
              androidNotificationIcon: 'drawable/ic_notification',
            ),
          )
        : RadioAudioHandler(client, storage);
    handler.setLanguage(language);
    final smtc = Platform.isWindows ? SmtcService(handler) : null;
    runApp(
      ProviderScope(
        overrides: [
          televisionProvider.overrideWithValue(television),
          storageProvider.overrideWithValue(storage),
          repositoryProvider.overrideWithValue(
            StationRepository(client, storage),
          ),
          audioHandlerProvider.overrideWithValue(handler),
        ],
        child: _AppLifetime(handler: handler, smtc: smtc),
      ),
    );
  } catch (error, stack) {
    debugPrint('Startup failed: $error\n$stack');
    runApp(
      MaterialApp(
        theme: radioTheme(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: RadioAccent.coral.color,
                    size: 48,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    translate('Nie udało się uruchomić radia.', language),
                    textAlign: TextAlign.center,
                    style: heading(22),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    translate(
                      'Zamknij aplikację i spróbuj ponownie.',
                      language,
                    ),
                    textAlign: TextAlign.center,
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

class _AppLifetime extends ConsumerStatefulWidget {
  const _AppLifetime({required this.handler, required this.smtc});
  final RadioAudioHandler handler;
  final SmtcService? smtc;
  @override
  ConsumerState<_AppLifetime> createState() => _AppLifetimeState();
}

class _AppLifetimeState extends ConsumerState<_AppLifetime> {
  @override
  void dispose() {
    widget.smtc?.dispose();
    widget.handler.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((settings) => settings.language), (
      _,
      language,
    ) {
      widget.handler.setLanguage(language);
    });
    return const OtherRadioApp();
  }
}
