cask "timeflow" do
  version "0.4.18"
  sha256 "e2e3ccf9e31d4a5de470ce7fa859fa23acb61ecbe7851adac9d80f615eb8d723"

  url "https://github.com/ercansavas/homebrew-tap/releases/download/v#{version}/TimeFlow.dmg",
      verified: "github.com/ercansavas/homebrew-tap/"
  name "TimeFlow"
  desc "Menubar time-tracker with coding analytics for Apple Silicon"
  homepage "https://github.com/ercansavas/homebrew-tap"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "TimeFlow.app"

  # Soft launch: TimeFlow is ad-hoc signed (not yet notarized), so downloads
  # carry the macOS quarantine flag and Gatekeeper blocks first launch. Strip
  # it after install so `brew install` gives a clean, no-prompt open. This
  # postflight is removed once the app ships notarized through Apple Developer.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/TimeFlow.app"]
  end

  # Quit the menubar app (which stops its child processes: bundled node backend,
  # aw-server, aw-watcher) before replacing/removing the bundle, so upgrades and
  # uninstalls never race a running instance.
  uninstall quit: "com.timeflow.menubar"

  # `brew uninstall --zap ercansavas/tap/timeflow` removes EVERYTHING the app
  # writes — no hand-rolled `rm -rf`. Covers runtime data, UserDefaults, the
  # WKWebView dashboard storage, and system caches.
  zap trash: [
    "~/.timeflow",
    "~/Library/Application Support/TimeFlow",
    "~/Library/Preferences/com.timeflow.menubar.plist",
    "~/Library/Caches/com.timeflow.menubar",
    "~/Library/HTTPStorages/com.timeflow.menubar",
    "~/Library/HTTPStorages/com.timeflow.menubar.binarycookies",
    "~/Library/WebKit/com.timeflow.menubar",
    "~/Library/Saved Application State/com.timeflow.menubar.savedState",
  ]
end
