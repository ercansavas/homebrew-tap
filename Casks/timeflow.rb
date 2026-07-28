cask "timeflow" do
  version "0.2.7"
  sha256 "d5e0bbdac5bed7f45948ad9b162407c24d1f02998625fb7a31e7df19eb154268"

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

  uninstall quit: "com.timeflow.menubar"

  zap trash: [
    "~/.timeflow",
    "~/Library/Application Support/TimeFlow",
  ]
end
