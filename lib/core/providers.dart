import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../audio/playback_controller.dart';
import '../audio/radio_audio_handler.dart';
import '../data/local/radio_storage.dart';
import '../data/repositories/station_repository.dart';
import '../features/history/history_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/stations/station_controller.dart';

final storageProvider = Provider<RadioStorage>(
  (ref) => throw UnimplementedError('Override at startup'),
);
final repositoryProvider = Provider<StationRepository>(
  (ref) => throw UnimplementedError('Override at startup'),
);
final audioHandlerProvider = Provider<RadioAudioHandler>(
  (ref) => throw UnimplementedError('Override at startup'),
);
final stationsProvider = ChangeNotifierProvider<StationController>(
  (ref) => StationController(ref.watch(repositoryProvider)),
);
final playbackProvider = ChangeNotifierProvider<PlaybackController>(
  (ref) => PlaybackController(
    ref.watch(audioHandlerProvider),
    fallbackQueue: () => ref.read(stationsProvider).stations,
  ),
);
final settingsProvider = ChangeNotifierProvider<SettingsController>(
  (ref) => SettingsController(ref.watch(storageProvider)),
);
final historyProvider = ChangeNotifierProvider<HistoryController>((ref) {
  final history = HistoryController(ref.watch(storageProvider));
  // `.notifier` so playback updates feed history without rebuilding it.
  final playback = ref.watch(playbackProvider.notifier);
  void sync() => history.observe(
    playback.state.station,
    playing: playback.state.phase == RadioPhase.playing,
  );
  playback.addListener(sync);
  sync();
  ref.onDispose(() => playback.removeListener(sync));
  return history;
});
