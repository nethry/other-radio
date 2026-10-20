import 'dart:math';

import 'package:dio/dio.dart';

import '../models/station.dart';

class RadioBrowserClient {
  RadioBrowserClient(this._dio);

  final Dio _dio;
  List<String>? _servers;
  String? _selected;

  static bool _isTransient(DioException error) => switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.unknown => true,
    DioExceptionType.badResponse => (error.response?.statusCode ?? 0) >= 500,
    _ => false,
  };

  Future<Response<dynamic>> _request(
    String url, {
    Map<String, dynamic>? query,
    bool retry = true,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await _dio.get<dynamic>(url, queryParameters: query);
      } on DioException catch (error) {
        // Radio Browser occasionally resets TLS/socket connections. Retry only
        // transient failures; never bypass certificate checks or retry 4xx.
        if (!retry || attempt >= 2 || !_isTransient(error)) rethrow;
        await Future<void>.delayed(
          Duration(milliseconds: 300 * (1 << attempt)),
        );
      }
    }
  }

  Future<List<String>> _discover() async {
    if (_servers != null) return _servers!;
    final response = await _request(
      'https://all.api.radio-browser.info/json/servers',
    );
    final servers =
        (response.data as List)
            .whereType<Map>()
            .map((entry) => entry['name'])
            .whereType<String>()
            .where(
              (host) =>
                  RegExp(r'^[a-z0-9-]+\.api\.radio-browser\.info$')
                      .hasMatch(host),
            )
            .toSet()
            .toList()
          ..shuffle(Random());
    if (servers.isEmpty) throw StateError('Brak serwerów radia');
    return _servers = servers;
  }

  Future<dynamic> _get(
    String path, {
    Map<String, dynamic>? query,
    bool retry = true,
  }) async {
    final servers = await _discover();
    final ordered = {?_selected, ...servers};
    Object? lastError;
    for (final server in ordered) {
      try {
        final response = await _request(
          'https://$server/json/$path',
          query: query,
          retry: retry,
        );
        _selected = server;
        return response.data;
      } catch (error) {
        lastError = error;
      }
    }
    _servers = null;
    _selected = null;
    throw lastError ?? StateError('Brak połączenia');
  }

  Future<List<Station>> stations() async {
    final data = await _get(
      'stations/search',
      query: {
        'countrycode': 'PL',
        'hidebroken': true,
        'order': 'clickcount',
        'reverse': true,
        'limit': 1000,
      },
    );
    final result = <Station>[];
    for (final row in data as List) {
      try {
        result.add(Station.fromJson(Map<String, dynamic>.from(row as Map)));
      } on Object {
        // One malformed community record must not discard the catalogue.
      }
    }
    return result;
  }

  Future<void> registerPlay(String id) async {
    await _get('url/${Uri.encodeComponent(id)}', retry: false);
  }
}
