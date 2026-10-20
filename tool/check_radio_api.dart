import 'dart:io';

import 'package:dio/dio.dart';
import 'package:other_radio/data/api/radio_browser_client.dart';

// Read-only network smoke check: does not register plays or open audio streams.
Future<void> main() async {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'User-Agent': 'OtherRadio/0.1.0 (catalogue smoke check; pl.otherradio.other_radio)',
      },
    ),
  );
  try {
    final stations = await RadioBrowserClient(dio).stations();
    if (stations.isEmpty) throw StateError('No usable Polish stations');
    stdout.writeln(
      'OK: ${stations.length} Polish station records; first: ${stations.first.name}',
    );
  } finally {
    dio.close();
  }
}
