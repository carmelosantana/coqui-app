#!/usr/bin/env bash
set -euo pipefail

# ── upload-apple.sh ────────────────────────────────────────────────────
#
# Build (or locate) iOS IPA and macOS DMG for the current app version,
# then upload both artifacts plus an updated SHA256SUMS.txt to the
# matching GitHub Release.
#
# Usage:
#   scripts/upload-apple.sh [options]
#
# Options:
#   --no-build      Skip build step; use pre-existing artifacts
#   --ios-only      Build and upload iOS IPA only
#   --macos-only    Build and upload macOS DMG only
#   --tag TAG       Use a specific release tag (default: current version)
#   --dry-run       Show what would be uploaded without actually uploading
#   --skip-validation  Skip flutter analyze + test before building
#   -h, --help      Show this help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_DIR="${HOME}/.coqui-release"
CONFIG_FILE="${CONFIG_DIR}/config"

# ── Colors ────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${BLUE}[info]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
fail()    { echo -e "${RED}[✗]${NC} $1" >&2; }
step()    { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}\n"; }

config_get() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
    fi
}

get_current_version() {
    grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d+ -f1
}

resolve_macos_signing_identity() {
    local configured
    configured=$(config_get "MACOS_SIGNING_IDENTITY")
    if [[ -n "$configured" ]]; then
        echo "$configured"
        return 0
    fi
    security find-identity -v -p codesigning 2>/dev/null \
        | grep -i "Developer ID Application" | head -1 \
        | sed 's/.*"\(.*\)".*/\1/' || true
}

# ── Argument Parsing ──────────────────────────────────────────────────

do_build=true
do_ios=true
do_macos=true
dry_run=false
skip_validation=false
explicit_tag=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)          do_build=false; shift ;;
        --ios-only)          do_macos=false; shift ;;
        --macos-only)        do_ios=false; shift ;;
        --tag)               explicit_tag="${2:-}"; shift 2 ;;
        --dry-run)           dry_run=true; shift ;;
        --skip-validation)   skip_validation=true; shift ;;
        -h|--help)
            sed -n '3,20p' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run: scripts/upload-apple.sh --help" >&2
            exit 1
            ;;
    esac
done

# ── Pre-flight checks ─────────────────────────────────────────────────

if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "This script requires macOS (for Xcode signing tools)."
    exit 1
fi

if ! command -v gh &>/dev/null; then
    fail "GitHub CLI (gh) is not installed."
    echo ""
    echo "  Install: brew install gh"
    echo "  Auth:    gh auth login"
    exit 1
fi

if ! gh auth status &>/dev/null 2>&1; then
    fail "Not authenticated with GitHub CLI."
    echo ""
    echo "  Run: gh auth login"
    exit 1
fi

if ! command -v flutter &>/dev/null; then
    fail "flutter is not installed or not in PATH."
    exit 1
fi

# ── Resolve version and tag ───────────────────────────────────────────

version=$(get_current_version)

if [[ -n "$explicit_tag" ]]; then
    tag="$explicit_tag"
    # strip leading 'v' to get version number
    version="${tag#v}"
else
    tag="v${version}"
fi

step "Upload Apple Artifacts for ${tag}"

info "Version: ${version}"
info "Tag:     ${tag}"

# Verify the GitHub release exists
if ! gh release view "$tag" --repo "$(cd "$PROJECT_ROOT" && gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || git remote get-url origin | sed 's/.*github.com[:/]\(.*\)\.git/\1/')" &>/dev/null 2>&1; then
    fail "GitHub Release '${tag}' not found."
    echo ""
    echo "  Check existing releases:"
    echo "    gh release list"
    echo ""
    echo "  Create the release first with:"
    echo "    scripts/release.sh tag patch"
    echo "  or specify a different tag:"
    echo "    scripts/upload-apple.sh --tag v1.0.0"
    exit 1
fi

success "GitHub Release '${tag}' exists"

# ── Define artifact paths ─────────────────────────────────────────────

dmg_name="Coqui-${version}-macos-arm64.dmg"
dmg_path="${PROJECT_ROOT}/build/macos/${dmg_name}"

# IPA is renamed by build script; find it by name pattern or fallback to glob
ipa_name="Coqui-${version}-ios.ipa"
ipa_path="${PROJECT_ROOT}/build/ios/ipa/${ipa_name}"

# ── Build ─────────────────────────────────────────────────────────────

if [[ "$do_build" == "true" ]]; then
    if [[ "$skip_validation" != "true" ]]; then
        step "Pre-build Validation"
        info "flutter analyze..."
        (cd "$PROJECT_ROOT" && flutter analyze --no-fatal-infos)
        success "Static analysis passed"

        info "flutter test..."
        (cd "$PROJECT_ROOT" && flutter test)
        success "Tests passed"
    fi

    if [[ "$do_macos" == "true" ]]; then
        step "Building macOS DMG"

        # Validate macOS signing
        macos_identity=$(resolve_macos_signing_identity)
        if [[ -z "$macos_identity" ]]; then
            fail "No macOS signing identity found."
            echo ""
            echo "  Run: scripts/release-setup.sh apple"
            exit 1
        fi
        success "macOS identity: ${macos_identity}"

        info "flutter build macos --release..."
        (cd "$PROJECT_ROOT" && flutter build macos --release)

        # Set up notarization flags if credentials available
        notarize_flag=""
        if [[ -n "$(config_get APPLE_APP_SPECIFIC_PASSWORD)" && \
              -n "$(config_get APPLE_ID)" && \
              -n "$(config_get APPLE_TEAM_ID)" ]]; then
            notarize_flag="--notarize"
            export APPLE_ID="$(config_get APPLE_ID)"
            export APPLE_APP_SPECIFIC_PASSWORD="$(config_get APPLE_APP_SPECIFIC_PASSWORD)"
            export APPLE_TEAM_ID="$(config_get APPLE_TEAM_ID)"
            info "Notarization credentials found — DMG will be notarized"
        else
            warn "Notarization credentials not configured — DMG will be signed but not notarized"
        fi

        export CODESIGN_IDENTITY="$macos_identity"
        (cd "$PROJECT_ROOT" && ./scripts/package-macos.sh \
            --version "$version" \
            --arch arm64 \
            $notarize_flag)

        if [[ ! -f "$dmg_path" ]]; then
            fail "DMG not found after build: ${dmg_path}"
            exit 1
        fi
        success "macOS DMG: ${dmg_path}"
    fi

    if [[ "$do_ios" == "true" ]]; then
        step "Building iOS IPA"

        # Validate iOS signing
        ios_identity=$(config_get "APPLE_SIGNING_IDENTITY")
        if [[ -z "$ios_identity" ]]; then
            fail "No iOS signing identity configured."
            echo ""
            echo "  Run: scripts/release-setup.sh apple"
            exit 1
        fi

        if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$ios_identity"; then
            fail "iOS signing certificate not found in Keychain: ${ios_identity}"
            echo ""
            echo "  Certificate may have expired. Run: scripts/release-setup.sh apple"
            exit 1
        fi
        success "iOS identity: ${ios_identity}"

        local_export_plist="${PROJECT_ROOT}/ios/ExportOptions.plist"
        generated_plist=""

        if [[ -f "$local_export_plist" ]]; then
            info "Using ios/ExportOptions.plist"
            (cd "$PROJECT_ROOT" && flutter build ipa --release \
                --export-options-plist=ios/ExportOptions.plist)
        else
            team_id=$(config_get "APPLE_TEAM_ID")
            if [[ -z "$team_id" ]]; then
                fail "APPLE_TEAM_ID not configured and no ExportOptions.plist found."
                echo ""
                echo "  Run: scripts/release-setup.sh apple"
                exit 1
            fi

            generated_plist=$(mktemp "${TMPDIR:-/tmp}/coqui-ios-export.XXXXXX.plist")
            cat > "$generated_plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>uploadBitcode</key>
  <false/>
  <key>uploadSymbols</key>
  <true/>
  <key>teamID</key>
  <string>${team_id}</string>
</dict>
</plist>
EOF
            info "Using automatic App Store export (team: ${team_id})"
            (cd "$PROJECT_ROOT" && flutter build ipa --release \
                --export-options-plist="$generated_plist")
            rm -f "$generated_plist"
        fi

        # Rename the IPA to match the canonical artifact name
        raw_ipa=$(find "${PROJECT_ROOT}/build/ios/ipa" -name "*.ipa" -type f 2>/dev/null | head -1)
        if [[ -z "$raw_ipa" ]]; then
            fail "IPA not found after build."
            exit 1
        fi
        if [[ "$raw_ipa" != "$ipa_path" ]]; then
            mv "$raw_ipa" "$ipa_path"
        fi
        success "iOS IPA: ${ipa_path}"
    fi
fi

# ── Verify artifacts exist ────────────────────────────────────────────

step "Verifying Artifacts"

upload_files=()

if [[ "$do_macos" == "true" ]]; then
    if [[ ! -f "$dmg_path" ]]; then
        fail "macOS DMG not found: ${dmg_path}"
        echo ""
        echo "  Build it first: scripts/upload-apple.sh  (without --no-build)"
        exit 1
    fi
    upload_files+=("$dmg_path")
    info "macOS DMG: ${dmg_name} ($(du -sh "$dmg_path" | cut -f1))"
fi

if [[ "$do_ios" == "true" ]]; then
    if [[ ! -f "$ipa_path" ]]; then
        fail "iOS IPA not found: ${ipa_path}"
        echo ""
        echo "  Build it first: scripts/upload-apple.sh  (without --no-build)"
        exit 1
    fi
    upload_files+=("$ipa_path")
    info "iOS IPA:  ${ipa_name} ($(du -sh "$ipa_path" | cut -f1))"
fi

if [[ ${#upload_files[@]} -eq 0 ]]; then
    fail "No artifacts to upload."
    exit 1
fi

# ── Generate / update SHA256SUMS.txt ─────────────────────────────────

step "Checksums"

checksum_dir=$(mktemp -d)
trap 'rm -rf "$checksum_dir"' EXIT

# Download existing SHA256SUMS.txt from the release, if any
existing_checksums_file="${checksum_dir}/SHA256SUMS.txt"
repo=$(cd "$PROJECT_ROOT" && gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)

info "Downloading existing SHA256SUMS.txt from release..."
if gh release download "$tag" \
    --repo "$repo" \
    --pattern "SHA256SUMS.txt" \
    --dir "$checksum_dir" 2>/dev/null; then
    success "Existing checksums downloaded"
else
    info "No existing SHA256SUMS.txt — starting fresh"
    touch "$existing_checksums_file"
fi

# Remove old Apple entries (so we overwrite on re-upload)
if [[ -s "$existing_checksums_file" ]]; then
    grep -v "\.dmg\|\.ipa" "$existing_checksums_file" > "${checksum_dir}/SHA256SUMS.other.txt" || true
else
    touch "${checksum_dir}/SHA256SUMS.other.txt"
fi

# Generate checksums for our Apple artifacts (files may be in different dirs)
apple_checksums_file="${checksum_dir}/SHA256SUMS.apple.txt"
: > "$apple_checksums_file"
for f in "${upload_files[@]}"; do
    shasum -a 256 "$f" | awk -v name="$(basename "$f")" '{print $1 "  " name}' >> "$apple_checksums_file"
done

# Merge and sort
cat "${checksum_dir}/SHA256SUMS.other.txt" "$apple_checksums_file" \
    | sort -k2 \
    | grep -v '^$' \
    > "${checksum_dir}/SHA256SUMS.txt"

echo ""
cat "${checksum_dir}/SHA256SUMS.txt"
echo ""

upload_files+=("${checksum_dir}/SHA256SUMS.txt")

# ── Upload ────────────────────────────────────────────────────────────

step "Uploading to GitHub Release ${tag}"

if [[ "$dry_run" == "true" ]]; then
    warn "Dry run — would upload:"
    for f in "${upload_files[@]}"; do
        echo "  $(basename "$f")"
    done
    echo ""
    echo "  To: gh release upload ${tag} (repo: ${repo})"
    echo ""
    success "Dry run complete — no files were uploaded"
    exit 0
fi

info "Uploading ${#upload_files[@]} files..."

# --clobber replaces existing assets with the same name
gh release upload "$tag" \
    --repo "$repo" \
    --clobber \
    "${upload_files[@]}"

echo ""
success "Uploaded to GitHub Release ${tag}:"
for f in "${upload_files[@]}"; do
    echo "  $(basename "$f")"
done

echo ""
info "View release: https://github.com/${repo}/releases/tag/${tag}"
echo ""
