#!/usr/bin/env bash
#
# Publish a new TimeFlow version to this Homebrew tap.
#
#   ./scripts/publish-release.sh [--dry-run] <path-to-TimeFlow.dmg>
#   e.g.  ./scripts/publish-release.sh ~/build/TimeFlow.dmg
#
# What it does:
#   1. Mints VERSION from CFBundleShortVersionString inside the DMG (not argv)
#   2. Computes the .dmg sha256
#   3. Creates (or, for a re-run, updates) the GitHub Release  vX.Y.Z  with the
#      .dmg asset. The newest release is what  releases/latest/download/  and
#      the web download button both resolve to — so no web change per release.
#   4. Bumps  version  +  sha256  in Casks/timeflow.rb
#   5. Commits + pushes the cask
#
# Prereqs: `gh` authenticated (repo scope), run from a clone of this tap, and a
# .dmg already built (TimeFlowApp/scripts/build-dmg.sh).
set -euo pipefail

REPO="ercansavas/homebrew-tap"
CASK="Casks/timeflow.rb"
# Fixed name: a versioned asset once made every brew upgrade 404.
ASSET="TimeFlow.dmg"

DRY_RUN=0

# Flags first, then exactly one positional DMG. Exit 2 = usage/arity (not
# exit 1, which is reserved for missing file / attach failure).
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -*)
      echo "error: unknown flag: $1" >&2
      echo "usage: $0 [--dry-run] <path-to-TimeFlow.dmg>" >&2
      exit 2
      ;;
    *)
      break
      ;;
  esac
done

if [[ $# -ne 1 ]]; then
  echo "usage: $0 [--dry-run] <path-to-TimeFlow.dmg>" >&2
  echo "  e.g. $0 ~/build/TimeFlow.dmg" >&2
  exit 2
fi

DMG="$1"
[[ -f "$DMG" ]] || { echo "error: dmg not found: $DMG" >&2; exit 1; }

# Mint from the artefact so a mistyped argv cannot tag/cask a version the
# DMG does not contain. No trap EXIT: under set -u on bash 3.2 it can make a
# crash exit 0. Unique mount — never /Volumes/TimeFlow (leftover would pin
# the next publish at the wrong volume).
version_from_dmg() {
  local dmg="$1"
  local mnt version
  mnt="$(mktemp -d "${TMPDIR:-/tmp}/timeflow-dmg.XXXXXX")"
  if ! hdiutil attach -nobrowse -readonly -mountpoint "$mnt" "$dmg" >/dev/null; then
    rmdir "$mnt" 2>/dev/null || true
    echo "error: failed to attach dmg: $dmg" >&2
    exit 1
  fi
  if ! version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
      "$mnt/TimeFlow.app/Contents/Info.plist")"; then
    hdiutil detach "$mnt" >/dev/null || true
    rmdir "$mnt" 2>/dev/null || true
    echo "error: could not read CFBundleShortVersionString from dmg" >&2
    exit 1
  fi
  if ! hdiutil detach "$mnt" >/dev/null; then
    echo "error: failed to detach dmg mount: $mnt" >&2
    exit 1
  fi
  rmdir "$mnt" 2>/dev/null || true
  printf '%s' "$version"
}

VERSION="$(version_from_dmg "$DMG")"
# PlistBuddy succeeds on <string></string>; without this guard TAG becomes "v"
# and --dry-run exits 0. Non-empty is the gate — no semver parsing.
if [[ -z "$VERSION" ]]; then
  echo "error: CFBundleShortVersionString is empty in dmg: $DMG" >&2
  exit 1
fi
readonly VERSION

# Operate from the repo root so it works from anywhere inside the clone.
cd "$(git rev-parse --show-toplevel)"
[[ -f "$CASK" ]] || { echo "error: run inside the homebrew-tap clone ($CASK missing)" >&2; exit 1; }

TAG="v$VERSION"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "→ version : $VERSION"
echo "→ sha256  : $SHA"
echo "→ dmg     : $DMG"
echo "→ asset   : $ASSET"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo ""
  echo "✓ dry-run: would publish TimeFlow $VERSION (no gh / cask / git)"
  exit 0
fi

# 1) GitHub Release + asset (only after successful attach→read→detach)
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "→ release $TAG exists — replacing the $ASSET asset"
  gh release upload "$TAG" "$DMG#$ASSET" --repo "$REPO" --clobber
else
  echo "→ creating release $TAG"
  gh release create "$TAG" "$DMG#$ASSET" --repo "$REPO" \
    --title "TimeFlow $VERSION" \
    --notes "Soft-launch build (ad-hoc signed). Install: brew install --cask ercansavas/tap/timeflow"
fi

# 2) Bump the cask (version + sha256) — anchored to the two-space cask indent.
sed -i '' -E "s/^  version \"[^\"]*\"/  version \"$VERSION\"/" "$CASK"
sed -i '' -E "s/^  sha256 \"[^\"]*\"/  sha256 \"$SHA\"/" "$CASK"

# 3) Commit + push the cask
git add "$CASK"
git commit --author="ercansavas <ercansavas1@gmail.com>" -m "chore(timeflow): release $VERSION"
git push

echo ""
echo "✓ published TimeFlow $VERSION"
echo "  users update:  brew update && brew upgrade --cask ercansavas/tap/timeflow"
echo "  web already points at releases/latest — no web change needed"
