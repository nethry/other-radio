import '../data/models/station.dart';

/// Polish plural: `plural(3, 'stacja', 'stacje', 'stacji')` → `3 stacje`.
String plural(int n, String one, String few, String many) {
  final d = n % 10, t = n % 100;
  final word = n == 1
      ? one
      : d >= 2 && d <= 4 && (t < 12 || t > 14)
      ? few
      : many;
  return '$n $word';
}

String stationCount(int n) => plural(n, 'stacja', 'stacje', 'stacji');

/// `45 min`, `1 godz. 20 min`, `< 1 min`.
String listenDuration(Duration d) {
  final minutes = d.inMinutes;
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final rest = minutes % 60;
  return '${minutes ~/ 60} godz. ${rest.toString().padLeft(2, '0')} min';
}

String clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _months = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// `Dzisiaj`, `Wczoraj` or `12 października`.
String dayLabel(DateTime day, DateTime now) {
  final a = DateTime(day.year, day.month, day.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = b.difference(a).inDays;
  if (diff == 0) return 'Dzisiaj';
  if (diff == 1) return 'Wczoraj';
  final label = '${day.day} ${_months[day.month - 1]}';
  return day.year == now.year ? label : '$label ${day.year}';
}

const _generic = {
  'radio',
  'polskie',
  'polska',
  'fm',
  'the',
  'online',
  'internet',
  'stacja',
  'program',
};

List<String> _monogramPool(String name) {
  final words = name
      .split(RegExp(r'[\s\-–—_.,:/|()]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final meaningful = words
      .where((w) => !_generic.contains(w.toLowerCase()))
      .toList();
  return meaningful.isEmpty ? words : meaningful;
}

bool _isShortCode(String word) =>
    word.length <= 4 &&
    (RegExp(r'^\d+$').hasMatch(word) || word == word.toUpperCase());

/// Short monogram for a station tile: `357`, `RMF`, `P3`, `RNŚ`.
String monogram(String name) {
  final pool = _monogramPool(name);
  if (pool.isEmpty) return '?';
  final first = pool.first;
  if (_isShortCode(first)) return first.toUpperCase();
  if (pool.length == 1) {
    return first.substring(0, first.length.clamp(0, 3)).toUpperCase();
  }
  return pool.take(3).map((w) => w.substring(0, 1).toUpperCase()).join();
}

/// Words a short-code monogram leaves out, so `ESKA ROCK` and `ESKA` tiles
/// differ: returns `ROCK`. Null when the monogram already covers the name.
String? monogramCaption(String name) {
  final pool = _monogramPool(name);
  if (pool.length < 2 || !_isShortCode(pool.first)) return null;
  final rest = pool.skip(1).join(' ').toUpperCase();
  return rest.length > 12 ? '${rest.substring(0, 11)}…' : rest;
}

/// Stable tile palette index for a station.
int paletteIndex(String id) =>
    id.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff) % 8;

/// First genre tags joined with ` · `.
String tagLine(Station s, {int count = 2}) {
  final tags = s.genres.take(count).join(' · ');
  return tags.isEmpty ? 'radio internetowe' : tags;
}

String place(Station s) => s.state.trim().isEmpty ? 'Polska' : s.state.trim();

/// `Warszawa · rock · alternatywa`.
String subtitle(Station s) => '${place(s)} · ${tagLine(s)}';

/// `AAC 128k` for compact lists.
String formatShort(Station s) {
  final codec = s.codec.isEmpty ? 'Audio' : s.codec.toUpperCase();
  return s.bitrate > 0 ? '$codec ${s.bitrate}k' : codec;
}

/// `AAC · 128 kb/s`.
String formatLong(Station s) {
  final codec = s.codec.isEmpty ? 'Audio' : s.codec.toUpperCase();
  return s.bitrate > 0 ? '$codec · ${s.bitrate} kb/s' : codec;
}

/// Splits ICY `Artist - Title` metadata. Returns `(title, artist)`.
(String, String) splitTrack(String icy) {
  final text = icy.trim();
  for (final separator in const [' - ', ' – ', ' — ']) {
    final i = text.indexOf(separator);
    if (i > 0) {
      return (
        text.substring(i + separator.length).trim(),
        text.substring(0, i).trim(),
      );
    }
  }
  return (text, '');
}
