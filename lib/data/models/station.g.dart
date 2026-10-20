// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'station.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Station _$StationFromJson(Map<String, dynamic> json) => _Station(
  id: json['stationuuid'] as String,
  name: json['name'] as String,
  streamUrl: json['url_resolved'] as String,
  favicon: json['favicon'] as String? ?? '',
  tags: json['tags'] as String? ?? '',
  codec: json['codec'] as String? ?? '',
  bitrate: (json['bitrate'] as num?)?.toInt() ?? 0,
  clickcount: (json['clickcount'] as num?)?.toInt() ?? 0,
  state: json['state'] as String? ?? '',
  language: json['language'] as String? ?? '',
  homepage: json['homepage'] as String? ?? '',
  countrycode: json['countrycode'] as String? ?? '',
);

Map<String, dynamic> _$StationToJson(_Station instance) => <String, dynamic>{
  'stationuuid': instance.id,
  'name': instance.name,
  'url_resolved': instance.streamUrl,
  'favicon': instance.favicon,
  'tags': instance.tags,
  'codec': instance.codec,
  'bitrate': instance.bitrate,
  'clickcount': instance.clickcount,
  'state': instance.state,
  'language': instance.language,
  'homepage': instance.homepage,
  'countrycode': instance.countrycode,
};
