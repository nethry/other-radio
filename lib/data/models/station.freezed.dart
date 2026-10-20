// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'station.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Station {

@JsonKey(name: 'stationuuid') String get id; String get name;@JsonKey(name: 'url_resolved') String get streamUrl; String get favicon; String get tags; String get codec; int get bitrate; int get clickcount; String get state; String get language; String get homepage; String get countrycode;
/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StationCopyWith<Station> get copyWith => _$StationCopyWithImpl<Station>(this as Station, _$identity);

  /// Serializes this Station to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Station;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Station&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.streamUrl, _this.streamUrl) || other.streamUrl == _this.streamUrl)&&(identical(other.favicon, _this.favicon) || other.favicon == _this.favicon)&&(identical(other.tags, _this.tags) || other.tags == _this.tags)&&(identical(other.codec, _this.codec) || other.codec == _this.codec)&&(identical(other.bitrate, _this.bitrate) || other.bitrate == _this.bitrate)&&(identical(other.clickcount, _this.clickcount) || other.clickcount == _this.clickcount)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.homepage, _this.homepage) || other.homepage == _this.homepage)&&(identical(other.countrycode, _this.countrycode) || other.countrycode == _this.countrycode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Station;
  return Object.hash(runtimeType,_this.id,_this.name,_this.streamUrl,_this.favicon,_this.tags,_this.codec,_this.bitrate,_this.clickcount,_this.state,_this.language,_this.homepage,_this.countrycode);
}

@override
String toString() {
  final _this = this as Station;
  return 'Station(id: ${_this.id}, name: ${_this.name}, streamUrl: ${_this.streamUrl}, favicon: ${_this.favicon}, tags: ${_this.tags}, codec: ${_this.codec}, bitrate: ${_this.bitrate}, clickcount: ${_this.clickcount}, state: ${_this.state}, language: ${_this.language}, homepage: ${_this.homepage}, countrycode: ${_this.countrycode})';
}


}

/// @nodoc
abstract mixin class $StationCopyWith<$Res>  {
  factory $StationCopyWith(Station value, $Res Function(Station) _then) = _$StationCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'stationuuid') String id, String name,@JsonKey(name: 'url_resolved') String streamUrl, String favicon, String tags, String codec, int bitrate, int clickcount, String state, String language, String homepage, String countrycode
});




}
/// @nodoc
class _$StationCopyWithImpl<$Res>
    implements $StationCopyWith<$Res> {
  _$StationCopyWithImpl(this._self, this._then);

  final Station _self;
  final $Res Function(Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? streamUrl = null,Object? favicon = null,Object? tags = null,Object? codec = null,Object? bitrate = null,Object? clickcount = null,Object? state = null,Object? language = null,Object? homepage = null,Object? countrycode = null,}) {
  return _then(Station(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String,favicon: null == favicon ? _self.favicon : favicon // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as String,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,bitrate: null == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int,clickcount: null == clickcount ? _self.clickcount : clickcount // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,homepage: null == homepage ? _self.homepage : homepage // ignore: cast_nullable_to_non_nullable
as String,countrycode: null == countrycode ? _self.countrycode : countrycode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Station].
extension StationPatterns on Station {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Station value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Station value)  $default,){
final _that = this;
switch (_that) {
case _Station():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Station value)?  $default,){
final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'stationuuid')  String id,  String name, @JsonKey(name: 'url_resolved')  String streamUrl,  String favicon,  String tags,  String codec,  int bitrate,  int clickcount,  String state,  String language,  String homepage,  String countrycode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.id,_that.name,_that.streamUrl,_that.favicon,_that.tags,_that.codec,_that.bitrate,_that.clickcount,_that.state,_that.language,_that.homepage,_that.countrycode);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'stationuuid')  String id,  String name, @JsonKey(name: 'url_resolved')  String streamUrl,  String favicon,  String tags,  String codec,  int bitrate,  int clickcount,  String state,  String language,  String homepage,  String countrycode)  $default,) {final _that = this;
switch (_that) {
case _Station():
return $default(_that.id,_that.name,_that.streamUrl,_that.favicon,_that.tags,_that.codec,_that.bitrate,_that.clickcount,_that.state,_that.language,_that.homepage,_that.countrycode);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'stationuuid')  String id,  String name, @JsonKey(name: 'url_resolved')  String streamUrl,  String favicon,  String tags,  String codec,  int bitrate,  int clickcount,  String state,  String language,  String homepage,  String countrycode)?  $default,) {final _that = this;
switch (_that) {
case _Station() when $default != null:
return $default(_that.id,_that.name,_that.streamUrl,_that.favicon,_that.tags,_that.codec,_that.bitrate,_that.clickcount,_that.state,_that.language,_that.homepage,_that.countrycode);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Station extends Station {
  const _Station({@JsonKey(name: 'stationuuid') required this.id, required this.name, @JsonKey(name: 'url_resolved') required this.streamUrl, this.favicon = '', this.tags = '', this.codec = '', this.bitrate = 0, this.clickcount = 0, this.state = '', this.language = '', this.homepage = '', this.countrycode = ''}): super._();
  factory _Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);

@override@JsonKey(name: 'stationuuid') final  String id;
@override final  String name;
@override@JsonKey(name: 'url_resolved') final  String streamUrl;
@override@JsonKey() final  String favicon;
@override@JsonKey() final  String tags;
@override@JsonKey() final  String codec;
@override@JsonKey() final  int bitrate;
@override@JsonKey() final  int clickcount;
@override@JsonKey() final  String state;
@override@JsonKey() final  String language;
@override@JsonKey() final  String homepage;
@override@JsonKey() final  String countrycode;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StationCopyWith<_Station> get copyWith => __$StationCopyWithImpl<_Station>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Station&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.streamUrl, streamUrl) || other.streamUrl == streamUrl)&&(identical(other.favicon, favicon) || other.favicon == favicon)&&(identical(other.tags, tags) || other.tags == tags)&&(identical(other.codec, codec) || other.codec == codec)&&(identical(other.bitrate, bitrate) || other.bitrate == bitrate)&&(identical(other.clickcount, clickcount) || other.clickcount == clickcount)&&(identical(other.state, state) || other.state == state)&&(identical(other.language, language) || other.language == language)&&(identical(other.homepage, homepage) || other.homepage == homepage)&&(identical(other.countrycode, countrycode) || other.countrycode == countrycode));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,streamUrl,favicon,tags,codec,bitrate,clickcount,state,language,homepage,countrycode);
}

@override
String toString() {
    return 'Station(id: $id, name: $name, streamUrl: $streamUrl, favicon: $favicon, tags: $tags, codec: $codec, bitrate: $bitrate, clickcount: $clickcount, state: $state, language: $language, homepage: $homepage, countrycode: $countrycode)';
}


}

/// @nodoc
abstract mixin class _$StationCopyWith<$Res> implements $StationCopyWith<$Res> {
  factory _$StationCopyWith(_Station value, $Res Function(_Station) _then) = __$StationCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'stationuuid') String id, String name,@JsonKey(name: 'url_resolved') String streamUrl, String favicon, String tags, String codec, int bitrate, int clickcount, String state, String language, String homepage, String countrycode
});




}
/// @nodoc
class __$StationCopyWithImpl<$Res>
    implements _$StationCopyWith<$Res> {
  __$StationCopyWithImpl(this._self, this._then);

  final _Station _self;
  final $Res Function(_Station) _then;

/// Create a copy of Station
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? streamUrl = null,Object? favicon = null,Object? tags = null,Object? codec = null,Object? bitrate = null,Object? clickcount = null,Object? state = null,Object? language = null,Object? homepage = null,Object? countrycode = null,}) {
  return _then(_Station(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,streamUrl: null == streamUrl ? _self.streamUrl : streamUrl // ignore: cast_nullable_to_non_nullable
as String,favicon: null == favicon ? _self.favicon : favicon // ignore: cast_nullable_to_non_nullable
as String,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as String,codec: null == codec ? _self.codec : codec // ignore: cast_nullable_to_non_nullable
as String,bitrate: null == bitrate ? _self.bitrate : bitrate // ignore: cast_nullable_to_non_nullable
as int,clickcount: null == clickcount ? _self.clickcount : clickcount // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as String,language: null == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String,homepage: null == homepage ? _self.homepage : homepage // ignore: cast_nullable_to_non_nullable
as String,countrycode: null == countrycode ? _self.countrycode : countrycode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
