#!/usr/bin/env bash
# Wraps the SwiftPM executable in a macOS .app bundle and ad-hoc signs it.
# Usage: scripts/bundle-app.sh <executable> <output.app>
set -euo pipefail

executable="$1"
bundle="$2"
here="$(cd "$(dirname "$0")" && pwd)"
version="${VERSION:-}"
[[ -n "$version" ]] || version="$(git -C "$here/.." describe --tags --always 2>/dev/null | sed 's/^v//' || true)"
[[ "$version" =~ ^[0-9] ]] || version="0.0.0-dev"
# CFBundleVersion must be purely numeric; the short version can carry a suffix like 0.1.0-3-gabc123.
build_number="$(echo "$version" | grep -oE '^[0-9]+(\.[0-9]+){0,2}')"

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$executable" "$bundle/Contents/MacOS/PRPets"

cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PR Pets</string>
  <key>CFBundleDisplayName</key><string>PR Pets</string>
  <key>CFBundleIdentifier</key><string>dev.prpets.PRPets</string>
  <key>CFBundleExecutable</key><string>PRPets</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${version}</string>
  <key>CFBundleVersion</key><string>${build_number}</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

# The app icon is drawn by the preview tool from the same pixel art as the doghouse.
preview_tool="$(dirname "$executable")/pr-pets-preview"
if [[ -x "$preview_tool" ]]; then
  iconset="$(mktemp -d)/AppIcon.iconset"
  "$preview_tool" icon "$iconset" >/dev/null
  iconutil --convert icns --output "$bundle/Contents/Resources/AppIcon.icns" "$iconset"
fi

# Ad-hoc signature: enough for a locally built app to launch without Gatekeeper prompts.
codesign --force --sign - "$bundle" >/dev/null
echo "Built $bundle ($version)"
