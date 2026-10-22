import '../api/radio_browser_client.dart';
import '../local/radio_storage.dart';
import '../models/station.dart';

class StationRepository {
  StationRepository(this.client, this.storage);
  final RadioBrowserClient client;
  final RadioStorage storage;

  List<Station> get cached => storage.readStations('catalogue');
  String get defaultCountry => storage.defaultCountry;
  List<Station> cachedFor(String countryCode) => countryCode == 'PL'
      ? cached
      : storage.readStations('catalogue_$countryCode');
  List<Station> get favorites => storage.readStations('favorites');

  Future<List<Station>> refresh({String countryCode = 'PL'}) async {
    final stations = normalize(await client.stations(countryCode: countryCode));
    await storage.writeStations(
      countryCode == 'PL' ? 'catalogue' : 'catalogue_$countryCode',
      stations,
    );
    return stations;
  }

  Future<void> saveFavorites(List<Station> stations) =>
      storage.writeStations('favorites', stations);

  List<String> get recentSearches => storage.recentSearches;
  Future<void> saveRecentSearches(List<String> queries) =>
      storage.saveRecentSearches(queries);

  static List<Station> normalize(List<Station> stations) {
    final sorted =
        stations.where((s) {
          final uri = Uri.tryParse(s.streamUrl);
          return s.id.isNotEmpty &&
              s.name.trim().isNotEmpty &&
              uri != null &&
              (uri.scheme == 'http' || uri.scheme == 'https') &&
              uri.host.isNotEmpty;
        }).toList()..sort((a, b) {
          final popularity = b.clickcount.compareTo(a.clickcount);
          return popularity != 0 ? popularity : b.bitrate.compareTo(a.bitrate);
        });
    final ids = <String>{};
    return sorted
        .where((s) {
          if (ids.contains(s.id)) return false;
          ids.add(s.id);
          return true;
        })
        .map((s) => s.copyWith(name: s.name.trim()))
        .toList();
  }
}
