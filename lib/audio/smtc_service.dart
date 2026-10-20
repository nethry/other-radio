import 'dart:async';

import 'package:smtc_windows/smtc_windows.dart';

import 'radio_audio_handler.dart';

class SmtcService {
  SmtcService(this.handler) {
    _smtc = SMTCWindows(
      config: const SMTCConfig(
        playEnabled: true,
        pauseEnabled: true,
        stopEnabled: true,
        fastForwardEnabled: false,
        nextEnabled: false,
        prevEnabled: false,
        rewindEnabled: false,
      ),
    );
    _buttons = _smtc.buttonPressStream.listen((button) {
      switch (button) {
        case PressedButton.play:
          unawaited(handler.play());
        case PressedButton.pause:
          unawaited(handler.pause());
        case PressedButton.stop:
          unawaited(handler.stop());
        default:
          break;
      }
    });
    handler.snapshot.addListener(_sync);
    _sync();
  }

  final RadioAudioHandler handler;
  late final SMTCWindows _smtc;
  late final StreamSubscription<PressedButton> _buttons;

  void _sync() {
    final state = handler.snapshot.value;
    final station = state.station;
    // System media controls are cosmetic; a native failure (smtc_windows
    // unwraps URI parsing in Rust) must not surface as an unhandled error.
    if (station != null) {
      unawaited(
        _smtc
            .updateMetadata(
              MusicMetadata(
                title: state.title.isEmpty ? station.name : state.title,
                artist: station.name,
                album: 'OtherRadio • Na żywo',
                thumbnail: station.artUri?.toString(),
              ),
            )
            .catchError((Object _) {}),
      );
    }
    unawaited(
      _smtc
          .setPlaybackStatus(switch (state.phase) {
            RadioPhase.playing => PlaybackStatus.playing,
            RadioPhase.paused => PlaybackStatus.paused,
            RadioPhase.loading ||
            RadioPhase.buffering => PlaybackStatus.changing,
            _ => PlaybackStatus.stopped,
          })
          .catchError((Object _) {}),
    );
  }

  void dispose() {
    handler.snapshot.removeListener(_sync);
    unawaited(_buttons.cancel());
    _smtc.dispose();
  }
}
