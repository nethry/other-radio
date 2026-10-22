import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../data/api/radio_browser_client.dart';
import '../data/local/radio_storage.dart';
import '../data/models/station.dart';

enum RadioPhase { idle, loading, buffering, playing, paused, error }

class RadioSnapshot {
  const RadioSnapshot({
    this.station,
    this.phase = RadioPhase.idle,
    this.title = '',
    this.volume = 0.75,
    this.error,
  });
  final Station? station;
  final RadioPhase phase;
  final String title;
  final double volume;
  final String? error;
  bool get busy => phase == RadioPhase.loading || phase == RadioPhase.buffering;
  bool get active => busy || phase == RadioPhase.playing;
}

class RadioAudioHandler extends BaseAudioHandler {
  RadioAudioHandler(this._client, this._storage, {AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _station = _storage.lastStation;
    _volume = _storage.volume;
    unawaited(_player.setVolume(_volume));
    snapshot = ValueNotifier(RadioSnapshot(station: _station, volume: _volume));
    _subscriptions.add(_player.playerStateStream.listen(_onPlayerState));
    _subscriptions.add(_player.errorStream.listen((_) => _recover()));
    _subscriptions.add(
      _player.icyMetadataStream.listen((metadata) {
        _title = metadata?.info?.title?.trim() ?? '';
        _updateMediaItem();
        _publish(snapshot.value.phase);
      }),
    );
    _updateMediaItem();
  }

  final RadioBrowserClient _client;
  final RadioStorage _storage;
  final AudioPlayer _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  late final ValueNotifier<RadioSnapshot> snapshot;
  Station? _station;
  String _title = '';
  double _volume = 0.75;
  bool _failed = false;
  bool _opening = false;
  bool _disposed = false;
  bool _wantsPlayback = false;
  int _generation = 0;
  int _attempts = 0;
  Timer? _retry;
  Timer? _watchdog;
  String _language = 'pl';
  String get liveAlbum =>
      _language == 'en' ? 'OtherRadio • Live' : 'OtherRadio • Na żywo';

  void setLanguage(String language) {
    if (_language == language || _disposed) return;
    _language = language;
    _updateMediaItem();
    _publish(snapshot.value.phase, error: snapshot.value.error);
  }

  void _onPlayerState(PlayerState state) {
    if (_disposed || _failed || _opening) return;
    final phase = switch (state.processingState) {
      ProcessingState.idle => RadioPhase.idle,
      ProcessingState.loading => RadioPhase.loading,
      ProcessingState.buffering => RadioPhase.buffering,
      ProcessingState.ready =>
        state.playing ? RadioPhase.playing : RadioPhase.paused,
      ProcessingState.completed => RadioPhase.idle,
    };
    _publish(phase);
    if (phase == RadioPhase.buffering) {
      _watchdog ??= Timer(const Duration(seconds: 10), _recover);
    } else {
      _watchdog?.cancel();
      _watchdog = null;
    }
    if (state.processingState == ProcessingState.completed && state.playing) {
      _recover();
    }
  }

  void _updateMediaItem() {
    final station = _station;
    if (station == null) return;
    mediaItem.add(
      MediaItem(
        id: station.id,
        title: _title.isEmpty ? station.name : _title,
        artist: station.name,
        album: liveAlbum,
        artUri: station.artUri,
        isLive: true,
      ),
    );
  }

  void _publish(RadioPhase phase, {String? error}) {
    if (_disposed) return;
    snapshot.value = RadioSnapshot(
      station: _station,
      phase: phase,
      title: _title,
      volume: _volume,
      error: error,
    );
    playbackState.add(
      PlaybackState(
        controls: [
          if (_wantsPlayback) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
        ],
        androidCompactActionIndices: const [0, 1],
        processingState: switch (phase) {
          RadioPhase.loading => AudioProcessingState.loading,
          RadioPhase.buffering => AudioProcessingState.buffering,
          RadioPhase.playing || RadioPhase.paused => AudioProcessingState.ready,
          RadioPhase.error => AudioProcessingState.error,
          RadioPhase.idle => AudioProcessingState.idle,
        },
        playing: _wantsPlayback && phase != RadioPhase.error,
        errorCode: error == null ? null : 1,
        errorMessage: error,
      ),
    );
  }

  Future<void> select(Station station) async {
    _cancelPending();
    _station = station;
    _title = '';
    _attempts = 0;
    _wantsPlayback = true;
    _failed = false;
    _updateMediaItem();
    unawaited(_storage.rememberStation(station).catchError((Object _) {}));
    // Popularity tracking must never prevent playback.
    unawaited(_client.registerPlay(station.id).catchError((Object _) {}));
    await _open();
  }

  Future<void> _open() async {
    final station = _station;
    if (station == null || _disposed || !_wantsPlayback) return;
    final generation = ++_generation;
    _opening = true;
    _failed = false;
    _publish(RadioPhase.loading);
    try {
      await _player
          .setUrl(station.streamUrl)
          .timeout(const Duration(seconds: 10));
      if (generation != _generation || !_wantsPlayback) return;
      _opening = false;
      unawaited(
        _player.play().catchError((Object _) {
          if (generation == _generation) _recover();
        }),
      );
      // setUrl can emit ready while _opening suppresses events. When switching
      // an already-playing stream, play() need not emit another state event.
      _onPlayerState(_player.playerState);
    } on Object {
      if (generation != _generation) return;
      _opening = false;
      _recover();
    }
  }

  void _recover() {
    if (_disposed || !_wantsPlayback || _retry != null || _opening) return;
    _watchdog?.cancel();
    _watchdog = null;
    if (_attempts >= 3) {
      _failed = true;
      _wantsPlayback = false;
      unawaited(_player.stop());
      _publish(
        RadioPhase.error,
        error: 'Stacja jest niedostępna. Spróbuj ponownie lub wybierz inną.',
      );
      return;
    }
    _attempts++;
    _publish(RadioPhase.buffering);
    _retry = Timer(Duration(seconds: 1 << (_attempts - 1)), () {
      _retry = null;
      unawaited(_open());
    });
  }

  void _cancelPending() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    _watchdog?.cancel();
    _watchdog = null;
    _opening = false;
  }

  @override
  Future<void> play() async {
    if (_station != null) await select(_station!);
  }

  @override
  Future<void> pause() async {
    _cancelPending();
    _wantsPlayback = false;
    await _player.pause();
    _publish(RadioPhase.paused);
  }

  @override
  Future<void> stop() async {
    _cancelPending();
    _wantsPlayback = false;
    _failed = false;
    await _player.stop();
    _publish(RadioPhase.idle);
  }

  @override
  Future<void> onTaskRemoved() => stop();

  @override
  Future<void> onNotificationDeleted() => stop();

  Future<void> changeVolume(double volume) async {
    _volume = volume.clamp(0, 1);
    await _player.setVolume(_volume);
    _publish(snapshot.value.phase, error: snapshot.value.error);
    await _storage.saveVolume(_volume);
  }

  Future<void> close() async {
    _disposed = true;
    _cancelPending();
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
    snapshot.dispose();
  }
}
