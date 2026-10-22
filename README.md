# 📻 [OtherRadio] — Worldwide Internet Radio

A cross-platform internet radio app for stations around the world, with a clean, futuristic UI.
Built with **Flutter**, powered by the community-maintained **[Radio Browser API](https://www.radio-browser.info/)**.

> **Status:** Flutter implementation — Windows desktop + Android (phones and Android TV). Interface languages: English and Polish, independent of station country.
> **Platform priority:** Mobile → Desktop → Web.

## Current implementation

The app includes Radio Browser server discovery/failover, worldwide station access, country selection, a popularity-sorted catalogue, local search/tag filters, persistent favorites and country-specific catalogue caches, last-station/volume restoration, and a responsive English/Polish UI with a mini/full player. Playback supports bounded retries, timeout/error states and ICY titles. Android background audio and Windows SMTC are wired; platform behavior requires real-device verification.

**Country and language:** Settings lets you choose the default station country and app language independently. Poland and Polish are the initial defaults, preserving existing users' experience. Each launch opens the configured country's catalogue. Browse and Search share a temporary country filter; **Worldwide** loads all available countries, and **Use default country** returns to your saved selection. Changing the default country updates the current catalogue too. Changing language never changes country, favorites, history or playback.

### Android TV

The same Android APK includes a TV launcher entry and a 320×180 branded banner; a touchscreen is optional. Native Android UI-mode detection enables remote-friendly input, overscan-safe margins, slightly larger text, visible focus outlines and initial navigation focus. Layouts still adapt to available width.

- **D-pad:** move between navigation, stations, filters and controls; focused stations scroll into view.
- **OK / Select:** activate the focused control. Search opens the keyboard when you enter the search field, not simply when visiting Search.
- **Back:** dismiss the keyboard or current dialog/player first; from a library/settings page return to Browse; from Browse use Android's normal exit behavior.
- **Play/Pause and volume:** Android's existing media session and system volume handling remain available. Home preserves background radio playback.
- **Favorites → Edit:** use the reorder menu's **Move up / Move down** actions with a remote.
- Country and language settings work independently on TV, just as on mobile.

Build a development APK with `flutter build apk --debug`, then sideload with `adb install -r build/app/outputs/flutter-apk/app-debug.apk`. For a signed release use the signing configuration in [CI/CD](docs/CI-CD.md). The neutral brand banner is shared by English/Polish; regenerate it on Windows with `tool/generate_tv_banner.ps1`.

Automated tests exercise D-pad/OK navigation, playback activation, Back and scrolling at TV resolutions. Physical TV validation (including its on-screen keyboard and hardware media buttons) is still needed before store publication.

**Toolchain:** Flutter 3.47.7 / Dart 3.13.5. Windows additionally needs Developer Mode (plugin symlinks), Visual Studio's **Desktop development with C++** workload, and **Rust/rustup** for `smtc_windows`. Android needs the Android SDK and JDK 17. Android release builds require signing credentials; see [CI/CD and releases](docs/CI-CD.md).

```bash
flutter pub get
dart run build_runner build
dart format lib test tool
flutter analyze
flutter test
flutter run -d windows
# For Android, select an actual device ID from flutter devices:
flutter run -d <device-id>
```

Focused checks: `flutter test test/data_test.dart`, `flutter test test/playback_test.dart`, and `flutter test test/widget_test.dart`. Tests mock network/audio plugins; no radio stream is played. Run `dart run tool/check_radio_api.dart` for an optional live catalogue smoke check. `.github/workflows/ci.yml` defines checks; `release.yml` builds signed Android APKs and Windows installers. See [release setup and instructions](docs/CI-CD.md).

`lib/main.dart` wires storage and platform audio; Riverpod providers in `lib/core/providers.dart` connect feature controllers to data repositories and audio services. Station model code is generated and checked in. Manrope, Sora and JetBrains Mono are bundled under the OFL for offline startup. The catalogue refreshes on launch; requests page through the selected country (or worldwide catalogue) in batches of 1000, without a total-record cap. Search and genre filters cover that fetched catalogue. Distinct station UUIDs are retained even when names match. Cached listings work offline, but playback requires a connection. The visual activity indicator represents playback state, not measured audio levels.

**Local validation:** native builds require the prerequisites above. The original specification and longer-term roadmap follow; they are not a claim that every platform behavior has been device-tested.

**Android playback behavior (verified on Pixel 9 Pro):** switching live stations updates the play/loading state; pressing Home keeps audio playing; removing OtherRadio from Recents stops playback. Actual notification dismissal stops playback and cancels reconnect attempts. Android's swipe gesture can only hide the system media controls without sending a dismissal callback: use the player's Stop action, or long-press the system media card and choose **Ukryj**, to stop it. Regression tests cover early-ready events, task removal, notification deletion, and cancellation during loading/retries.

**Search:** focusing the search bar hides promotional content and genre chips so results appear immediately below it. The search bar stays pinned while scrolling; **×** clears the query, exits search, and returns to the top of browsing.

**Desktop shortcuts:** Space toggles playback, Ctrl+←/→ selects the previous/next queued station, Ctrl+1–9 selects favorites in their displayed order, and Ctrl+K opens and focuses Search. These also work in the full player and station details. Text fields retain Space and Ctrl+arrow editing; popup menus/dialogs keep their own key handling. Hold-to-repeat does not repeatedly toggle playback. Enter still activates a focused button.

---

## Table of Contents

1. [Goals](#goals)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Getting Started](#getting-started)
5. [Project Structure](#project-structure)
6. [Radio Browser API Integration](#radio-browser-api-integration)
7. [Audio Playback](#audio-playback)
8. [Platform Configuration](#platform-configuration)
9. [UI & Design Guidelines](#ui--design-guidelines)
10. [Roadmap](#roadmap)
11. [Conventions](#conventions)
12. [Legal Notes](#legal-notes)

---

## Goals

- Access to available Radio Browser stations worldwide, with a configurable default country and country filters.
- English and Polish interface languages, selectable independently of station country.
- One codebase for Android and Windows now, iOS/macOS/Web later.
- Clean, dark, futuristic look with smooth motion.
- Background playback with system media controls on every platform.

## Features

### MVP (Phase 1)

- [x] Worldwide station catalogue, sorted by popularity (Radio Browser click count)
- [x] Configurable default country and country filtering, including a worldwide view
- [x] Independent English/Polish interface language setting
- [x] Search by station name
- [x] Filter by genre tag (pop, rock, news, classical, …)
- [x] Play / pause / stop with buffering and error states (native verification pending)
- [x] Mini player + expandable full-screen player
- [x] "Now playing" from ICY metadata (backend/device verification pending)
- [x] Favorites (stored locally)
- [x] Remember last played station and volume
- [ ] Background playback (Android notification, lock screen, Bluetooth/headset buttons)
- [ ] Windows media keys + system media overlay (SMTC)
- [x] Offline-friendly station cache

### Later

- [ ] Sleep timer
- [ ] Alarm (wake up to radio)
- [ ] Recently played history
- [ ] Animated audio visualizer
- [ ] Android Auto
- [ ] iOS, macOS and Web builds

---

## Tech Stack

| Area              | Choice                                              |
| ----------------- | --------------------------------------------------- |
| Framework         | Flutter (latest stable)                             |
| Language          | Dart                                                |
| State management  | `flutter_riverpod`                                  |
| HTTP client       | `dio`                                               |
| Audio playback    | `just_audio`                                        |
| Windows backend   | `just_audio_media_kit` + `media_kit_libs_windows_audio` |
| Background audio  | `audio_service` (Android)                           |
| Windows media keys| `smtc_windows`                                      |
| Local storage     | `shared_preferences` (settings), `hive` (favorites, station cache) |
| Images            | `cached_network_image`                              |
| Fonts             | Bundled Manrope, Sora, JetBrains Mono (OFL)          |
| Models / JSON     | `freezed` + `json_serializable`                     |

> Use the latest stable versions of all packages. Check each package's pub.dev page for platform support before upgrading.

---

## Getting Started

### Prerequisites

- **Flutter SDK** (stable channel) — `flutter doctor` should pass for Android and Windows
- **Android Studio** with Android SDK and an emulator or physical device
- **Visual Studio 2022** (not VS Code) with the **"Desktop development with C++"** workload — required for Windows builds
- Git

### Setup

```bash
git clone <repo-url>
cd <project-folder>
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Run

```bash
# Android
flutter devices
flutter run -d <android-device-id>

# Windows
flutter run -d windows
```

### Build

```bash
# Android (release APK / App Bundle)
flutter build apk --release
flutter build appbundle --release

# Windows (release)
flutter build windows --release
```

---

## Project Structure

```
lib/
├── main.dart                    # Entry point, audio + media_kit init
├── app.dart                     # MaterialApp, theme, routing
├── core/
│   ├── theme/                   # Colors, typography, glass/neon styles
│   ├── constants/               # API config, user agent, timeouts
│   └── utils/                   # Helpers, extensions
├── data/
│   ├── models/                  # Station, Tag (freezed)
│   ├── api/                     # Radio Browser client + server discovery
│   ├── repositories/            # StationRepository (API + cache)
│   └── local/                   # Hive boxes, preferences
├── audio/
│   ├── audio_handler.dart       # audio_service handler (Android)
│   ├── player_service.dart      # just_audio wrapper, retry logic
│   └── smtc_service.dart        # Windows media controls
└── features/
    ├── stations/                # Station grid, search, tag filters
    ├── player/                  # Mini player, full player, visualizer
    ├── favorites/               # Favorites list
    └── settings/                # Settings screen
```

**Rule:** UI widgets never call the API or the player directly — they go through Riverpod providers that use repositories and services.

---

## Radio Browser API Integration

Radio Browser is a free, community-run database. Please respect its guidelines so the service stays available for everyone.

### 1. Server discovery

There is no single fixed server. Pick one at app start:

- Fetch the server list: `GET https://all.api.radio-browser.info/json/servers`
- Shuffle the list, use the first one that responds, and fall back to the next on failure.
- Cache the chosen server for the session.

### 2. Always send a User-Agent

Every request must include a descriptive User-Agent:

```
User-Agent: ProjectName/0.1.0 (contact or repo URL)
```

### 3. Key endpoints

All paths are relative to the chosen server, e.g. `https://<server>/json/...`.

| Purpose | Endpoint |
| ------- | -------- |
| Country catalogue | `GET /json/stations/search?countrycode=<ISO-code>&hidebroken=true&order=name&limit=1000&offset=<offset>` |
| Worldwide catalogue | Same paginated request, omitting `countrycode` |
| Search by name | Search the fetched catalogue locally |
| Filter by tag or region | Filter the fetched catalogue locally |
| Genre choices | Tags from fetched stations |
| Single station | `GET /json/stations/byuuid/<stationuuid>` |
| **Register a play** | `GET /json/url/<stationuuid>` — call this every time the user starts a station |

> Registering plays via `/json/url/` is requested by the Radio Browser project. It keeps the popularity ranking accurate, and that ranking is what this app uses to show "most popular" stations.

### 4. Station model (fields we use)

| Field | Type | Notes |
| ----- | ---- | ----- |
| `stationuuid` | String | Primary key — use this, not `name` |
| `name` | String | Trim whitespace; names can contain duplicates |
| `url_resolved` | String | **Use this for playback** (playlists already resolved) |
| `favicon` | String | Logo URL — may be empty or broken, always have a fallback |
| `tags` | String | Comma-separated, lower-case |
| `codec` | String | MP3, AAC, AAC+, … |
| `bitrate` | int | kbps, `0` if unknown |
| `hls` | int | `1` if HLS stream |
| `lastcheckok` | int | `1` if the stream was reachable on the last check |
| `clickcount` | int | Popularity |
| `votes` | int | User votes |
| `homepage` | String | Station website |

### 5. Data quality handling

Community data is not perfect. The repository layer should:

- Deduplicate stations with the same normalized name (keep the highest `clickcount` / bitrate).
- Skip entries with empty `url_resolved`.
- Show a generated placeholder logo when `favicon` is missing or fails to load.
- Cache results locally (e.g. 12–24 h) and show the cache instantly on start, refreshing in the background.

---

## Audio Playback

### Initialization (`main.dart`)

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Windows playback backend (libmpv)
  JustAudioMediaKit.ensureInitialized(windows: true, linux: false);

  // Background audio + media notification (Android)
  final audioHandler = await AudioService.init(
    builder: () => RadioAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.radio.playback',
      androidNotificationChannelName: 'Radio playback',
      androidNotificationOngoing: true,
    ),
  );

  runApp(ProviderScope(
    overrides: [audioHandlerProvider.overrideWithValue(audioHandler)],
    child: const App(),
  ));
}
```

### Playback rules

- Play from `url_resolved`.
- Call `/json/url/<stationuuid>` when playback starts.
- **Timeout** if the stream doesn't start buffering within ~10 s → show "Station unavailable" with a retry button.
- **Auto-retry** on network drop (e.g. 3 attempts with backoff) before showing an error.
- Show clear states: `idle`, `loading`, `buffering`, `playing`, `paused`, `error`.
- Read ICY metadata (`player.icyMetadataStream`) for artist/title. Not every station sends it, and support can differ between the Android and Windows backends — verify on both and hide the "now playing" line when empty.

---

## Platform Configuration

### Android

**`android/app/src/main/AndroidManifest.xml`** — permissions:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

Also add the `audio_service` service and media button receiver as described in the package README, and make `MainActivity` extend `AudioServiceActivity`.

**Cleartext (HTTP) streams** — many radio streams are plain HTTP, which Android blocks by default. Add `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true" />
</network-security-config>
```

And reference it on the `<application>` tag:

```xml
android:networkSecurityConfig="@xml/network_security_config"
```

### Windows

- Add `just_audio_media_kit` and `media_kit_libs_windows_audio` to `pubspec.yaml`.
- Register media keys and the system media overlay via `smtc_windows`, synced with player state.
- Set a sensible minimum window size (e.g. 900×600) for the desktop layout.

---

## UI & Design Guidelines

**Direction:** clean, dark, futuristic — calm by default, glowing where it matters.

- **Base:** near-black background (`#0A0B10`-ish) with slightly lighter surface layers.
- **Accents:** one primary neon (cyan `#00E5FF`) and one secondary (violet `#8B5CF6`). Use accents only for active/interactive elements.
- **Surfaces:** frosted glass cards (`BackdropFilter` blur + low-opacity border).
- **Typography:** Space Grotesk or Inter for UI text; a display font (e.g. Orbitron) only for large headings, if at all.
- **Motion:** `Hero` transition from station card to full player; subtle pulsing glow around the active station; animated waveform while playing.
- **Logos:** rounded square containers with consistent size; generated gradient + initials as fallback.

### Layouts

| Platform | Layout |
| -------- | ------ |
| Android | Station grid → mini player at the bottom → swipe up for full player |
| Windows | Left sidebar (Browse, Favorites, Genres, Settings) · station grid in the center · player panel on the right |

Use breakpoints (e.g. `< 700 px` mobile, `≥ 700 px` desktop) rather than platform checks, so the layout also works on tablets and the future web build.

---

## Roadmap

| Phase | Scope |
| ----- | ----- |
| **0 — Setup** | Repo, Flutter project, lint rules, theme, folder structure, CI (build Android + Windows) |
| **1 — Data** | Server discovery, API client, station model, repository + cache, station list screen |
| **2 — Playback** | Player service, mini/full player, error handling, `/json/url` click registration |
| **3 — Platform** | Android background audio + notification, Windows SMTC, cleartext config |
| **4 — Features** | Search, tag filters, favorites, last station, settings |
| **5 — Polish** | Animations, visualizer, logo fallbacks, testing on real devices |
| **6 — Release** | App icons, store listings (Google Play, Microsoft Store), versioning |
| **Next** | iOS, macOS, Web, sleep timer, alarm, Android Auto |

---

## Conventions

- **Lints:** `flutter_lints` (or `very_good_analysis` for stricter rules).
- **Formatting:** `dart format .` before every commit.
- **Commits:** [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`, `refactor:`, `chore:` …
- **Branches:** `main` (stable), `develop`, `feature/<name>`.
- **Tests:** unit tests for repository + API parsing; widget tests for player states.
- **No secrets** in the repo (Radio Browser needs no API key).

---

## Legal Notes

- Station data comes from Radio Browser, a community database — this app does not host any streams.
- Station names and logos are trademarks of their respective owners.
- Before publishing on Google Play or the Microsoft Store, review store policies and the terms of major broadcasters (some, e.g. RMF FM or Polskie Radio, have official apps and rules for third-party use of their streams).

---

## Acknowledgements

- [Radio Browser](https://www.radio-browser.info/) — free, open radio station database
- [just_audio](https://pub.dev/packages/just_audio), [audio_service](https://pub.dev/packages/audio_service), [media_kit](https://pub.dev/packages/media_kit)
