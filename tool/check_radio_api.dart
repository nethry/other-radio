import 'dart:io';

import 'package:dio/dio.dart';
import 'package:other_radio/data/api/radio_browser_client.dart';

// Read-only network smoke check: does not register plays or open audio streams.
Future<void> main(List<String> args) async {
  final country = args.isEmpty ? 'PL' : args.first.toUpperCase();
  final scope = country == 'ALL' ? '' : country;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'OtherRadio/0.2.1 (worldwide catalogue smoke check; pl.otherradio.other_radio)',
      },
    ),
  );
  try {
    final stations = await RadioBrowserClient(dio).stations(countryCode: scope);
    if (stations.isEmpty) throw StateError('No usable stations for $country');
    if (scope.isNotEmpty && stations.any((s) => s.countrycode != scope)) {
      throw StateError('Catalogue contains stations outside $scope');
    }
    stdout.writeln(
      'OK: ${stations.length} station records for $country; first: ${stations.first.name}',
    );
  } finally {
    dio.close();
  }
}
