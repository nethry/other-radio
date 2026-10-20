import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:other_radio/audio/playback_controller.dart';
import 'package:other_radio/audio/radio_audio_handler.dart';
import 'package:other_radio/data/api/radio_browser_client.dart';
import 'package:other_radio/data/local/radio_storage.dart';
import 'package:other_radio/data/models/station.dart';

class _Player extends Mock implements AudioPlayer {}

class _Client extends Mock implements RadioBrowserClient {}

class _Storage extends Mock implements RadioStorage {}

const station = Station(
  id: 'one',
  name: 'Radio Test',
  streamUrl: 'https://example.org/live',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Player player;
  late _Client client;
  late _Storage storage;
  late RadioAudioHandler handler;
  late StreamController<PlayerState> states;

  setUp(() {
    player = _Player();
    client = _Client();
    storage = _Storage();
    states = StreamController<PlayerState>.broadcast(sync: true);
    when(() => player.playerStateStream).thenAnswer((_) => states.stream);
    when(() => player.playerState)
        .thenReturn(PlayerState(true, ProcessingState.ready));
    when(() => player.errorStream).thenAnswer((_) => const Stream.empty());
    when(() => player.icyMetadataStream)
        .thenAnswer((_) => const Stream.empty());
    when(() => player.setVolume(any())).thenAnswer((_) async {});
    when(() => player.setUrl(any())).thenAnswer((_) async => null);
    when(player.play).thenAnswer((_) async {});
    when(player.pause).thenAnswer((_) async {});
    when(player.stop).thenAnswer((_) async {});
    when(player.dispose).thenAnswer((_) async {});
    when(() => storage.lastStation).thenReturn(station);
    when(() => storage.volume).thenReturn(0.4);
    when(() => storage.rememberStation(station)).thenAnswer((_) async {});
    when(() => client.registerPlay(station.id)).thenAnswer((_) async {});
    handler = RadioAudioHandler(client, storage, player: player);
  });

  tearDown(() async {
    await handler.close();
    await states.close();
  });

  test(
    'restores last station without playing and ignores click tracking failures',
    () async {
      expect(handler.snapshot.value.station, station);
      expect(handler.snapshot.value.phase, RadioPhase.idle);
      verifyNever(player.play);
      when(() => client.registerPlay(station.id))
          .thenThrow(StateError('API offline'));
      // Simulate an asynchronous API failure, as with a real HTTP request.
      when(() => client.registerPlay(station.id))
          .thenAnswer((_) async => throw StateError('API offline'));
      await handler.play();
      verify(() => player.setUrl(station.streamUrl)).called(1);
      verify(player.play).called(1);
      states.add(PlayerState(true, ProcessingState.ready));
      expect(handler.snapshot.value.phase, RadioPhase.playing);
      await handler.pause();
      expect(handler.snapshot.value.phase, RadioPhase.paused);
    },
  );

  test('stopping an in-flight station load prevents late autoplay', () async {
    final pending = Completer<Duration?>();
    when(() => player.setUrl(any())).thenAnswer((_) => pending.future);
    final opening = handler.select(station);
    expect(handler.snapshot.value.phase, RadioPhase.loading);
    await handler.stop();
    pending.complete(null);
    await opening;
    verifyNever(player.play);
    expect(handler.snapshot.value.phase, RadioPhase.idle);
  });

  test(
    'station switch reconciles ready emitted before setUrl completes',
    () async {
      await handler.select(station);
      states.add(PlayerState(true, ProcessingState.ready));
      final next = station.copyWith(
        id: 'two',
        streamUrl: 'https://example.org/two',
      );
      when(() => storage.rememberStation(next)).thenAnswer((_) async {});
      when(() => client.registerPlay(next.id)).thenAnswer((_) async {});
      when(() => player.setUrl(next.streamUrl)).thenAnswer((_) async {
        states.add(PlayerState(true, ProcessingState.ready));
        return null;
      });
      // play() is already active and emits nothing on this station switch.
      await handler.select(next);
      expect(handler.snapshot.value.station, next);
      expect(handler.snapshot.value.phase, RadioPhase.playing);
      expect(handler.snapshot.value.busy, false);
      expect(handler.playbackState.value.playing, true);
    },
  );

  for (final event in ['task removal', 'notification dismissal']) {
    Future<void> dismiss() => event == 'task removal'
        ? handler.onTaskRemoved()
        : handler.onNotificationDeleted();

    test(
      '$event stops active audio and clears the media session state',
      () async {
        await handler.select(station);
        await dismiss();
        verify(player.stop).called(1);
        expect(handler.snapshot.value.phase, RadioPhase.idle);
        expect(handler.playbackState.value.playing, false);
      },
    );

    test('$event cancels in-flight loading without late autoplay', () async {
      final pending = Completer<Duration?>();
      when(() => player.setUrl(any())).thenAnswer((_) => pending.future);
      final opening = handler.select(station);
      await dismiss();
      pending.complete(null);
      await opening;
      verifyNever(player.play);
      expect(handler.snapshot.value.phase, RadioPhase.idle);
    });

    testWidgets('$event cancels pending reconnect attempts', (tester) async {
      when(() => player.setUrl(any()))
          .thenAnswer((_) async => throw StateError('offline'));
      await handler.select(station);
      await dismiss();
      await tester.pump(const Duration(seconds: 10));
      verify(() => player.setUrl(station.streamUrl)).called(1);
      verifyNever(player.play);
      expect(handler.snapshot.value.phase, RadioPhase.idle);
    });
  }

  testWidgets(
    'failed streams retry three times, then present a recoverable Polish error',
    (tester) async {
      when(() => player.setUrl(any()))
          .thenAnswer((_) async => throw StateError('stream offline'));
      await handler.select(station);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 4));
      expect(handler.snapshot.value.phase, RadioPhase.error);
      expect(handler.snapshot.value.error, contains('Stacja jest niedostępna'));
      verify(() => player.setUrl(station.streamUrl)).called(4);
      when(() => player.setUrl(any())).thenAnswer((_) async => null);
      await handler.play();
      verify(player.play).called(1);
    },
  );

  test(
    'previous and next move through the list a station was picked from',
    () async {
      final two = station.copyWith(
        id: 'two',
        streamUrl: 'https://example.org/two',
      );
      final three = station.copyWith(
        id: 'three',
        streamUrl: 'https://example.org/three',
      );
      for (final s in [two, three]) {
        when(() => storage.rememberStation(s)).thenAnswer((_) async {});
        when(() => client.registerPlay(s.id)).thenAnswer((_) async {});
      }
      final controller = PlaybackController(
        handler,
        fallbackQueue: () => const [],
      );
      await controller.select(
        two,
        queue: [station, two, three],
        source: 'Ulubionych',
      );
      expect(controller.source, 'Ulubionych');
      expect(controller.canSkip, isTrue);
      await controller.next();
      expect(handler.snapshot.value.station, three);
      await controller.next();
      expect(handler.snapshot.value.station, station);
      await controller.previous();
      expect(handler.snapshot.value.station, three);
      verify(() => player.setUrl(three.streamUrl)).called(2);
      controller.dispose();
    },
  );
}
