cask "timeflow" do
  version "0.2.5"
  sha256 "bc767a68be3fcb68ab17453ad3d7fbccc113ab295cbf5318b42cdf25f64ec74b"

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
