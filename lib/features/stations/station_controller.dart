import 'package:flutter/foundation.dart';

import '../../core/format.dart';
import '../../data/models/station.dart';
import '../../data/repositories/station_repository.dart';

/// Top-level destinations, in navigation order.
enum AppPage { browse, search, favorites, history, settings }

/// Genre chips on the browse screen and the tags each one matches.
enum Genre {
  all('Wszystkie', []),
  pop('Pop', ['pop', 'hits', 'przeboje', 'top 40']),
  rock('Rock', ['rock', 'metal', 'alternatyw', 'alternative', 'punk']),
  news('Informacje', ['news', 'informac', 'wiadomości', 'information']),
  talk('Rozmowy', ['talk', 'rozmow', 'publicystyka', 'kultura', 'culture']),
  classical('Klasyka', ['classical', 'klasycz', 'klasyka', 'opera']),
  jazz('Jazz', ['jazz', 'blues', 'swing']),
  regional('Regionalne', ['regional', 'region', 'lokaln', 'local']);

  const Genre(this.label, this.keys);
  final String label;
  final List<String> keys;

  bool matches(Station s) =>
      keys.isEmpty || s.genres.any((g) => keys.any(g.contains));
}

enum BrowseSort { popular, az }

enum SearchSort {
  relevance('Trafność'),
  az('Nazwa A–Z'),
  bitrate('Jakość');

  const SearchSort(this.label);
  final String label;
}

enum FavoriteSort { own, az, recent }

class StationController extends ChangeNotifier {
  StationController(this.repository) {
    countryCode = repository.defaultCountry;
    stations = repository.cachedFor(countryCode);
    favorites = repository.favorites;
    try {
      recentSearches = repository.recentSearches;
    } on Object {
      recentSearches = [];
    }
  }

  static const maxRecentSearches = 6;

  final StationRepository repository;
  List<Station> stations = [];
  List<Station> favorites = [];
  List<String> recentSearches = [];
  bool loading = false;
  bool _disposed = false;
  late String countryCode;
  int _request = 0;

  Future<void> setCountry(String value) async {
    if (countryCode == value) return;
    countryCode = value;
    stations = repository.cachedFor(value);
    searchPlace = null;
    searchGenre = null;
    await refresh(force: true);
  }

  String? error;
  AppPage page = AppPage.browse;
  int searchFocusRequest = 0;

  void focusSearch() {
    page = AppPage.search;
    searchFocusRequest++;
    notifyListeners();
  }

  // Browse
  Genre genre = Genre.all;
  BrowseSort browseSort = BrowseSort.popular;

  // Search
  String query = '';
  String? searchGenre;
  String? searchPlace;
  bool highQuality = false;
  bool httpsOnly = false;
  SearchSort searchSort = SearchSort.relevance;

  // Favourites
  FavoriteSort favoriteSort = FavoriteSort.own;

  bool isFavorite(Station station) => favorites.any((s) => s.id == station.id);

  /// Browse list: whole catalogue filtered by the genre chip.
  List<Station> get visible {
    final list = stations.where(genre.matches).toList();
    if (browseSort == BrowseSort.az) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return list;
  }

  bool get hasSearchFilters =>
      searchGenre != null || searchPlace != null || highQuality || httpsOnly;

  bool get searching => query.trim().isNotEmpty || hasSearchFilters;

  /// Search results across name, tags and region.
  List<Station> get results {
    if (!searching) return const [];
    final q = query.trim().toLowerCase();
    int score(Station s) {
      if (q.isEmpty) return 1;
      final name = s.name.toLowerCase();
      if (name.startsWith(q)) return 4;
      if (name.contains(q)) return 3;
      if (s.genres.any((g) => g.contains(q))) return 2;
      if (s.state.toLowerCase().contains(q)) return 1;
      return 0;
    }

    final scored = <(Station, int)>[];
    for (final s in stations) {
      if (searchGenre != null && !s.genres.contains(searchGenre)) continue;
      if (searchPlace != null && place(s) != searchPlace) continue;
      if (highQuality && s.bitrate < 128) continue;
      if (httpsOnly && !s.streamUrl.startsWith('https://')) continue;
      final value = score(s);
      if (value > 0) scored.add((s, value));
    }
    switch (searchSort) {
      case SearchSort.relevance:
        // Catalogue order is popularity, so a stable sort keeps it as the
        // tie-breaker.
        mergeSort(scored, compare: (a, b) => b.$2.compareTo(a.$2));
      case SearchSort.az:
        scored.sort(
          (a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()),
        );
      case SearchSort.bitrate:
        mergeSort(
          scored,
          compare: (a, b) => b.$1.bitrate.compareTo(a.$1.bitrate),
        );
    }
    return [for (final r in scored) r.$1];
  }

  /// Most common tags, for genre pickers.
  List<String> popularTags([int count = 24]) {
    final counts = <String, int>{};
    for (final s in stations) {
      for (final g in s.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in ranked.take(count)) e.key];
  }

  /// Regions present in the catalogue, alphabetically.
  List<String> get places {
    final set = {for (final s in stations) place(s)};
    return set.toList()..sort();
  }

  /// Tags that co-occur with the current results, excluding the query.
  List<String> relatedTags(List<Station> results, [int count = 6]) {
    final q = query.trim().toLowerCase();
    final counts = <String, int>{};
    for (final s in results.take(200)) {
      for (final g in s.genres) {
        if (g == q || g == searchGenre) continue;
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final ranked = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in ranked.take(count)) e.key];
  }

  /// Favourites in the chosen order. [lastPlayed] comes from history.
  List<Station> sortedFavorites([Map<String, DateTime> lastPlayed = const {}]) {
    final list = [...favorites];
    switch (favoriteSort) {
      case FavoriteSort.own:
        break;
      case FavoriteSort.az:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case FavoriteSort.recent:
        final epoch = DateTime.fromMillisecondsSinceEpoch(0);
        mergeSort(
          list,
          compare: (a, b) =>
              (lastPlayed[b.id] ?? epoch).compareTo(lastPlayed[a.id] ?? epoch),
        );
    }
    return list;
  }

  Future<void> refresh({bool force = false}) async {
    if (loading && !force) return;
    final request = ++_request;
    final country = countryCode;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final next = await repository.refresh(countryCode: country);
      if (_disposed || request != _request) return;
      stations = next;
      if (kDebugMode) {
        debugPrint('Station catalogue refreshed: ${stations.length} stations');
      }
    } catch (failure) {
      if (_disposed || request != _request) return;
      if (kDebugMode) debugPrint('Station catalogue refresh failed: $failure');
      error = stations.isEmpty
          ? 'Nie udało się pobrać katalogu stacji. Spróbuj ponownie.'
          : 'Nie udało się odświeżyć katalogu. Wyświetlamy zapisaną listę stacji. Odtwarzanie może nadal działać.';
    } finally {
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _saveFavorites(List<Station> next) async {
    final previous = favorites;
    favorites = next;
    notifyListeners();
    try {
      await repository.saveFavorites(favorites);
    } on Object {
      favorites = previous;
      error = 'Nie udało się zapisać ulubionych.';
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> toggleFavorite(Station station) => _saveFavorites(
    isFavorite(station)
        ? favorites.where((s) => s.id != station.id).toList()
        : [...favorites, station],
  );

  /// Moves a favourite within the user's own order.
  Future<void> reorderFavorite(int from, int to) {
    final next = [...favorites];
    final item = next.removeAt(from);
    next.insert(to.clamp(0, next.length), item);
    favoriteSort = FavoriteSort.own;
    return _saveFavorites(next);
  }

  void sortFavorites(FavoriteSort value) {
    favoriteSort = value;
    notifyListeners();
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  /// Remembers a query once the user acts on its results.
  void rememberSearch([String? value]) {
    final q = (value ?? query).trim();
    if (q.isEmpty) return;
    recentSearches = [
      q,
      ...recentSearches.where((r) => r.toLowerCase() != q.toLowerCase()),
    ].take(maxRecentSearches).toList();
    notifyListeners();
    repository.saveRecentSearches(recentSearches).catchError((Object _) {});
  }

  void clearRecentSearches() {
    recentSearches = [];
    notifyListeners();
    repository.saveRecentSearches(const []).catchError((Object _) {});
  }

  void setSearchGenre(String? value) {
    searchGenre = value;
    notifyListeners();
  }

  void setSearchPlace(String? value) {
    searchPlace = value;
    notifyListeners();
  }

  void toggleHighQuality() {
    highQuality = !highQuality;
    notifyListeners();
  }

  void toggleHttpsOnly() {
    httpsOnly = !httpsOnly;
    notifyListeners();
  }

  void setSearchSort(SearchSort value) {
    searchSort = value;
    notifyListeners();
  }

  void clearSearch() {
    query = '';
    searchGenre = null;
    searchPlace = null;
    highQuality = false;
    httpsOnly = false;
    notifyListeners();
  }

  void filter(Genre value) {
    genre = value;
    notifyListeners();
  }

  void sortBrowse(BrowseSort value) {
    browseSort = value;
    notifyListeners();
  }

  void navigate(AppPage value) {
    page = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
