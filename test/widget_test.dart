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
import 'package:other_radio/core/ui/controls.dart';
import 'package:other_radio/data/local/radio_storage.dart';
import 'package:other_radio/data/models/history_entry.dart';
import 'package:other_radio/data/models/station.dart';
import 'package:other_radio/data/repositories/station_repository.dart';
import 'package:other_radio/features/stations/station_controller.dart';

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
  Future<void> next() async {}
  @override
  Future<void> previous() async {}
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
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _Repository();
  when(() => repository.cached).thenReturn(stations);
  when(() => repository.favorites).thenReturn([]);
  when(() => repository.recentSearches).thenReturn([]);
  when(repository.refresh).thenAnswer((_) async => stations);
  when(() => repository.saveFavorites(any())).thenAnswer((_) async {});
  when(() => repository.saveRecentSearches(any())).thenAnswer((_) async {});
  final storage = _Storage();
  when(() => storage.themeMode).thenReturn(theme);
  when(() => storage.accent).thenReturn(null);
  when(() => storage.reduceMotion).thenReturn(calm);
  when(storage.readHistory).thenReturn([]);
  when(() => storage.writeHistory(any())).thenAnswer((_) async {});
  when(() => storage.saveThemeMode(any())).thenAnswer((_) async => true);
  when(() => storage.saveAccent(any())).thenAnswer((_) async => true);
  when(() => storage.saveReduceMotion(any())).thenAnswer((_) async => true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
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
    testWidgets('Polish browsing, search, player and library fit $size', (
      tester,
    ) async {
      final storage = await _pumpApp(tester, size: size);
      expect(find.textContaining('Polskie radio'), findsOneWidget);
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
      await tester.tap(find.text('Jasny').last);
      await tester.pumpAndSettle();
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
      await _tapVisible(tester, find.text(many.first.name).first);
      _noErrors(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
