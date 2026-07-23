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
