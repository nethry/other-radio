# CI/CD and releases

## Workflows

- `ci.yml`: pushes to `main` and all pull requests run locked dependency resolution, code generation, formatting checks, `flutter analyze`, and `flutter test` on Ubuntu. Fork PRs need no secrets.
- `release.yml`: tags matching `v*.*.*` and **Actions → Release → Run workflow** run the same checks, then build Android and Windows in parallel. Manual runs upload artifacts only, even when selecting a tag. A tag push publishes a GitHub Release after both builds succeed.
- Flutter **3.47.7**, stable, is pinned in both workflows to match this project's Dart constraint. Update all Flutter pins together. Flutter SDK and pub dependencies are cached by `subosito/flutter-action`; the committed `pubspec.lock` is enforced. Signing material is never cached or uploaded.
- Actions are pinned to release commit SHAs with version comments. Update SHA and comment together when upgrading. Only the publishing job gets `contents: write`; checkout does not retain credentials.

## Required GitHub Secrets

In **Settings → Secrets and variables → Actions → Repository secrets**, add:

| Secret | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Base64 of the complete release JKS keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Signing key alias, for example `otherradio` |
| `ANDROID_KEY_PASSWORD` | Password for that key |

Use an existing release key if this application has already been distributed. Otherwise generate one interactively (passwords are not command-line arguments):

```sh
keytool -genkeypair -v -keystore other-radio-release.jks -storetype JKS -alias otherradio -keyalg RSA -keysize 3072 -validity 10000
```

With the authenticated GitHub CLI, upload the encoded keystore without printing it:

```sh
# Bash/Linux
base64 -w 0 other-radio-release.jks | gh secret set ANDROID_KEYSTORE_BASE64
```

```powershell
# PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path 'other-radio-release.jks'))) | gh secret set ANDROID_KEYSTORE_BASE64
```

Enter the other three secrets through GitHub's UI. Back up the key and passwords securely: updates must use the same signing key. Never commit them. CI decodes the keystore into the runner's temporary directory with restrictive permissions, passes credentials through environment variables to Gradle, verifies the APK signature, and removes the keystore even after failure. Missing credentials fail the release build; there is no debug-key fallback.

For local Android release builds, set `ANDROID_KEYSTORE_PATH` to the absolute keystore path and set `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, and `ANDROID_KEY_PASSWORD` in your environment before running `flutter build apk --release`. Debug builds require none of these variables.

No personal access token is needed: release publishing uses the automatic `GITHUB_TOKEN`. Repository/organization Actions policy must allow the pinned actions and the publishing job's write permission. Restrict who can push release tags and modify release workflows, since trusted release builds receive signing credentials.

## Publish a release

1. Set `pubspec.yaml` to `version: X.Y.Z+N` (for example `0.1.1+2`). Increment `N` for every distributed Android update. All four numeric components must be at most 65535 for Windows metadata; `N` must be positive.
2. Commit and push to `main`; wait for CI to pass.
3. Tag that commit with the exact three-part version (no build suffix):

   ```sh
   git tag -a v0.1.1 -m "OtherRadio 0.1.1"
   git push origin v0.1.1
   ```

4. The workflow validates the tag against `pubspec.yaml`. Prerelease suffixes and mismatched tags are rejected.
5. Download from the GitHub Release:
   - `OtherRadio-Android-X.Y.Z.apk` — signed universal release APK.
   - `OtherRadio-Setup-X.Y.Z.exe` — Windows x64 standalone installer.

Both files also appear in the workflow's `OtherRadio-Android` and `OtherRadio-Windows` artifacts, retained for 14 days. Release assets remain until removed. A new release is created as a draft, both assets are uploaded, then it is published with generated notes. Rerunning a failed tag workflow reuses the release and replaces same-named assets. Prefer a new version for changes to an already-published release.

For a build without publishing, run the Release workflow manually on the desired branch. It uses that branch's pubspec version and still requires all Android signing secrets. The workflow must exist on the default branch for GitHub to expose manual execution.

## Windows installer

`installer.iss` is the canonical Inno Setup definition. `installer/windows/build_installer.ps1` reads the pubspec version, locates Inno Setup 6 and Visual Studio's x64 redistributable CRT, validates required bundle/runtime files, and compiles the installer. CI uses Windows Server 2022 with Visual Studio 2022, enables plugin symlinks, configures Rust's stable MSVC toolchain for `smtc_windows`, and installs Inno Setup if absent.

The installer recursively includes **all** of `build/windows/x64/runner/Release`: `other_radio.exe`, Flutter engine, plugin/native/audio DLLs, ICU, AOT code, fonts, and other assets. It also includes the complete Visual Studio x64 CRT DLL set app-locally, so users need no Flutter SDK, Rust, or separately installed Visual C++ redistributable. Windows 10 or later is required.

Metadata uses OtherRadio as name/publisher. Installation is per-user under `%LOCALAPPDATA%\Programs\OtherRadio`, with a Start Menu shortcut, optional desktop shortcut, Polish installer UI, and standard Windows uninstall support. The existing stable AppId is preserved for upgrades. Uninstall removes installed files and shortcuts; user preferences are retained. The executable installer is not Authenticode-signed; Windows publisher signing is separate from Android signing.

Local packaging from the repository root:

```powershell
./installer/windows/build_installer.ps1
# Or package an already-built release bundle:
./installer/windows/build_installer.ps1 -SkipFlutterBuild
```

Output: `build/installer/OtherRadio-Setup-X.Y.Z.exe`. Validate installation, launch/audio playback, upgrade, and uninstall on a clean Windows machine before distribution.

## Validation and maintenance

Run `actionlint .github/workflows/ci.yml .github/workflows/release.yml` for workflow validation. Run the standard Flutter checks listed in `AGENTS.md`. The release jobs validate versions, signatures, required installer paths, and nonempty artifacts before publishing. Build failures prevent publication. GitHub-hosted runner tooling and native downloads still require network access; the first release run validates the hosted environment and configured signing key end to end.
