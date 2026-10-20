import 'package:freezed_annotation/freezed_annotation.dart';

part 'station.freezed.dart';
part 'station.g.dart';

@freezed
abstract class Station with _$Station {
  const Station._();

  const factory Station({
    @JsonKey(name: 'stationuuid') required String id,
    required String name,
    @JsonKey(name: 'url_resolved') required String streamUrl,
    @Default('') String favicon,
    @Default('') String tags,
    @Default('') String codec,
    @Default(0) int bitrate,
    @Default(0) int clickcount,
    @Default('') String state,
    @Default('') String language,
    @Default('') String homepage,
    @Default('') String countrycode,
  }) = _Station;

  factory Station.fromJson(Map<String, dynamic> json) =>
      _$StationFromJson(json);

  /// Community-supplied artwork, limited to web URLs. Native consumers such as
  /// SMTC would otherwise receive arbitrary schemes or panic on malformed text.
  Uri? get artUri {
    final uri = Uri.tryParse(favicon.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

  /// Station website, limited to web URLs like [artUri].
  Uri? get homepageUri {
    final uri = Uri.tryParse(homepage.trim());
    if (uri == null || uri.host.isEmpty) return null;
    return uri.scheme == 'http' || uri.scheme == 'https' ? uri : null;
  }

  List<String> get genres => tags
      .split(',')
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();
}
