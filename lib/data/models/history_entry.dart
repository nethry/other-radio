import 'station.dart';

/// One listening session. `end` is advanced while the station keeps playing so
/// an app kill still leaves a usable duration.
class HistoryEntry {
  const HistoryEntry({
    required this.station,
    required this.start,
    required this.end,
  });

  final Station station;
  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  HistoryEntry copyWith({DateTime? end}) =>
      HistoryEntry(station: station, start: start, end: end ?? this.end);

  Map<String, dynamic> toJson() => {
    'station': station.toJson(),
    'start': start.millisecondsSinceEpoch,
    'end': end.millisecondsSinceEpoch,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    station: Station.fromJson(
      Map<String, dynamic>.from(json['station'] as Map),
    ),
    start: DateTime.fromMillisecondsSinceEpoch(json['start'] as int),
    end: DateTime.fromMillisecondsSinceEpoch(json['end'] as int),
  );
}
