#!/usr/bin/env bash
set -euo pipefail

# Package a Flutter macOS release build into a signed, notarized DMG.
#
# Usage:
#   scripts/package-macos.sh --version 0.1.0 [options]
#
# Required:
#   --version VERSION       Semantic version (e.g. 0.1.0)
#
# Options:
#   --arch ARCH             Architecture label (default: arm64)
#   --app-path PATH         Path to .app bundle (default: build/macos/Build/Products/Release/Coqui.app)
#   --output-dir DIR        Output directory for DMG (default: build/macos)
#   --identity IDENTITY     Code signing identity (default: from CODESIGN_IDENTITY env var)
#   --notarize              Notarize the DMG (requires APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID env vars)
#   --no-sign               Skip code signing (for CI without certs)
#   -h, --help              Show this help

usage() {
  sed -n '3,20p' "$0" | sed 's/^# \?//'
}

version=""
arch="arm64"
appPath="build/macos/Build/Products/Release/Coqui.app"
outputDir="build/macos"
identity="${CODESIGN_IDENTITY:-}"
notarize='false'
sign='true'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:-}"; shift 2 ;;
    --arch) arch="${2:-}"; shift 2 ;;
    --app-path) appPath="${2:-}"; shift 2 ;;
    --output-dir) outputDir="${2:-}"; shift 2 ;;
    --identity) identity="${2:-}"; shift 2 ;;
    --notarize) notarize='true'; shift ;;
    --no-sign) sign='false'; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "Error: --version is required." >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$appPath" ]]; then
  echo "Error: app bundle not found at $appPath" >&2
  exit 1
fi

dmgName="Coqui-${version}-macos-${arch}.dmg"
dmgPath="${outputDir}/${dmgName}"

mkdir -p "$outputDir"

# ── Code Signing ──────────────────────────────────────────────────────

if [[ "$sign" == 'true' ]]; then
  if [[ -z "$identity" ]]; then
    echo "Error: code signing identity not set. Use --identity or CODESIGN_IDENTITY env var." >&2
    echo "Use --no-sign to skip signing." >&2
    exit 1
  fi

  echo "[sign] Signing ${appPath} with identity: ${identity}"
  codesign --deep --force --options runtime --sign "$identity" "$appPath"
  echo "[sign] Verifying signature..."
  codesign --verify --deep --strict "$appPath"
fi

# ── Create DMG ────────────────────────────────────────────────────────

echo "[dmg] Creating ${dmgPath}..."

# Create a temporary directory with the app and an Applications symlink
stagingDir="$(mktemp -d)"
trap 'rm -rf "$stagingDir"' EXIT

cp -a "$appPath" "${stagingDir}/Coqui.app"
ln -s /Applications "${stagingDir}/Applications"

# Create DMG from the staging directory
hdiutil create \
  -volname "Coqui" \
  -srcfolder "$stagingDir" \
  -ov \
  -format UDZO \
  "$dmgPath"

# Sign the DMG itself
if [[ "$sign" == 'true' ]]; then
  echo "[sign] Signing DMG..."
  codesign --force --sign "$identity" "$dmgPath"
fi

# ── Notarization ──────────────────────────────────────────────────────

if [[ "$notarize" == 'true' ]]; then
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" || -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "Error: notarization requires APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, and APPLE_TEAM_ID env vars." >&2
    exit 1
  fi

  echo "[notarize] Submitting ${dmgPath} for notarization..."
  xcrun notarytool submit "$dmgPath" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait

  echo "[notarize] Stapling notarization ticket..."
  xcrun stapler staple "$dmgPath"
fi

echo "[done] ${dmgPath}"
echo "::set-output name=artifact-path::${dmgPath}"
echo "::set-output name=artifact-name::${dmgName}"
