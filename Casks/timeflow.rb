cask "timeflow" do
  version "0.5.15"
  sha256 "b11dac4584cd10a2eab6d6c4930ce62fceb96661f12dfee7078a17edb7e1a926"

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

    # Reopen after an upgrade — and make sure the thing that comes back is the build we
    # just installed.
    #
    # By the time postflight runs, brew has ALREADY replaced the bundle. So any TimeFlow
    # still running is executing the REPLACED binary: it is stale by construction. That
    # happens whenever the `uninstall quit:` above did not take — it needs Automation access
    # for "Terminal -> System Events", which a colleague's Mac will not have until they
    # approve a dialog, and which they may simply decline.
    #
    # Merely checking "is something running" cannot see this, and an earlier version of this
    # postflight made exactly that mistake: it found the stale process, called the relaunch
    # good, and left the old build running while `brew upgrade` reported success. Observed on
    # a real upgrade 2026-09-03 — on-disk 0.5.14, in-memory 0.5.13, for hours.
    #
    # SIGTERM rather than AppleScript: it needs no permission at all, and the app treats it as
    # a first-class shutdown (AppDelegate installs DispatchSourceSignal handlers that run the
    # same cleanup as applicationWillTerminate — children reaped, clean-exit marker written),
    # so nothing is left half-finished.
    exe = "#{appdir}/TimeFlow.app/Contents/MacOS/TimeFlowMenuBar"
    running_pids = lambda do
      system_command("/usr/bin/pgrep", args: ["-f", exe], must_succeed: false)
        .stdout.split("\n").map(&:strip).reject(&:empty?)
    end

    stale = running_pids.call
    unless stale.empty?
      opoo "TimeFlow hala eski surumle calisiyor (uygulama kapatilamadi) — durdurulup yeniden aciliyor."
      system_command("/bin/kill", args: ["-TERM", *stale], must_succeed: false)
      # Give the clean-shutdown path its moment before falling back to force.
      12.times do
        break if running_pids.call.empty?

        sleep 1
      end
      leftover = running_pids.call
      system_command("/bin/kill", args: ["-KILL", *leftover], must_succeed: false) unless leftover.empty?
    end

    system_command "/usr/bin/open", args: ["-a", "#{appdir}/TimeFlow.app"]

    # ...and confirm the relaunch actually took. If it did not, SAY SO — a warning the user can
    # act on beats time tracking that quietly stops.
    sleep 5
    if running_pids.call.empty?
      system_command "/usr/bin/open", args: ["-a", "#{appdir}/TimeFlow.app"], must_succeed: false
      sleep 5
    end
    if running_pids.call.empty?
      opoo "TimeFlow yukseltmeden sonra acilmadi. Menu cubugunda simge yoksa uygulamayi elle " \
           "acin — acilana kadar zaman takibi calismaz."
    end

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
