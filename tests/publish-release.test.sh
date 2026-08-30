#!/usr/bin/env bash
# Regression tests for G4: publish-release.sh must mint VERSION from the DMG
# plist, not argv. Invokes the real script; stubs block gh / git publish.
#
# WHY no trap EXIT around the script: on macOS bash 3.2, trap+set -u can
# swallow a non-zero exit as 0 — we must capture $? from the subprocess itself.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/publish-release.sh"
CASK="$ROOT/Casks/timeflow.rb"
PASSED=0
FAILED=0

# ---- helpers ----------------------------------------------------------------

pass() {
  echo "PASS: $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo "FAIL: $1"
  echo "  $2"
  FAILED=$((FAILED + 1))
}

# Build stubs that sit first on PATH so a RED run of today's script cannot
# create a real GitHub release or push a cask commit.
setup_stubs() {
  STUB_BIN="$(mktemp -d "${TMPDIR:-/tmp}/g4-stubs.XXXXXX")"
  cat >"$STUB_BIN/gh" <<'EOF'
#!/usr/bin/env bash
echo "FORBIDDEN gh: $*" >&2
exit 99
EOF
  cat >"$STUB_BIN/git" <<'EOF'
#!/usr/bin/env bash
# Forward read-only probes the script needs (rev-parse for repo root).
# Publish side-effects must never reach the real git.
case "${1:-}" in
  rev-parse|status)
    exec /usr/bin/git "$@"
    ;;
  *)
    echo "FORBIDDEN git: $*" >&2
    exit 99
    ;;
esac
EOF
  chmod +x "$STUB_BIN/gh" "$STUB_BIN/git"
  export PATH="$STUB_BIN:$PATH"
}

cleanup_stubs() {
  if [[ -n "${STUB_BIN:-}" && -d "$STUB_BIN" ]]; then
    rm -rf "$STUB_BIN"
  fi
}

# Minimal app + UDZO DMG whose plist version is 0.4.1 — deliberately not
# argv 0.9.9, not cask 0.5.5, and the file is not named TimeFlow.dmg so
# grepping output for TimeFlow.dmg hits the ASSET constant, not the path.
build_fixture_dmg() {
  FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/g4-fixture.XXXXXX")"
  APP_SRC="$FIXTURE_DIR/app"
  mkdir -p "$APP_SRC/TimeFlow.app/Contents"
  cat >"$APP_SRC/TimeFlow.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string>0.4.1</string>
  <key>CFBundleIdentifier</key>
  <string>com.timeflow.menubar</string>
</dict>
</plist>
EOF
  FIXTURE_DMG="$FIXTURE_DIR/fixture-0.4.1.dmg"
  hdiutil create -srcfolder "$APP_SRC" -volname "TimeFlowFixture" -ov -format UDZO "$FIXTURE_DMG" >/dev/null
}

# Same safety stubs as (A)/(B). Empty CFBundleShortVersionString — PlistBuddy
# succeeds but VERSION=""; file not named TimeFlow.dmg.
build_empty_version_fixture_dmg() {
  EMPTY_FIXTURE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/g4-empty-fixture.XXXXXX")"
  local app_src="$EMPTY_FIXTURE_DIR/app"
  mkdir -p "$app_src/TimeFlow.app/Contents"
  cat >"$app_src/TimeFlow.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleShortVersionString</key>
  <string></string>
  <key>CFBundleIdentifier</key>
  <string>com.timeflow.menubar</string>
</dict>
</plist>
EOF
  EMPTY_FIXTURE_DMG="$EMPTY_FIXTURE_DIR/empty-version-fixture.dmg"
  hdiutil create -srcfolder "$app_src" -volname "TimeFlowEmptyVer" -ov -format UDZO "$EMPTY_FIXTURE_DMG" >/dev/null
}

cleanup_fixture() {
  if [[ -n "${FIXTURE_DIR:-}" && -d "$FIXTURE_DIR" ]]; then
    rm -rf "$FIXTURE_DIR"
  fi
  if [[ -n "${EMPTY_FIXTURE_DIR:-}" && -d "$EMPTY_FIXTURE_DIR" ]]; then
    rm -rf "$EMPTY_FIXTURE_DIR"
  fi
}

# ---- tests ------------------------------------------------------------------

# (A) Dry-run mints CFBundleShortVersionString and keeps ASSET=TimeFlow.dmg.
# Also proves --dry-run does not rewrite the cask (checksum before/after).
test_A_dry_run_mints_plist_version() {
  local name="(A) dry-run mints plist version 0.4.1 and asset TimeFlow.dmg"
  local cask_before cask_after out rc
  cask_before="$(shasum -a 256 "$CASK" | awk '{print $1}')"

  set +e
  out="$("$SCRIPT" --dry-run "$FIXTURE_DMG" 2>&1)"
  rc=$?
  set -e

  cask_after="$(shasum -a 256 "$CASK" | awk '{print $1}')"

  if [[ "$rc" -ne 0 ]]; then
    fail "$name" "expected exit 0, got $rc; output: $out"
    return
  fi
  if ! echo "$out" | grep -q '→ version : 0.4.1'; then
    fail "$name" "expected '→ version : 0.4.1' in output; got: $out"
    return
  fi
  if ! echo "$out" | grep -q '→ asset   : TimeFlow.dmg'; then
    fail "$name" "expected '→ asset   : TimeFlow.dmg' in output; got: $out"
    return
  fi
  if [[ "$cask_before" != "$cask_after" ]]; then
    fail "$name" "dry-run mutated Casks/timeflow.rb (sha $cask_before → $cask_after)"
    return
  fi
  pass "$name"
}

# (B) Extra positional after flag parse must be exit 2 (not exit 1 "dmg not found").
# Today argv 0.9.9 is treated as the DMG path → exit 1; asserting 2 is RED.
test_B_extra_positional_exits_2() {
  local name="(B) dry-run with argv 0.9.9 and dmg exits 2 (rejects argv mint)"
  local out rc
  set +e
  out="$("$SCRIPT" --dry-run 0.9.9 "$FIXTURE_DMG" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 2 ]]; then
    fail "$name" "expected exit 2, got $rc; output: $out"
    return
  fi
  if echo "$out" | grep -q '→ version : 0.9.9'; then
    fail "$name" "must not mint argv 0.9.9; output: $out"
    return
  fi
  pass "$name"
}

# (C) Empty CFBundleShortVersionString must exit 1 (attach/read class), not
# mint TAG=v / dry-run success. Before the guard: attach+PlistBuddy succeed,
# VERSION="", dry-run exits 0 — asserting exit 1 is therefore RED.
test_C_empty_version_exits_1() {
  local name="(C) dry-run with empty CFBundleShortVersionString exits 1"
  local out rc
  set +e
  out="$("$SCRIPT" --dry-run "$EMPTY_FIXTURE_DMG" 2>&1)"
  rc=$?
  set -e

  if [[ "$rc" -ne 1 ]]; then
    fail "$name" "expected exit 1, got $rc; output: $out"
    return
  fi
  if echo "$out" | grep -q '✓ dry-run: would publish'; then
    fail "$name" "must not print dry-run success; output: $out"
    return
  fi
  if echo "$out" | grep -qE '→ version :[[:space:]]*$'; then
    fail "$name" "must not print empty version as successful mint; output: $out"
    return
  fi
  if echo "$out" | grep -q 'FORBIDDEN gh:'; then
    fail "$name" "must not call gh; output: $out"
    return
  fi
  pass "$name"
}

# (D) The DMG already mounted (exactly what the AGENTS.md pre-publish check
# leaves behind) must fail loudly and name that cause, never publish.
test_D_already_mounted_exits_1() {
  local name="(D) an already-mounted dmg exits 1 and names the cause"
  local out rc pre
  pre="$(mktemp -d "${TMPDIR:-/tmp}/g4-preattach.XXXXXX")"
  if ! hdiutil attach -nobrowse -readonly -mountpoint "$pre" "$FIXTURE_DMG" >/dev/null 2>&1; then
    rmdir "$pre" 2>/dev/null || true
    fail "$name" "could not pre-attach the fixture dmg"
    return
  fi

  set +e
  out="$("$SCRIPT" --dry-run "$FIXTURE_DMG" 2>&1)"
  rc=$?
  set -e

  hdiutil detach "$pre" >/dev/null 2>&1 || true
  rmdir "$pre" 2>/dev/null || true

  if [[ "$rc" -ne 1 ]]; then
    fail "$name" "expected exit 1, got $rc; output: $out"
    return
  fi
  if echo "$out" | grep -q '✓ dry-run: would publish'; then
    fail "$name" "must not publish from an already-mounted image; output: $out"
    return
  fi
  if ! echo "$out" | grep -qi 'already be mounted'; then
    fail "$name" "error must name the already-mounted cause; output: $out"
    return
  fi
  if echo "$out" | grep -q 'FORBIDDEN gh:'; then
    fail "$name" "must not call gh; output: $out"
    return
  fi
  pass "$name"
}

# ---- run --------------------------------------------------------------------

setup_stubs
build_fixture_dmg
build_empty_version_fixture_dmg

test_A_dry_run_mints_plist_version
test_B_extra_positional_exits_2
test_C_empty_version_exits_1
test_D_already_mounted_exits_1

cleanup_fixture
cleanup_stubs

echo ""
echo "$PASSED passed, $FAILED failed"
if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
