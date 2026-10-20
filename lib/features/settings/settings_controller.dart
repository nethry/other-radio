import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/local/radio_storage.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this.storage)
    : themeMode = ThemeMode.values.firstWhere(
        (m) => m.name == storage.themeMode,
        orElse: () => ThemeMode.dark,
      ),
      accent = RadioAccent.byName(storage.accent),
      reduceMotion = storage.reduceMotion;

  final RadioStorage storage;
  ThemeMode themeMode;
  RadioAccent accent;
  bool reduceMotion;

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
