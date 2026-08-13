cask "timeflow" do
  version "0.4.39"
  sha256 "b8032a4a4c3dfa3eda1f0cae0ad9d57a4e347edff5cffbc7f60c8d862310f8c4"

  url "https://github.com/ercansavas/homebrew-tap/releases/download/v#{version}/TimeFlow.dmg",
      verified: "github.com/ercansavas/homebrew-tap/"
  name "TimeFlow"
  desc "Menubar time-tracker with coding analytics for Apple Silicon"
  homepage "https://github.com/ercansavas/homebrew-tap"

  depends_on macos: :sonoma
  depends_on arch: :arm64

  app "TimeFlow.app"

  # Soft launch: TimeFlow is signed with a stable self-signed identity rather
  # than a notarized Developer ID one, so downloads still carry the macOS
  # quarantine flag and Gatekeeper blocks first launch. Strip it after install
  # so `brew install` gives a clean, no-prompt open. This postflight is removed
  # once the app ships notarized through Apple Developer.
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
