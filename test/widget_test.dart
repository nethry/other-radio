import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:other_radio/app.dart';
import 'package:other_radio/audio/playback_controller.dart';
import 'package:other_radio/audio/radio_audio_handler.dart';
import 'package:other_radio/core/providers.dart';
import 'package:other_radio/core/theme.dart';
import 'package:other_radio/core/ui/controls.dart';
import 'package:other_radio/data/local/radio_storage.dart';
import 'package:other_radio/data/models/history_entry.dart';
import 'package:other_radio/data/models/station.dart';
import 'package:other_radio/data/repositories/station_repository.dart';
import 'package:other_radio/features/stations/station_controller.dart';
import 'package:other_radio/features/tv/tv_player.dart';
import 'package:other_radio/features/tv/tv_shell.dart';
import 'package:other_radio/features/tv/tv_theme.dart';
import 'package:other_radio/features/tv/tv_widgets.dart';

class _Repository extends Mock implements StationRepository {}

class _Storage extends Mock implements RadioStorage {}

class _Playback extends ChangeNotifier implements PlaybackController {
  RadioSnapshot _state = const RadioSnapshot();
  @override
  String source = 'Katalogu';
  @override
  RadioSnapshot get state => _state;
  @override
  Future<void> select(
    Station station, {
    List<Station>? queue,
    String? source,
  }) async {
    if (source != null) this.source = source;
    _state = RadioSnapshot(station: station, phase: RadioPhase.playing);
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    _state = RadioSnapshot(
      station: _state.station,
      phase: _state.active ? RadioPhase.paused : RadioPhase.playing,
    );
    notifyListeners();
  }

  @override
  bool get canSkip => false;
  @override
  Future<void> next() async {
    nextCalls++;
  }

  int nextCalls = 0;
  int previousCalls = 0;
  @override
  Future<void> previous() async {
    previousCalls++;
  }

  @override
  void volume(double value) {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> retry() async {}
  @override
  RadioAudioHandler get handler => throw UnimplementedError();
}

const station = Station(
  id: 'one',
  name: 'Radio Test',
  streamUrl: 'https://example.org/live',
  tags: 'pop,rock',
  codec: 'MP3',
  bitrate: 128,
  state: 'Warszawa',
);

Future<_Storage> _pumpApp(
  WidgetTester tester, {
  required Size size,
  List<Station> stations = const [station],
  bool calm = true,
  String? theme,
  String language = 'pl',
  String country = 'PL',
  bool television = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Repository();
  when(() => repository.cached).thenReturn(stations);
  when(() => repository.defaultCountry).thenReturn(country);
  when(() => repository.cachedFor(any())).thenReturn(stations);
  when(() => repository.favorites).thenReturn([]);
  when(() => repository.recentSearches).thenReturn([]);
  when(() => repository.refresh(countryCode: any(named: 'countryCode')))
      .thenAnswer((_) async => stations);
  when(() => repository.saveFavorites(any())).thenAnswer((_) async {});
  when(() => repository.saveRecentSearches(any())).thenAnswer((_) async {});
  final storage = _Storage();
  when(() => storage.themeMode).thenReturn(theme);
  when(() => storage.accent).thenReturn(null);
  when(() => storage.reduceMotion).thenReturn(calm);
  when(() => storage.language).thenReturn(language);
  when(() => storage.defaultCountry).thenReturn(country);
  when(() => storage.saveLanguage(any())).thenAnswer((_) async {});
  when(() => storage.saveDefaultCountry(any())).thenAnswer((_) async {});
  when(storage.readHistory).thenReturn([]);
  when(() => storage.writeHistory(any())).thenAnswer((_) async {});
  when(() => storage.saveThemeMode(any())).thenAnswer((_) async => true);
  when(() => storage.saveAccent(any())).thenAnswer((_) async => true);
  when(() => storage.saveReduceMotion(any())).thenAnswer((_) async => true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        televisionProvider.overrideWithValue(television),
        storageProvider.overrideWithValue(storage),
        stationsProvider.overrideWith((_) => StationController(repository)),
        playbackProvider.overrideWith((_) => _Playback()),
      ],
      child: const OtherRadioApp(),
    ),
  );
  if (calm) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
  return storage;
}

Future<void> _go(WidgetTester tester, AppPage page) async {
  await tester.tap(find.byKey(ValueKey('nav-${page.name}')));
  await tester.pumpAndSettle();
}

final _miniPlayer = find.byWidgetPredicate(
  (w) => w is Tappable && w.semanticLabel == 'Otwórz odtwarzacz',
);

String? _focusedLabel() => FocusManager.instance.primaryFocus?.debugLabel;

/// Name of the station card holding focus, if any.
String? _focusedStation() => FocusManager.instance.primaryFocus?.context
    ?.findAncestorWidgetOfExactType<TvStationCard>()
    ?.station
    .name;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    registerFallbackValue(<HistoryEntry>[]);
    for (final (family, files) in [
      ('Manrope', ['400', '500', '600', '700', '800']),
      ('Sora', ['400', '600', '700']),
      ('JetBrains Mono', ['500']),
    ]) {
      final loader = FontLoader(family);
      for (final weight in files) {
        final name = family.replaceAll(' ', '');
        loader.addFont(rootBundle.load('assets/fonts/$name-$weight.ttf'));
      }
      await loader.load();
    }
  });

  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(800, 600),
    const Size(1280, 800),
  ]) {
    testWidgets(
      'English screens fit $size and language does not change station country',
      (tester) async {
        if (size.width == 320) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        final storage = await _pumpApp(
          tester,
          size: size,
          language: 'en',
          country: 'US',
        );
        expect(
          find.textContaining('Radio from around the world'),
          findsOneWidget,
        );
        expect(find.textContaining('United States'), findsOneWidget);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(OtherRadioApp)),
        );
        final stations = container.read(stationsProvider);
        _noErrors(tester);
        await _go(tester, AppPage.search);
        await tester.enterText(
          find.byKey(const ValueKey('station-search')),
          'missing',
        );
        await tester.pumpAndSettle();
        expect(find.text('No stations found'), findsOneWidget);
        _noErrors(tester);
        await _go(tester, AppPage.favorites);
        expect(
          find.text('Your favorites are waiting to be discovered'),
          findsOneWidget,
        );
        _noErrors(tester);
        await _go(tester, AppPage.history);
        expect(find.text('History is empty'), findsOneWidget);
        _noErrors(tester);
        await _go(tester, AppPage.settings);
        expect(find.text('App language'), findsOneWidget);
        await _tapVisible(tester, find.text('Polski'));
        expect(find.text('Język aplikacji'), findsOneWidget);
        expect(stations.countryCode, 'US');
        verify(() => storage.saveLanguage('pl')).called(1);
        verifyNever(() => storage.saveDefaultCountry(any()));
        _noErrors(tester);
        await _tapVisible(tester, find.text('English'));
        expect(find.text('App language'), findsOneWidget);
        expect(stations.countryCode, 'US');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Polish browsing, search, player and library fit $size', (
      tester,
    ) async {
      final storage = await _pumpApp(tester, size: size);
      expect(find.textContaining('Radio z całego świata'), findsOneWidget);
      _noErrors(tester);
      if (size.width >= 760) {
        // The sidebar fills the window exactly; it must not scroll when its
        // content fits.
        final sidebar = tester.state<ScrollableState>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('nav-browse')),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(sidebar.position.maxScrollExtent, 0);
        expect(find.byTooltip('Jasny'), findsOneWidget);
      }

      await _go(tester, AppPage.search);
      final field = find.byKey(const ValueKey('station-search'));
      await tester.enterText(field, 'nieistniejąca');
      await tester.pumpAndSettle();
      expect(find.text('Nie znaleziono stacji'), findsOneWidget);
      await tester.enterText(field, 'Radio');
      await tester.pumpAndSettle();
      expect(find.text('Radio Test'), findsWidgets);
      _noErrors(tester);

      await _go(tester, AppPage.browse);
      await _tapVisible(tester, find.byTooltip('Dodaj do ulubionych').first);
      expect(
        find.byTooltip('Usuń z ulubionych', skipOffstage: false),
        findsWidgets,
      );
      await _tapVisible(tester, find.text('Radio Test').last);
      _noErrors(tester);

      if (size.width < 1180) {
        await tester.tap(_miniPlayer);
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Radio Test'), findsWidgets);
        await tester.tap(find.byTooltip('Pełny ekran'));
        await tester.pumpAndSettle();
      }
      if (size.width < 900) {
        expect(find.text('ODTWARZANE Z'), findsOneWidget);
        expect(find.text('Katalogu'), findsOneWidget);
        await tester.tap(find.byTooltip('Informacje o stacji'));
        await tester.pumpAndSettle();
        expect(find.text('Szczegóły stacji'), findsOneWidget);
        expect(find.text('MP3'), findsOneWidget);
        _noErrors(tester);
        await tester.tap(find.byTooltip('Wstecz'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Zamknij odtwarzacz'));
      } else {
        expect(find.text('Biblioteka'), findsOneWidget);
        _noErrors(tester);
        await tester.tap(find.text('Biblioteka'));
      }
      await tester.pumpAndSettle();
      _noErrors(tester);

      await _go(tester, AppPage.favorites);
      expect(find.text('Radio Test'), findsWidgets);
      _noErrors(tester);

      await _go(tester, AppPage.history);
      expect(find.text('Najczęściej w tym tygodniu'.toUpperCase()), findsOne);
      expect(find.text('Radio Test'), findsWidgets);
      _noErrors(tester);

      await _go(tester, AppPage.settings);
      await _tapVisible(tester, find.text('Jasny').last);
      verify(() => storage.saveThemeMode('light')).called(1);
      expect(
        Theme.of(tester.element(find.byType(Scaffold).first)).brightness,
        Brightness.light,
      );
      _noErrors(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets('light theme at text scale 1.3 fits every page at $size', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final many = [
        for (var i = 0; i < 40; i++)
          station.copyWith(
            id: '$i',
            name: 'Polskie Radio Program Regionalny numer $i',
            tags: 'informacje,rozmowy,muzyka,kultura',
          ),
      ];
      await _pumpApp(tester, size: size, stations: many, theme: 'light');
      for (final page in AppPage.values) {
        await _go(tester, page);
        _noErrors(tester);
      }
      await _go(tester, AppPage.browse);
      if (size.width < 760) {
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
      }
      await _tapVisible(tester, find.text(many.first.name).first);
      _noErrors(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  final tvStations = [
    for (var i = 0; i < 30; i++) station.copyWith(id: '$i', name: 'Station $i'),
  ];

  Future<ProviderContainer> pumpTv(
    WidgetTester tester, {
    Size size = const Size(960, 540),
    List<Station>? stations,
  }) async {
    await _pumpApp(
      tester,
      size: size,
      language: 'en',
      television: true,
      stations: stations ?? tvStations,
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(OtherRadioApp)),
    );
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
    _noErrors(tester);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    _noErrors(tester);
  }

  /// Holds OK past the long-press threshold.
  Future<void> hold(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    _noErrors(tester);
  }

  for (final size in [
    const Size(960, 540),
    const Size(853, 480),
    const Size(1920, 1080),
  ]) {
    testWidgets(
      'TV Discover plays from the hero, keeps row columns and walks the Back '
      'stack at $size',
      (tester) async {
        final container = await pumpTv(tester, size: size);
        final player = container.read(playbackProvider);
        final catalogue = container.read(stationsProvider);

        // Launch → listening in one press.
        expect(_focusedLabel(), 'hero play');
        await press(tester, LogicalKeyboardKey.select);
        expect(player.state.station?.id, '0');
        expect(player.state.phase, RadioPhase.playing);
        expect(find.textContaining('Now playing: Station 0'), findsOneWidget);

        // Empty Favourites is skipped; Recently played now holds Station 0.
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focusedStation(), 'Station 0');
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.arrowRight);
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focusedStation(), 'Station 2');
        await press(tester, LogicalKeyboardKey.arrowDown);
        expect(_focusedStation(), isNull, reason: 'Genres row');
        await press(tester, LogicalKeyboardKey.arrowUp);
        expect(_focusedStation(), 'Station 2', reason: 'rows keep columns');

        // ← at column 0 opens the rail on the current section; → closes it
        // and restores the exact card.
        await press(tester, LogicalKeyboardKey.arrowLeft);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        await press(tester, LogicalKeyboardKey.arrowLeft);
        expect(_focusedLabel(), 'rail Odkrywaj');
        await press(tester, LogicalKeyboardKey.arrowRight);
        expect(_focusedStation(), 'Station 0');

        // Back: content → hero → rail → exit dialog ("Stay" focused).
        await back(tester);
        expect(_focusedLabel(), 'hero play');
        await back(tester);
        expect(_focusedLabel(), 'rail Odkrywaj');
        await back(tester);
        expect(find.text('Close OtherRadio?'), findsOneWidget);
        await press(tester, LogicalKeyboardKey.select);
        expect(find.text('Close OtherRadio?'), findsNothing);
        expect(_focusedLabel(), 'rail Odkrywaj');
        expect(player.state.phase, RadioPhase.playing);

        // Rail → Search; the on-screen keyboard types without the system IME.
        await press(tester, LogicalKeyboardKey.arrowDown);
        await press(tester, LogicalKeyboardKey.select);
        expect(catalogue.page, AppPage.search);
        await press(tester, LogicalKeyboardKey.select);
        await press(tester, LogicalKeyboardKey.arrowRight);
        await press(tester, LogicalKeyboardKey.select);
        expect(catalogue.query, 'aą');
        expect(tester.testTextInput.isVisible, isFalse);
        await back(tester);
        expect(_focusedLabel(), 'rail Szukaj');
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('TV mini-player opens the full player; Back restores focus', (
    tester,
  ) async {
    final container = await pumpTv(tester);
    final player = container.read(playbackProvider);
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(_focusedLabel(), 'mini player');
    await press(tester, LogicalKeyboardKey.select);
    expect(find.byType(TvPlayerScreen), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.select);
    expect(player.state.phase, RadioPhase.paused);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(find.text('Next station'), findsOneWidget);
    await back(tester);
    expect(find.byType(TvPlayerScreen), findsNothing);
    expect(player.state.phase, RadioPhase.paused);
    expect(_focusedLabel(), 'mini player');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'TV favourites: hold OK opens the menu, Move reorders without dragging, '
    'removal is confirmed',
    (tester) async {
      final container = await pumpTv(tester);
      final catalogue = container.read(stationsProvider);
      for (final s in tvStations.take(3)) {
        await catalogue.toggleFavorite(s);
      }
      catalogue.navigate(AppPage.favorites);
      await tester.pumpAndSettle();
      expect(_focusedStation(), 'Station 0');

      await hold(tester);
      expect(find.text('Move'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(catalogue.favorites.first.id, '0', reason: 'committed on drop');
      await press(tester, LogicalKeyboardKey.select);
      expect([for (final s in catalogue.favorites) s.id], ['1', '0', '2']);
      expect(_focusedStation(), 'Station 0');

      await hold(tester);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.arrowDown);
      await press(tester, LogicalKeyboardKey.select);
      expect(find.text('Remove from favorites?'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.select);
      expect([for (final s in catalogue.favorites) s.id], ['1', '2']);
      expect(_focusedStation(), 'Station 2', reason: 'focus moves to next');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('TV splash reveals the logo and lands on Discover', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      size: const Size(960, 540),
      television: true,
      calm: false,
    );
    expect(find.byType(TvShell), findsNothing);
    // The remote does nothing behind the splash.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('other'), findsOneWidget);
    expect(find.text('POLSKIE RADIO · NA ŻYWO'), findsOneWidget);
    // Cached stations are ready, so the reveal goes straight to the exit.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TvShell), findsOneWidget);
    expect(find.text('other'), findsNothing);
    expect(_focusedLabel(), 'hero play');
    _noErrors(tester);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TV splash: OK or Back skip to Discover', (tester) async {
    for (final skip in ['ok', 'back']) {
      await _pumpApp(
        tester,
        size: const Size(960, 540),
        television: true,
        calm: false,
      );
      expect(find.byType(TvShell), findsNothing);
      if (skip == 'ok') {
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
      } else {
        await tester.binding.handlePopRoute();
      }
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(TvShell), findsOneWidget, reason: skip);
      expect(_focusedLabel(), 'hero play', reason: skip);
      _noErrors(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('TV settings switch theme and accent with the remote', (
    tester,
  ) async {
    final container = await pumpTv(tester);
    final settings = container.read(settingsProvider);
    // A TV that never chose an accent keeps the canvas teal.
    expect(settings.accent, RadioAccent.teal);
    TvColors palette() => TvColors.of(tester.element(find.byType(TvShell)));
    expect(palette().dark, isTrue);

    await back(tester); // hero → rail
    for (var i = 0; i < 4; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
    }
    expect(_focusedLabel(), 'rail Ustawienia');
    await press(tester, LogicalKeyboardKey.select);
    expect(settings.themeMode, ThemeMode.dark);
    // "Wygląd i animacje" → its first option, "Motyw".
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('Light'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(settings.themeMode, ThemeMode.light);
    expect(palette().dark, isFalse);

    // "Kolor akcentu": the dialog opens on the current accent.
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(find.text('Lime'), findsOneWidget);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.select);
    expect(settings.accent, RadioAccent.lime);
    expect(palette().accent, RadioAccent.lime.ink);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('TV all-stations grid reaches rows that were not built yet', (
    tester,
  ) async {
    await pumpTv(
      tester,
      stations: [
        for (var i = 0; i < 80; i++)
          station.copyWith(id: '$i', name: 'Station $i'),
      ],
    );
    // Popular → Genres → "All stations".
    await press(tester, LogicalKeyboardKey.arrowDown);
    await press(tester, LogicalKeyboardKey.arrowDown);
    final tile = _focusedLabel();
    await press(tester, LogicalKeyboardKey.select);
    expect(_focusedStation(), 'Station 0');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(_focusedStation(), 'Station 1');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(_focusedStation(), 'Station 0', reason: 'focus never wraps');
    final reached = <String?>{};
    for (var i = 0; i < 12; i++) {
      await press(tester, LogicalKeyboardKey.arrowDown);
      reached.add(_focusedStation());
    }
    expect(reached, hasLength(12));
    final card = find.byWidgetPredicate(
      (w) => w is TvStationCard && w.station.name == _focusedStation(),
    );
    expect(tester.getRect(card).bottom, lessThanOrEqualTo(540));
    await back(tester);
    expect(_focusedLabel(), tile);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'desktop shortcuts work with focused controls and across player routes',
    (tester) async {
      final second = station.copyWith(id: 'two', name: 'Second Radio');
      await _pumpApp(
        tester,
        size: const Size(1280, 800),
        stations: [station, second],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OtherRadioApp)),
      );
      final player = container.read(playbackProvider) as _Playback;
      final catalogue = container.read(stationsProvider);
      await catalogue.toggleFavorite(station);
      await catalogue.toggleFavorite(second);
      await player.select(station);
      await tester.pumpAndSettle();
      Future<void> ctrl(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      Focus.of(tester.element(find.text('Ustawienia').first)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(player.state.phase, RadioPhase.paused);
      expect(
        catalogue.page,
        AppPage.browse,
      ); // Space did not activate Settings.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
      await tester.sendKeyRepeatEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(player.state.phase, RadioPhase.playing);
      await ctrl(LogicalKeyboardKey.digit2);
      expect(player.state.station?.id, second.id);
      await tester.tap(find.byTooltip('Pełny ekran'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(player.state.phase, RadioPhase.paused);
      await ctrl(LogicalKeyboardKey.arrowRight);
      await ctrl(LogicalKeyboardKey.arrowLeft);
      expect(player.nextCalls, 1);
      expect(player.previousCalls, 1);
      await ctrl(LogicalKeyboardKey.digit1);
      expect(player.state.station?.id, station.id);
      await ctrl(LogicalKeyboardKey.keyK);
      expect(catalogue.page, AppPage.search);
      final field = find.byKey(const ValueKey('station-search'));
      expect(field, findsOneWidget);
      expect(
        tester.widget<TextField>(field).focusNode!.hasFocus,
        isTrue,
        reason: 'Ctrl+K focus: ${FocusManager.instance.primaryFocus}',
      );
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>(),
        isNotNull,
      );
      await tester.enterText(field, 'Radio Test');
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await ctrl(LogicalKeyboardKey.arrowLeft);
      await ctrl(LogicalKeyboardKey.arrowRight);
      expect(player.state.phase, RadioPhase.playing);
      expect(player.nextCalls, 1);
      expect(player.previousCalls, 1);
      // Ctrl+K must also refocus the field when Search is already displayed.
      Focus.of(tester.element(find.text('Ustawienia').first)).requestFocus();
      await tester.pump();
      await ctrl(LogicalKeyboardKey.keyK);
      expect(
        FocusManager.instance.primaryFocus?.context
            ?.findAncestorStateOfType<EditableTextState>(),
        isNotNull,
      );
      _noErrors(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('animations run while playing and stop without errors', (
    tester,
  ) async {
    await _pumpApp(tester, size: const Size(1280, 800), calm: false);
    await tester.tap(find.text('Radio Test').last);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.textContaining('NA ŻYWO'), findsWidgets);
    _noErrors(tester);
    await tester.pumpWidget(const SizedBox());
  });
}

/// Fails with the error and, for layout overflows, the offending widgets.
void _noErrors(WidgetTester tester) {
  final error = tester.takeException();
  if (error != null) {
    final overflowing = [
      for (final r in tester.allRenderObjects.whereType<RenderFlex>())
        if (r.toStringShort().contains('OVERFLOWING'))
          '${r.constraints}\n${r.debugCreator}',
    ];
    fail('$error\n${overflowing.join('\n\n')}');
  }
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.3);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
