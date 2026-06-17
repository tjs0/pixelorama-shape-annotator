#!/usr/bin/env bash
set -euo pipefail
# Publishes a new build to GitHub.
#
# Usage:
#   ./release.sh <version>   # explicit semver, e.g. 0.2.0
#   ./release.sh patch       # bump 0.1.0 -> 0.1.1
#   ./release.sh minor       # bump 0.1.0 -> 0.2.0
#   ./release.sh major       # bump 0.1.0 -> 1.0.0
#
# Steps: bump version in extension.json, prepend a row to the README
# compatibility table, build the .pck, commit, tag, push, and create a DRAFT
# GitHub release with the .pck attached for review.
#
# The new compatibility row is prefilled by carrying forward the current top
# row's Pixelorama and Godot columns, then $EDITOR opens README.md so a human
# can adjust it before the release continues. Tweak this behavior with:
#   PIXELORAMA_VERSION=1.2.0 GODOT_VERSION="4.6.3, 4.7" ./release.sh minor
#   NO_EDIT=1 ./release.sh minor   # skip the editor, keep the prefilled row

ROOT="$(cd "$(dirname "$0")" && pwd)"
MANIFEST="$ROOT/src/Extensions/ShapeAnnotator/extension.json"
README="$ROOT/README.md"
PCK="$ROOT/dist/ShapeAnnotator.pck"

die() { echo "error: $*" >&2; exit 1; }

# Prepend a row to the README compatibility table for the new version. The
# Pixelorama/Godot columns default to the current top row, overridable via env.
update_readme() {
  local version="$1" tmp
  tmp="$(mktemp)"
  awk -v ver="$version" \
      -v pix="${PIXELORAMA_VERSION:-}" \
      -v godot="${GODOT_VERSION:-}" '
    { print }
    /^\|[[:space:]]*-/ && !inserted {
      if ((getline nextline) > 0) {
        split(nextline, c, "|")
        cur_pix = c[3];   gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur_pix)
        cur_godot = c[4]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", cur_godot)
        if (pix == "")   pix = cur_pix
        if (godot == "") godot = cur_godot
        printf "| %s | %s | %s |\n", ver, pix, godot
        print nextline
      }
      inserted = 1
    }
  ' "$README" >"$tmp" && mv "$tmp" "$README"
  grep -qF "| $version |" "$README" || die "failed to update README compatibility table"
}

[[ $# -eq 1 ]] || die "usage: $0 <version|patch|minor|major>"
command -v jq >/dev/null  || die "jq is required"
command -v gh >/dev/null  || die "gh (GitHub CLI) is required"
gh auth status >/dev/null 2>&1 || die "gh is not authenticated; run 'gh auth login'"

# Refuse to release from a dirty tree so the version bump is the only change.
[[ -z "$(git -C "$ROOT" status --porcelain)" ]] || die "working tree is dirty; commit or stash first"

CURRENT="$(jq -r '.version' "$MANIFEST")"
[[ "$CURRENT" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "current version '$CURRENT' is not semver"
IFS=. read -r MAJOR MINOR PATCH <<<"$CURRENT"

case "$1" in
  major) VERSION="$((MAJOR + 1)).0.0" ;;
  minor) VERSION="${MAJOR}.$((MINOR + 1)).0" ;;
  patch) VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))" ;;
  *)
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "'$1' is not a semver or bump keyword"
    VERSION="$1"
    ;;
esac

TAG="v$VERSION"
git -C "$ROOT" rev-parse "$TAG" >/dev/null 2>&1 && die "tag $TAG already exists"

echo "Releasing $CURRENT -> $VERSION ($TAG)"

# Bump the version in the manifest (single source of truth).
tmp="$(mktemp)"
jq --arg v "$VERSION" '.version = $v' "$MANIFEST" >"$tmp" && mv "$tmp" "$MANIFEST"

# Prepend a row to the README compatibility table, then let a human review/edit
# it. Set NO_EDIT=1 to skip the editor (e.g. in CI) and keep the prefilled row.
update_readme "$VERSION"
if [[ -z "${NO_EDIT:-}" ]]; then
  EDITOR_CMD="${VISUAL:-${EDITOR:-}}"
  [[ -n "$EDITOR_CMD" ]] || EDITOR_CMD="$(command -v nano || command -v vi || true)"
  [[ -n "$EDITOR_CMD" ]] || die "no editor found; set \$EDITOR or run with NO_EDIT=1"
  echo "Opening README.md for review (save and close to continue)..."
  $EDITOR_CMD "$README"
fi

# Build the distributable .pck.
"$ROOT/build.sh"
[[ -f "$PCK" ]] || die "build did not produce $PCK"

# Commit the version bump and tag it.
git -C "$ROOT" add "$MANIFEST" "$README"
git -C "$ROOT" commit -m "Release $TAG"
git -C "$ROOT" tag -a "$TAG" -m "Release $TAG"

# Push the commit and tag.
BRANCH="$(git -C "$ROOT" branch --show-current)"
git -C "$ROOT" push origin "$BRANCH"
git -C "$ROOT" push origin "$TAG"

# Create a draft release with the .pck attached.
gh release create "$TAG" "$PCK" \
  --repo "$(git -C "$ROOT" remote get-url origin)" \
  --title "$TAG" \
  --draft \
  --generate-notes

echo
echo "Draft release $TAG created. Review and publish it on GitHub:"
gh release view "$TAG" --web >/dev/null 2>&1 || true
