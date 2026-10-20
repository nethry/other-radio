import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:other_radio/data/api/radio_browser_client.dart';
import 'package:other_radio/data/local/radio_storage.dart';
import 'package:other_radio/data/models/station.dart';
import 'package:other_radio/data/repositories/station_repository.dart';
import 'package:other_radio/features/stations/station_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Client extends Mock implements RadioBrowserClient {}

const station = Station(
  id: 'one',
  name: 'Radio Test',
  streamUrl: 'https://example.org/live',
  tags: 'pop, rock',
  clickcount: 10,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('community records are deduplicated by normalized name and UUID, keeping popularity then bitrate', () {
    final result = StationRepository.normalize([
      station.copyWith(
        id: 'duplicate-name',
        name: '  RADIO   TEST ',
        clickcount: 20,
      ),
      station.copyWith(
        id: 'higher-bitrate',
        name: 'radio test',
        clickcount: 20,
        bitrate: 192,
      ),
      station,
      station.copyWith(id: 'empty', streamUrl: ''),
      station.copyWith(id: 'unsafe', streamUrl: 'file:///tmp/song.mp3'),
      station.copyWith(id: 'two', name: 'Drugie Radio'),
      station.copyWith(name: 'Duplicate UUID'),
    ]);
    expect(result.map((s) => s.id), ['higher-bitrate', 'two', 'one']);
    expect(result.first.bitrate, 192);
  });

  test('community artwork is limited to web URLs', () {
    Uri? art(String favicon) => station.copyWith(favicon: favicon).artUri;
    expect(art(''), isNull);
    expect(art('favicon.ico'), isNull);
    expect(art('not a url'), isNull);
    expect(art('file:///C:/Windows/win.ini'), isNull);
    expect(art('file://attacker.example/share/logo.png'), isNull);
    expect(art(r'\\attacker.example\share\logo.png'), isNull);
    expect(art('ms-appx:///logo.png'), isNull);
    expect(art('javascript:alert(1)'), isNull);
    expect(art('https:///logo.png'), isNull);
    expect(
      art(' https://example.org/logo.png '),
      Uri.parse('https://example.org/logo.png'),
    );
    expect(art('http://example.org/logo.png')?.scheme, 'http');
  });

  test('API discovers hosts, rejects untrusted names, skips bad records and registers play', () async {
    final dio = Dio();
    final paths = <String>[];
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          paths.add(options.uri.toString());
          final Object data;
          if (options.path.endsWith('/servers')) {
            data = [
              {'name': 'de1.api.radio-browser.info'},
              {'name': 'evil.example'},
            ];
          } else if (options.path.endsWith('/stations/search')) {
            expect(options.queryParameters['countrycode'], 'PL');
            expect(options.queryParameters['hidebroken'], true);
            data = [
              station.toJson(),
              {'name': 'Broken row'},
            ];
          } else {
            data = {'ok': true};
          }
          handler.resolve(Response(requestOptions: options, data: data));
        },
      ),
    );
    final client = RadioBrowserClient(dio);
    expect(await client.stations(), [station]);
    await client.registerPlay(station.id);
    expect(paths.where((p) => p.endsWith('/servers')).length, 1);
    expect(paths.last, 'https://de1.api.radio-browser.info/json/url/one');
    expect(paths.any((p) => p.contains('evil.example')), false);
    dio.close();
  });

  test(
    'API attempts every discovered server before surfacing failure',
    () async {
      final dio = Dio();
      final hosts = <String>{};
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path.endsWith('/servers')) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: [
                    {'name': 'de1.api.radio-browser.info'},
                    {'name': 'at1.api.radio-browser.info'},
                  ],
                ),
              );
            } else {
              hosts.add(options.uri.host);
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                ),
              );
            }
          },
        ),
      );
      await expectLater(
        RadioBrowserClient(dio).stations(),
        throwsA(isA<DioException>()),
      );
      expect(hosts, {
        'de1.api.radio-browser.info',
        'at1.api.radio-browser.info',
      });
      dio.close();
    },
  );

  test(
    'transient discovery and catalogue resets recover without manual refresh',
    () async {
      final dio = Dio();
      var discoveryAttempts = 0;
      var catalogueAttempts = 0;
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final discovery = options.path.endsWith('/servers');
            final attempt = discovery
                ? ++discoveryAttempts
                : ++catalogueAttempts;
            if (attempt == 1) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.connectionError,
                  error: const SocketException('Connection reset by peer'),
                ),
              );
            } else {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: discovery
                      ? [
                          {'name': 'de1.api.radio-browser.info'},
                        ]
                      : [station.toJson()],
                ),
              );
            }
          },
        ),
      );
      expect(await RadioBrowserClient(dio).stations(), [station]);
      expect(discoveryAttempts, 2);
      expect(catalogueAttempts, 2);
      dio.close();
    },
  );

  test('invalid certificates are never bypassed or retried', () async {
    final dio = Dio();
    var attempts = 0;
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          attempts++;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badCertificate,
            ),
          );
        },
      ),
    );
    await expectLater(
      RadioBrowserClient(dio).stations(),
      throwsA(isA<DioException>()),
    );
    expect(attempts, 1);
    dio.close();
  });

  group('offline catalogue and preferences', () {
    late Directory directory;
    late Box<String> box;
    late RadioStorage storage;
    late _Client client;
    late StationRepository repository;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('other_radio_test_');
      Hive.init(directory.path);
      box = await Hive.openBox<String>('radio');
      SharedPreferences.setMockInitialValues({});
      storage = RadioStorage(box, await SharedPreferences.getInstance());
      client = _Client();
      repository = StationRepository(client, storage);
    });
    tearDown(() async {
      await box.close();
      await directory.delete(recursive: true);
    });

    test(
      'failed refresh preserves catalogue and favorites independently',
      () async {
        await storage.writeStations('catalogue', [station]);
        await storage.writeStations('favorites', [station]);
        when(client.stations).thenThrow(const SocketException('offline'));
        final controller = StationController(repository);
        expect(controller.stations, [station]);
        await controller.refresh();
        expect(controller.stations, [station]);
        expect(controller.error, contains('zapisaną listę'));
        expect(controller.error, contains('Odtwarzanie może nadal działać'));
        expect(controller.error, isNot(contains('Brak połączenia')));
        expect(controller.loading, false);
        expect(controller.favorites, [station]);
        await controller.toggleFavorite(station);
        expect(repository.favorites, isEmpty);
        expect(repository.cached, [station]);
        controller.dispose();
      },
    );

    test('successful refresh persists, filters compose, and last station never autoplays', () async {
      when(client.stations).thenAnswer(
        (_) async => [
          station,
          station.copyWith(id: 'two', name: 'Jazz FM', tags: 'jazz'),
        ],
      );
      final controller = StationController(repository);
      await controller.refresh();
      expect(repository.cached.length, 2);
      controller.filter(Genre.rock);
      expect(controller.visible, [station]);
      controller.search('TEST');
      expect(controller.results, [station]);
      controller.search('jazz');
      expect(controller.results.single.name, 'Jazz FM');
      controller.toggleHighQuality();
      expect(controller.results, isEmpty);
      controller.rememberSearch();
      expect(storage.recentSearches, ['jazz']);
      await storage.rememberStation(station);
      await storage.saveVolume(0.4);
      expect(storage.lastStation, station);
      expect(storage.volume, 0.4);
      controller.dispose();
    });

    test('catalogue server failure is not reported as disconnected and successful retry clears warning', () async {
      when(client.stations)
          .thenAnswer((_) async => throw StateError('TLS handshake failed'));
      final controller = StationController(repository);
      await controller.refresh();
      expect(controller.error, contains('katalogu stacji'));
      expect(controller.error, isNot(contains('połączeni')));
      when(client.stations).thenAnswer((_) async => [station]);
      await controller.refresh();
      expect(controller.error, isNull);
      expect(controller.stations, [station]);
      controller.dispose();
    });

    test('corrupt cache is ignored', () async {
      await box.put('catalogue', '{broken');
      expect(repository.cached, isEmpty);
    });
  });
}
