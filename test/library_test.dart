import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:other_radio/core/format.dart';
import 'package:other_radio/data/local/radio_storage.dart';
import 'package:other_radio/data/models/station.dart';
import 'package:other_radio/features/history/history_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

const a = Station(id: 'a', name: 'Radio 357', streamUrl: 'https://a.pl/live');
const b = Station(id: 'b', name: 'TOK FM', streamUrl: 'https://b.pl/live');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Polish formatting', () {
    test('plurals follow Polish rules', () {
      expect(stationCount(1), '1 stacja');
      expect(stationCount(3), '3 stacje');
      expect(stationCount(5), '5 stacji');
      expect(stationCount(12), '12 stacji');
      expect(stationCount(22), '22 stacje');
      expect(stationCount(0), '0 stacji');
    });

    test('durations, days and track metadata', () {
      expect(listenDuration(const Duration(seconds: 20)), '< 1 min');
      expect(listenDuration(const Duration(minutes: 45)), '45 min');
      expect(listenDuration(const Duration(minutes: 80)), '1 godz. 20 min');
      final now = DateTime(2026, 10, 18, 12);
      expect(dayLabel(DateTime(2026, 10, 18, 1), now), 'Dzisiaj');
      expect(dayLabel(DateTime(2026, 10, 17, 23), now), 'Wczoraj');
      expect(dayLabel(DateTime(2026, 10, 2), now), '2 października');
      expect(splitTrack('Kult - Arahja'), ('Arahja', 'Kult'));
      expect(splitTrack('Audycja'), ('Audycja', ''));
    });

    test('monograms stay short and recognisable', () {
      expect(monogramCaption('ESKA ROCK'), 'ROCK');
      expect(monogramCaption('RMF FM'), isNull);
      expect(monogramCaption('Radio Nowy Świat'), isNull);
      expect(monogram('Radio 357'), '357');
      expect(monogram('RMF FM'), 'RMF');
      expect(monogram('Polskie Radio Trójka'), 'TRÓ');
      expect(monogram('Radio Nowy Świat'), 'NŚ');
      expect(monogram('Antyradio'), 'ANT');
      expect(monogram(''), '?');
      expect(paletteIndex('a'), inInclusiveRange(0, 7));
    });
  });

  group('listening history', () {
    late Directory directory;
    late Box<String> box;
    late RadioStorage storage;
    late DateTime now;
    late HistoryController history;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('other_radio_hist_');
      Hive.init(directory.path);
      box = await Hive.openBox<String>('radio');
      SharedPreferences.setMockInitialValues({});
      storage = RadioStorage(box, await SharedPreferences.getInstance());
      now = DateTime(2026, 10, 18, 14, 0);
      history = HistoryController(storage, clock: () => now);
    });
    tearDown(() async {
      history.dispose();
      await box.close();
      await directory.delete(recursive: true);
    });

    test('sessions are recorded, merged after short pauses and persisted', () {
      history.observe(a, playing: true);
      expect(history.entries, hasLength(1));
      expect(history.isOpen(history.entries.first), isTrue);
      now = now.add(const Duration(minutes: 30));
      history.observe(a, playing: false);
      expect(history.entries.first.duration, const Duration(minutes: 30));
      // A two-minute pause continues the same session.
      now = now.add(const Duration(minutes: 2));
      history.observe(a, playing: true);
      now = now.add(const Duration(minutes: 10));
      history.observe(b, playing: true);
      expect(history.entries.map((e) => e.station.id), ['b', 'a']);
      expect(history.entries.last.duration, const Duration(minutes: 42));
      now = now.add(const Duration(minutes: 5));
      history.observe(null, playing: false);

      final restored = HistoryController(storage, clock: () => now);
      expect(restored.entries.map((e) => e.station.id), ['b', 'a']);
      expect(restored.top(3).first.station.id, 'a');
      expect(restored.lastPlayed['b'], now);
      expect(restored.groups.single.label, 'Dzisiaj');
      restored.filter('tok');
      expect(restored.groups.single.entries.single.station.id, 'b');
      restored.dispose();
    });

    test('long gaps start a new entry and clearing empties storage', () async {
      history.observe(a, playing: true);
      now = now.add(const Duration(minutes: 1));
      history.observe(a, playing: false);
      now = now.add(const Duration(hours: 1));
      history.observe(a, playing: true);
      expect(history.entries, hasLength(2));
      await history.clear();
      expect(history.entries, isEmpty);
      expect(storage.readHistory(), isEmpty);
    });

    test('corrupt history entries are skipped', () async {
      await box.put('history', '[{"broken":true}]');
      expect(storage.readHistory(), isEmpty);
      await box.put('history', '{broken');
      expect(storage.readHistory(), isEmpty);
    });
  });
}
