# OtherRadio app icons

These assets match the in-app logo (`Brand` in `lib/core/ui/art.dart`,
reference: `logo reference.png` in the repo root): Flutter's
`Icons.graphic_eq_rounded` (Material Icons, U+F7BD) in brand mint `#65E5CD`
(`brandMint` in `lib/core/theme.dart`), followed in the app by the `other`
(heavy) / `radio` (regular, mint) wordmark. On the light theme the app uses
the darker `brandMintInk` `#0F766E` for contrast. The icon tile uses the existing theme background `#0A0D14`.
The glyph outline is extracted from Flutter's Material Icons font rather than
approximated with independently drawn bars. The notification's existing white
waveform remains unchanged.

`other_radio.svg` is the reusable vector source; `other_radio.png` is a
1024 × 1024 transparent-corner raster export. Neither requires an asset entry
in `pubspec.yaml` for native launcher icons to work.

## Regeneration

On Windows, after `flutter pub get` and a Flutter build that copies the full
Material Icons font into `build/flutter_assets/fonts/`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/generate_app_icons.ps1
```

The script first looks in the SDK recorded by `.dart_tool/package_config.json`.
An explicit `-MaterialFont C:\path\to\MaterialIcons-Regular.otf` also works.
Use the full Flutter Material Icons font, not a tree-shaken release subset.
The generator uses Windows PowerShell/.NET System.Drawing, without downloaded
design assets or image packages.

## Glyph attribution

Material Icons / `graphic_eq_rounded` by Google, distributed with Flutter:
<https://github.com/google/material-design-icons>.
The SDK's `bin/cache/artifacts/material_fonts/materialicons_license.txt`
supplies the [Creative Commons Attribution 4.0 International license](https://creativecommons.org/licenses/by/4.0/legalcode).
The original glyph outline is retained; only scale, mint fill, dark background
and raster/native icon packaging are applied. The glyph is supplied without
warranties, as described in that license. No Google endorsement is implied.

## Outputs

- Android legacy and round PNGs: 48, 72, 96, 144, 192 pixels (mdpi–xxxhdpi).
- Android API 26 adaptive icons: full-bleed theme background plus transparent
  108 dp vector foreground. The entire glyph fits the central 66 dp safe circle.
- Android API 33 themed icons: the same foreground used as the monochrome layer.
- Windows `windows/runner/resources/app_icon.ico`: 32-bit RGBA PNG frames at
  16, 20, 24, 32, 40, 48, 64, 96, 128 and 256 pixels. `Runner.rc` already embeds
  this resource, so no Windows code changes are necessary.

Launcher/system icon caches can require reinstalling the Android app or
restarting Windows Explorer before the new image is visible. Physical-device
launcher masks and themed-icon rendering still require device validation.
