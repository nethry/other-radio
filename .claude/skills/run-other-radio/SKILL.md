---
name: run-other-radio
description: Build, run, and drive the OtherRadio Flutter app on Windows desktop. Use when asked to start or launch OtherRadio, run it on Windows, build it, run its tests, take a screenshot of its UI, click play/pause, or check what Windows media controls (SMTC) show for it.
---

OtherRadio is a Flutter internet-radio app (Android + Windows). On Windows an agent drives
the real debug build through `.claude/skills/run-other-radio/driver.ps1` (Windows PowerShell 5.1):
it builds, launches the window at a fixed size, takes screenshots, clicks, and reads the system
media session. All paths are relative to the repo root.

## Prerequisites

Verified on Windows 11 with Flutter 3.47.7 and rustc 1.99.1. Also required (see AGENTS.md):
Developer Mode (plugin symlinks), Visual Studio "Desktop development with C++", Rust via rustup
(`smtc_windows` compiles Rust). The driver adds `%USERPROFILE%\.cargo\bin` to PATH itself.

Flutter need not be on PATH: the driver uses `flutter` from PATH, else `$env:FLUTTER_ROOT`, else
the SDK recorded in `.idea\libraries\Dart_SDK.xml` (gitignored, so only on a machine that opened
the project in an IDE). On a fresh clone set `$env:FLUTTER_ROOT = 'C:\path\to\flutter'`.

## Build

```powershell
& .claude\skills\run-other-radio\driver.ps1 build
```

Runs `flutter build windows --debug` → `build\windows\x64\runner\Debug\other_radio.exe` (~20 s warm).

## Run (agent path)

```powershell
$d = ".claude\skills\run-other-radio\driver.ps1"
& $d launch                 # kills any old instance, opens 1600x900 window at 0,0, waits ~6 s
& $d shot launch            # -> build\run-shots\launch.png  (Read it and look)
& $d click 1378 780         # big play/pause button in the "Teraz gra" panel
& $d media Playing 20       # waits until OtherRadio's SMTC session reports Playing
& $d flyout flyout          # Win+A screenshot: system media card with title + thumbnail
& $d stop
```

| command | what it does |
|---|---|
| `build` / `test` | debug build / `dart format` + `flutter analyze` + `flutter test` |
| `launch` | start exe, restore + pin window to 1600x900 so coordinates below hold |
| `shot <name>` | PrintWindow capture of the app → `build\run-shots\<name>.png` |
| `click <x> <y>` | click at window-relative pixel (same coordinates as `shot` images); refuses if another window covers the point |
| `media [status] [sec]` | list Windows media sessions (App, Status, Title, Artist, Album, Thumbnail); with a status, wait for OtherRadio to reach it or throw |
| `flyout <name>` | open Quick Settings, full-screen capture, close with Esc |
| `stop` | kill the app |

Verified coordinates at 1600x900: play/pause **1378,780**, theme Ciemny **100,862** / Jasny **237,862**, nav Szukaj **160,232** (wide layout with the "Teraz gra"
panel on the right). For anything else, take a `shot`, read pixel positions off the PNG, click.

Expected flow: launch shows the Polish UI, ~830 stations from Radio Browser, station logos in cards (monogram fallback). The
last station is restored as "GOTOWE" and must **not** autoplay. Clicking play →
"NA ŻYWO", moving visualizer, `media` shows `Status: Playing`, `Album: OtherRadio • Na żywo`,
`Thumbnail: True`.

## Run (human path)

```powershell
& .claude\skills\run-other-radio\driver.ps1 build; & build\windows\x64\runner\Debug\other_radio.exe
```

## Test

```powershell
& .claude\skills\run-other-radio\driver.ps1 test
```

Expected: `No issues found!` and `All tests passed!` (37 tests).

## Gotchas

- **Clicks silently landing in another app.** Windows' foreground lock stops a background shell's
  `SetForegroundWindow`; a plain click then hits whatever window is on top (here: the user's
  Notepad). `click` raises the window with a TOPMOST toggle + Alt tap and checks `WindowFromPoint`
  before clicking. Don't bypass it with raw `mouse_event`.
- **Verify state via `media`, not the screenshot alone.** `shot` uses PrintWindow, which renders the
  app even when it is covered, so a screenshot can look right while clicks went elsewhere.
- **DPI scaling.** Without `SetProcessDPIAware` (done in the driver) the shell sees scaled-down
  coordinates (a 1600x900 window reports 1280x720) and captures are clipped on the right.
- **Window size is not stable across launches.** Windows may reopen it maximized; `launch` restores
  and pins it. Re-run `launch` if the user resized/maximized it mid-session.
- **SMTC source shows "Unknown app"** in the media card: an unpackaged debug exe has no display
  name. Expected, not a bug.
- **Live network.** The catalogue and streams are real Radio Browser data; station order and
  logos vary. Playback produces real audio on the machine's speakers.

## Troubleshooting

- **`dart`/`flutter` "not recognized"**: SDK not on PATH. Set `$env:FLUTTER_ROOT` (the driver then finds it).
- **`media Playing` times out with `Status: Stopped`**: the click didn't reach the app (see first
  gotcha) or the stream failed; take a `shot` and check for the Polish error text.
- **Reading the SMTC thumbnail bytes from PowerShell 5.1 fails** (`AsStreamForRead` overload not
  found, `GetInputStreamAt` missing on `__ComObject`): the WinRT projection loses the stream
  interfaces. Use `media` (`Thumbnail: True`) plus `flyout` to see the image instead.
