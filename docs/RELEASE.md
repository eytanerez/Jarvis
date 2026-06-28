# Jarvis Release & Auto-Update

Jarvis is distributed as a signed/notarized **DMG** for first install and updates
itself afterward through **Sparkle**. The version dashboard (Debug window /
Settings → About) always shows exactly what is running.

```
DMG          = first install (drag into /Applications)
Sparkle      = ongoing updates (per-channel appcast)
Version panel = shows the running app + brain build
```

## Version source of truth

Three repo-root files drive every build:

| File             | Example  | Meaning                          |
| ---------------- | -------- | -------------------------------- |
| `VERSION`        | `0.3.12` | Marketing version (CFBundleShortVersionString) |
| `BUILD_NUMBER`   | `13`     | Incrementing build (CFBundleVersion)           |
| `UPDATE_CHANNEL` | `dev`    | Default channel for this build                 |

`scripts/generate_build_info.sh` reads these (plus git commit + date) and writes:

- `Sources/JarvisCore/Generated/BuildInfo.swift` → `enum JarvisBuildInfo`
- `brain/app/_build_constants.py` → constants used by `brain/app/build_info.py`

The app exposes this via `AppVersionInfo.current`; the brain via
`GET /runtime/version` and `GET /runtime/status`. The Swift app passes its real
version to the brain (env `JARVIS_APP_VERSION` etc.) so the brain can report an
app/brain **version mismatch**.

## Channels

Separate appcast feeds live under `Updates/<channel>/appcast.xml` and are served
from GitHub raw:

```
dev:    https://raw.githubusercontent.com/eytanerez/Jarvis/main/Updates/dev/appcast.xml
beta:   .../Updates/beta/appcast.xml
stable: .../Updates/stable/appcast.xml
```

`JarvisUpdaterDelegate` (Sparkle) selects the feed for the channel chosen in
Settings (`UpdateChannelStore`). Defaults: developer builds → `dev`, testers →
`beta`, users → `stable`. Until stable ships, prefer `beta`/`dev`.

DMG enclosures point at GitHub Releases (`releases/download/vX.Y.Z/`).

## One-time setup

1. **Sparkle keys** — a Jarvis EdDSA key pair has been generated under the
   Sparkle keychain account `Jarvis`, and the public key is installed in
   `Atoll/DynamicIsland/Info.plist`:

   ```sh
   ./bin/generate_keys --account Jarvis -p
   ```

   Keep the **private** key out of git. Local appcast generation uses the
   keychain account by default (`SPARKLE_KEY_ACCOUNT=Jarvis`). For CI, export
   the private key to a temporary local file, add its contents to the
   `SPARKLE_PRIVATE_KEY` secret, then delete the file:

   ```sh
   ./bin/generate_keys --account Jarvis -x /tmp/jarvis_sparkle_private_key
   ```

2. **Developer ID** — a "Developer ID Application" cert in the keychain, plus the
   notarization env below.

## Local release

```sh
# build + sign + notarize + DMG + appcast for the beta channel
DEVELOPER_ID_APP="Developer ID Application: Your Name (TEAMID)" \
APPLE_ID="you@example.com" APPLE_TEAM_ID="XXXXXXXXXX" \
APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
SPARKLE_PRIVATE_KEY="$(cat /tmp/jarvis_sparkle_private_key)" \
scripts/release_update.sh --channel beta --version 0.3.12
```

Each step degrades gracefully when a credential/tool is missing, so local dev is
never blocked:

| Script                       | Does                                         |
| ---------------------------- | -------------------------------------------- |
| `scripts/build_release.sh`   | bump build, generate build info, archive/export `Jarvis.app` (unsigned fallback) |
| `scripts/notarize.sh`        | codesign (hardened runtime) + notarize + staple |
| `scripts/package_dmg.sh`     | DMG with `/Applications` symlink + install note |
| `scripts/generate_appcast.sh`| Sparkle-sign the DMG and update the channel appcast |
| `scripts/release_update.sh`  | runs all of the above in order               |

Then create the GitHub release `vX.Y.Z`, upload the DMG, and commit the updated
`Updates/<channel>/appcast.xml`.

## CI

`.github/workflows/release-macos.yml` (manual `workflow_dispatch`: version /
channel / release notes) automates the same pipeline. Required secrets:

```
APPLE_DEVELOPER_ID_CERTIFICATE            (base64 .p12)
APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD
DEVELOPER_ID_APP
APPLE_ID
APPLE_TEAM_ID
APP_SPECIFIC_PASSWORD
SPARKLE_PRIVATE_KEY
UPDATE_UPLOAD_TOKEN                        (optional; defaults to GITHUB_TOKEN)
```

Missing CI secrets do not block local development.

## Running from the wrong place

`InstallLocation` flags when Jarvis runs from DerivedData, Downloads, Desktop, a
mounted DMG, an App-Translocation path, or a repo `.build` folder. The version
panel shows a warning and a **Move to Applications** button (copies into
`/Applications/Jarvis.app` and relaunches). Mounted-DMG / translocated runs are
called out specifically because Sparkle can't update them.
`DuplicateInstanceDetector` warns when more than one Jarvis (same bundle id) is
running and offers to quit the others.

## Bundled vs developer brain

The app prefers a bundled brain (`Jarvis.app/Contents/Resources/brain`) in
production and only uses a repo brain in developer mode, where the panel shows
**Developer Brain Active**. The brain's `brainMode` and `matchesAppVersion` are
reported by `GET /runtime/status`.

The Xcode "Copy Jarvis Brain" phase calls `scripts/copy_brain_bundle.sh` instead
of raw `ditto`. It copies the brain source plus the main runtime `.venv` when
present, while excluding helper/dev venvs (`.venv-*`), tests, egg-info, bytecode,
and cache directories. To use a cleaner prepared runtime venv for a release, set
`JARVIS_BRAIN_RUNTIME_VENV=/path/to/runtime-venv`; to copy source only, set
`JARVIS_INCLUDE_BRAIN_RUNTIME_VENV=0`.
