import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:other_radio/core/theme.dart';
import 'package:other_radio/core/ui/art.dart';
import 'package:other_radio/data/models/station.dart';

const _station = Station(
  id: 'eska-rock',
  name: 'ESKA ROCK',
  streamUrl: 'https://example.org/live',
);

Widget _host(Widget child) => MaterialApp(
  theme: radioTheme(calm: true),
  home: Center(child: child),
);

void main() {
  testWidgets('tiles use the Radio Browser favicon with a monogram fallback', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        StationTile(
          station: _station.copyWith(favicon: 'https://example.org/logo.png'),
          width: 120,
        ),
      ),
    );
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'https://example.org/logo.png');
    // The monogram shows until the image decodes (or if it never does).
    expect(find.text('ESKA'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
  });

  testWidgets('non-web favicons never reach the image loader', (tester) async {
    await tester.pumpWidget(
      _host(
        StationTile(
          station: _station.copyWith(favicon: 'file:///etc/passwd'),
          width: 48,
        ),
      ),
    );
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('ESKA'), findsOneWidget);
  });

  testWidgets('logo shows the waveform and other/radio wordmark', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Brand()));
    expect(find.byIcon(Icons.graphic_eq_rounded), findsOneWidget);
    expect(find.text('otherradio', findRichText: true), findsOneWidget);
  });
}
