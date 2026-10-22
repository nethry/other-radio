import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/format.dart';
import '../../data/local/radio_storage.dart';
import '../../data/models/history_entry.dart';
import '../../data/models/station.dart';

typedef HistoryGroup = ({String label, List<HistoryEntry> entries});
typedef TopStation = ({Station station, Duration listened});

/// Records listening sessions from playback state. Sessions of the same
/// station separated by a short pause are merged into one entry.
class HistoryController extends ChangeNotifier {
  HistoryController(this.storage, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    entries = storage.readHistory();
  }

  static const maxEntries = 300;
  static const mergeGap = Duration(minutes: 5);

  final RadioStorage storage;
  final DateTime Function() _clock;

  /// Newest first.
  List<HistoryEntry> entries = [];
  HistoryEntry? _open;
  Timer? _tick;
  bool _disposed = false;
  String query = '';

  bool isOpen(HistoryEntry entry) => identical(entry, _open);

  /// Called whenever playback changes.
  void observe(Station? station, {required bool playing}) {
    final now = _clock();
    if (playing && station != null) {
      if (_open?.station.id == station.id) return;
      _close(now);
      final last = entries.isEmpty ? null : entries.first;
      final HistoryEntry entry;
      if (last != null &&
          last.station.id == station.id &&
          now.difference(last.end) < mergeGap) {
        entry = HistoryEntry(station: station, start: last.start, end: now);
        entries = [entry, ...entries.skip(1)];
      } else {
        entry = HistoryEntry(station: station, start: now, end: now);
        entries = [entry, ...entries].take(maxEntries).toList();
      }
      _open = entry;
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 30), (_) => _extend());
      _persist();
    } else if (_open != null) {
      _close(now);
      _persist();
    }
  }

  void _extend() {
    final open = _open;
    if (open == null || entries.isEmpty) return;
    final updated = open.copyWith(end: _clock());
    entries = [updated, ...entries.skip(1)];
    _open = updated;
    _persist();
  }

  void _close(DateTime now) {
    final open = _open;
    _tick?.cancel();
    _tick = null;
    _open = null;
    if (open == null || entries.isEmpty) return;
    entries = [open.copyWith(end: now), ...entries.skip(1)];
  }

  void _persist() {
    if (_disposed) return;
    notifyListeners();
    storage.writeHistory(entries).catchError((Object _) {});
  }

  Future<void> clear() async {
    _tick?.cancel();
    _tick = null;
    _open = null;
    entries = [];
    notifyListeners();
    try {
      await storage.writeHistory(entries);
    } on Object {
      // Nothing to restore; an empty in-memory list is still correct.
    }
  }

  void filter(String value) {
    query = value;
    notifyListeners();
  }

  Duration listened(HistoryEntry entry) =>
      isOpen(entry) ? _clock().difference(entry.start) : entry.duration;

  List<HistoryGroup> get groups => groupsFor('pl');

  List<HistoryGroup> groupsFor(String language) {
    final now = _clock();
    final q = query.trim().toLowerCase();
    final result = <HistoryGroup>[];
    for (final entry in entries) {
      if (q.isNotEmpty && !entry.station.name.toLowerCase().contains(q)) {
        continue;
      }
      final label = dayLabel(entry.start, now, language: language);
      if (result.isEmpty || result.last.label != label) {
        result.add((label: label, entries: [entry]));
      } else {
        result.last.entries.add(entry);
      }
    }
    return result;
  }

  /// Most-listened stations over the last seven days.
  List<TopStation> top(int count) {
    final since = _clock().subtract(const Duration(days: 7));
    final totals = <String, Duration>{};
    final stations = <String, Station>{};
    for (final entry in entries) {
      if (entry.end.isBefore(since)) continue;
      final id = entry.station.id;
      totals[id] = (totals[id] ?? Duration.zero) + listened(entry);
      stations.putIfAbsent(id, () => entry.station);
    }
    final ranked = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in ranked.take(count))
        (station: stations[e.key]!, listened: e.value),
    ];
  }

  /// When each station was last heard, for "Ostatnio" sorting.
  Map<String, DateTime> get lastPlayed {
    final result = <String, DateTime>{};
    for (final entry in entries) {
      result.putIfAbsent(entry.station.id, () => entry.end);
    }
    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _tick?.cancel();
    super.dispose();
  }
}
