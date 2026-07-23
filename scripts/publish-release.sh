#!/usr/bin/env bash
#
# Publish a new TimeFlow version to this Homebrew tap.
#
#   ./scripts/publish-release.sh <version> <path-to-TimeFlow.dmg>
#   e.g.  ./scripts/publish-release.sh 0.2.2 ~/build/TimeFlow.dmg
#
# What it does:
#   1. Computes the .dmg sha256
#   2. Creates (or, for a re-run, updates) the GitHub Release  vX.Y.Z  with the
#      .dmg asset. The newest release is what  releases/latest/download/  and
#      the web download button both resolve to — so no web change per release.
#   3. Bumps  version  +  sha256  in Casks/timeflow.rb
#   4. Commits + pushes the cask
#
# Prereqs: `gh` authenticated (repo scope), run from a clone of this tap, and a
# .dmg already built (TimeFlowApp/scripts/build-dmg.sh).
set -euo pipefail

REPO="ercansavas/homebrew-tap"
CASK="Casks/timeflow.rb"
ASSET="TimeFlow.dmg"

VERSION="${1:-}"
DMG="${2:-}"
if [[ -z "$VERSION" || -z "$DMG" ]]; then
  echo "usage: $0 <version> <path-to-TimeFlow.dmg>" >&2
  echo "  e.g. $0 0.2.2 ~/build/TimeFlow.dmg" >&2
  exit 2
fi
[[ -f "$DMG" ]] || { echo "error: dmg not found: $DMG" >&2; exit 1; }

# Operate from the repo root so it works from anywhere inside the clone.
cd "$(git rev-parse --show-toplevel)"
[[ -f "$CASK" ]] || { echo "error: run inside the homebrew-tap clone ($CASK missing)" >&2; exit 1; }

TAG="v$VERSION"
SHA="$(shasum -a 256 "$DMG" | awk '{print $1}')"
echo "→ version : $VERSION"
echo "→ sha256  : $SHA"
echo "→ dmg     : $DMG"

# 1) GitHub Release + asset
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
