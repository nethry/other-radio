import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/history_entry.dart';
import '../models/station.dart';

class RadioStorage {
  RadioStorage(this.box, this.preferences);
  final Box<String> box;
  final SharedPreferences preferences;

  List<Station> readStations(String key) {
    try {
      final value = box.get(key);
      if (value == null) return [];
      return (jsonDecode(value) as List)
          .map((e) => Station.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> writeStations(String key, Iterable<Station> stations) =>
      box.put(key, jsonEncode(stations.map((e) => e.toJson()).toList()));

  Station? get lastStation {
    try {
      final value = preferences.getString('lastStation');
      return value == null
          ? null
          : Station.fromJson(jsonDecode(value) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> rememberStation(Station station) async {
    await preferences.setString('lastStation', jsonEncode(station.toJson()));
  }

  double get volume => (preferences.getDouble('volume') ?? 0.75).clamp(0, 1);
  Future<void> saveVolume(double volume) async {
    await preferences.setDouble('volume', volume);
  }

  List<HistoryEntry> readHistory() {
    try {
      final value = box.get('history');
      if (value == null) return [];
      final result = <HistoryEntry>[];
      for (final row in jsonDecode(value) as List) {
        try {
          result.add(
            HistoryEntry.fromJson(Map<String, dynamic>.from(row as Map)),
          );
        } on Object {
          // Skip a corrupt entry rather than losing the whole history.
        }
      }
      return result;
    } on Object {
      return [];
    }
  }

  Future<void> writeHistory(Iterable<HistoryEntry> entries) =>
      box.put('history', jsonEncode(entries.map((e) => e.toJson()).toList()));

  String? get themeMode => preferences.getString('themeMode');
  String get defaultCountry => preferences.getString('defaultCountry') ?? 'PL';
  Future<void> saveDefaultCountry(String value) =>
      preferences.setString('defaultCountry', value);

  String get language => preferences.getString('language') ?? 'pl';
  Future<void> saveLanguage(String value) =>
      preferences.setString('language', value);

  Future<void> saveThemeMode(String value) =>
      preferences.setString('themeMode', value);

  String? get accent => preferences.getString('accent');
  Future<void> saveAccent(String value) =>
      preferences.setString('accent', value);

  bool get reduceMotion => preferences.getBool('reduceMotion') ?? false;
  Future<void> saveReduceMotion(bool value) =>
      preferences.setBool('reduceMotion', value);

  List<String> get recentSearches =>
      preferences.getStringList('recentSearches') ?? const [];
  Future<void> saveRecentSearches(List<String> value) =>
      preferences.setStringList('recentSearches', value);
}
