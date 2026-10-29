#!/usr/bin/env bash
# Installs (or updates) PR Pets from the latest GitHub release.
#   curl -fsSL https://raw.githubusercontent.com/thehenrymcintosh/pr-pets/main/install.sh | bash
# Options (environment variables):
#   PR_PETS_INSTALL_DIR  where to put the app (default: ~/Applications)
#   PR_PETS_VERSION      a specific release tag such as v0.2.0 (default: latest)
#   PR_PETS_NO_LAUNCH=1  install without opening the app
set -euo pipefail

repo="thehenrymcintosh/pr-pets"
install_dir="${PR_PETS_INSTALL_DIR:-$HOME/Applications}"
version="${PR_PETS_VERSION:-latest}"
app_name="PR Pets.app"

say() { printf '\033[1m%s\033[0m\n' "$*"; }
fail() { printf '\033[31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "PR Pets runs on macOS only."
macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= 14 )) || fail "PR Pets needs macOS 14 (Sonoma) or later; this Mac has $(sw_vers -productVersion)."

if [[ "$version" == "latest" ]]; then
  base_url="https://github.com/$repo/releases/latest/download"
else
  base_url="https://github.com/$repo/releases/download/$version"
fi

workspace="$(mktemp -d)"
trap 'rm -rf "$workspace"' EXIT

say "Downloading PR Pets ($version)…"
curl -fsSL --retry 3 -o "$workspace/PR-Pets.zip" "$base_url/PR-Pets.zip" \
  || fail "Couldn't download $base_url/PR-Pets.zip. Is there a published release?"
curl -fsSL --retry 3 -o "$workspace/PR-Pets.zip.sha256" "$base_url/PR-Pets.zip.sha256" \
  || fail "Couldn't download the release checksum."

expected="$(awk '{print $1}' "$workspace/PR-Pets.zip.sha256")"
actual="$(shasum -a 256 "$workspace/PR-Pets.zip" | awk '{print $1}')"
[[ "$expected" == "$actual" ]] || fail "Checksum mismatch (expected $expected, got $actual). Nothing was installed."

ditto -x -k "$workspace/PR-Pets.zip" "$workspace/unpacked"
[[ -d "$workspace/unpacked/$app_name" ]] || fail "The download didn't contain $app_name."

if pgrep -xq PRPets; then
  say "Quitting the running copy…"
  osascript -e 'quit app "PR Pets"' >/dev/null 2>&1 || pkill -x PRPets || true
  sleep 1
fi

mkdir -p "$install_dir"
rm -rf "${install_dir:?}/$app_name"
mv "$workspace/unpacked/$app_name" "$install_dir/"
# The app is ad-hoc signed rather than notarised; clear any quarantine flag so it opens without a warning.
xattr -dr com.apple.quarantine "$install_dir/$app_name" 2>/dev/null || true

say "Installed to $install_dir/$app_name"

if ! command -v gh >/dev/null 2>&1; then
  echo
  echo "PR Pets reads your pull requests through the GitHub CLI, which isn't installed yet:"
  echo "  brew install gh && gh auth login"
elif ! gh auth status >/dev/null 2>&1; then
  echo
  echo "Log the GitHub CLI in so PR Pets can see your pull requests:"
  echo "  gh auth login"
fi

if [[ "${PR_PETS_NO_LAUNCH:-}" != "1" ]]; then
  open "$install_dir/$app_name"
  say "PR Pets is running. Look for the doghouse at the bottom of your screen 🐾"
fi
