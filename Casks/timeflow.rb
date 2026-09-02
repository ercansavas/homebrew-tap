cask "timeflow" do
  version "0.5.11"
  sha256 "9d0e0afeabef33434b413a3fa4d253a5bbbb5580e32ed237b7eb9b2194adbd66"

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

    # Reopen after an upgrade. `uninstall quit:` below stops the app so the
    # bundle can be replaced safely, but nothing ever started it again: the user
    # saw a successful upgrade and a menubar with no icon, and tracking stayed
    # silently off until they happened to notice. One user went eleven days that
    # way. On a fresh install this is what the setup instructions asked people to
    # type by hand anyway.
    system_command "/usr/bin/open", args: ["-a", "#{appdir}/TimeFlow.app"]

    # The accessibility grant is pinned to this signing leaf, not to the bundle
    # id or the cdhash, which is why permission survives ordinary upgrades. If it
    # ever changes, every user silently loses tracking permission, so say so here
    # rather than letting it be discovered from missing data weeks later.
    expected_leaf = "59a7b2e3efec5f1404f959037508793288eda57d"
    req = system_command("/usr/bin/codesign",
                         args: ["-d", "--requirements", "-", "#{appdir}/TimeFlow.app"],
                         must_succeed: false)
    leaf = "#{req.stdout}#{req.stderr}"[/certificate leaf = H"([a-f0-9]{40})"/, 1]
    if leaf && leaf != expected_leaf
      opoo "TimeFlow imza sertifikasi degismis — Erisilebilirlik izni dusmus olabilir. " \
           "Sistem Ayarlari > Gizlilik ve Guvenlik > Erisilebilirlik: TimeFlow'u kaldirip yeniden ekleyin."
    end
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
