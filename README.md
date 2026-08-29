# ercansavas/homebrew-tap

Homebrew tap for TimeFlow (and future apps).

## TimeFlow

Menubar time-tracker with coding analytics for Apple Silicon Macs.

```sh
brew install --cask ercansavas/tap/timeflow
```

The cask strips the macOS download-quarantine flag automatically, so the app
opens without the Gatekeeper "unverified developer" prompt — no terminal step
needed.

> **Soft launch note:** TimeFlow is currently ad-hoc signed (not yet notarized
> by Apple). The cask handles the one-time quarantine step for you. At full
> launch the app will be notarized through Apple Developer and this step goes
> away.

### Requirements
- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or newer)

### Uninstall
```sh
brew uninstall --cask ercansavas/tap/timeflow          # remove the app
brew uninstall --zap --cask ercansavas/tap/timeflow    # also remove local data
```

## Publishing a new version (maintainers)

1. Build the `.dmg` (in the TimeFlowApp repo):
   ```sh
   ./scripts/build-dmg.sh
   ```
2. From a clone of this tap, publish it (version is read from the DMG plist,
   not passed as an argument):
   ```sh
   ./scripts/publish-release.sh [--dry-run] <path-to-TimeFlow.dmg>
   # e.g. ./scripts/publish-release.sh ~/build/TimeFlow.dmg
   ```

The script mints the version from `CFBundleShortVersionString` inside the
`.dmg`, creates the `vX.Y.Z` GitHub Release with the asset named
`TimeFlow.dmg`, bumps `version` + `sha256` in `Casks/timeflow.rb`, and
commits + pushes. The web download button points at
`releases/latest/download/TimeFlow.dmg`, so it picks up the new build
automatically — no web change per release.

Users then update with:
```sh
brew update && brew upgrade --cask ercansavas/tap/timeflow
```
