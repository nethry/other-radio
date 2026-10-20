import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/models/station.dart';
import 'radio_audio_handler.dart';

class PlaybackController extends ChangeNotifier {
  PlaybackController(this.handler, {this._fallbackQueue}) {
    handler.snapshot.addListener(notifyListeners);
  }
  final RadioAudioHandler handler;
  final List<Station> Function()? _fallbackQueue;
  Timer? _volumeDebounce;
  List<Station> _queue = const [];

  /// Where the current station was chosen, e.g. `Ulubionych`.
  String source = 'Katalogu';

  RadioSnapshot get state => handler.snapshot.value;

  /// Plays [station]. [queue] is the list it was picked from; previous/next
  /// move through it.
  Future<void> select(Station station, {List<Station>? queue, String? source}) {
    if (queue != null) _queue = List.unmodifiable(queue);
    if (source != null) this.source = source;
    return handler.select(station);
  }

  Future<void> toggle() => state.active ? handler.pause() : handler.play();
  Future<void> stop() => handler.stop();
  Future<void> retry() => handler.play();

  bool get canSkip => _effectiveQueue.length > 1;

  List<Station> get _effectiveQueue {
    final current = state.station;
    if (current != null && _queue.any((s) => s.id == current.id)) {
      return _queue;
    }
    return _fallbackQueue?.call() ?? _queue;
  }

  Future<void> next() => _skip(1);
  Future<void> previous() => _skip(-1);

  Future<void> _skip(int step) async {
    final queue = _effectiveQueue;
    if (queue.isEmpty) return;
    final index = queue.indexWhere((s) => s.id == state.station?.id);
    final target = index < 0
        ? queue.first
        : queue[(index + step) % queue.length];
    _queue = queue;
    await handler.select(target);
  }

  void volume(double value) {
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 70), () {
      unawaited(handler.changeVolume(value).catchError((Object _) {}));
    });
  }

  @override
  void dispose() {
    _volumeDebounce?.cancel();
    handler.snapshot.removeListener(notifyListeners);
    super.dispose();
  }
}
