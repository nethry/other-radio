import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/local/radio_storage.dart';

class SettingsController extends ChangeNotifier {
  /// [defaultAccent] applies until the user picks one (TV: the canvas teal).
  SettingsController(
    this.storage, {
    RadioAccent defaultAccent = RadioAccent.coral,
  }) : themeMode = ThemeMode.values.firstWhere(
         (m) => m.name == storage.themeMode,
         orElse: () => ThemeMode.dark,
       ),
       accent = storage.accent == null
           ? defaultAccent
           : RadioAccent.byName(storage.accent),
       reduceMotion = storage.reduceMotion,
       language = storage.language,
       defaultCountry = storage.defaultCountry;

  final RadioStorage storage;
  ThemeMode themeMode;
  RadioAccent accent;
  bool reduceMotion;
  String language;
  String defaultCountry;

  void setLanguage(String value) {
    if (!['pl', 'en'].contains(value)) return;
    language = value;
    notifyListeners();
    storage.saveLanguage(value).catchError((Object _) {});
  }

  void setDefaultCountry(String value) {
    defaultCountry = value;
    notifyListeners();
    storage.saveDefaultCountry(value).catchError((Object _) {});
  }

  void setThemeMode(ThemeMode value) {
    themeMode = value;
    notifyListeners();
    storage.saveThemeMode(value.name).catchError((Object _) => false);
  }

  void setAccent(RadioAccent value) {
    accent = value;
    notifyListeners();
    storage.saveAccent(value.name).catchError((Object _) => false);
  }

  void setReduceMotion(bool value) {
    reduceMotion = value;
    notifyListeners();
    storage.saveReduceMotion(value).catchError((Object _) => false);
  }
}
