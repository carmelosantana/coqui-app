#!/usr/bin/env bash
set -euo pipefail

# ── Coqui Release Orchestrator ─────────────────────────────────────────
#
# Usage:
#   scripts/release.sh setup                    Run first-time setup wizard
#   scripts/release.sh build [--platform P]     Build signed release artifacts
#   scripts/release.sh tag [VERSION|patch|minor|major]  Bump version, tag, push
#   scripts/release.sh publish                  Upload iOS IPA to TestFlight
#   scripts/release.sh status                   Show current release readiness

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

CONFIG_DIR="${HOME}/.coqui-release"
CONFIG_FILE="${CONFIG_DIR}/config"
BUNDLE_ID="ai.coquibot.app"

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
fail()    { echo -e "${RED}[✗]${NC} $1"; }
step()    { echo -e "\n${BOLD}${CYAN}── $1 ──${NC}\n"; }
prompt()  { echo -en "${BOLD}$1${NC} "; }

confirm() {
    local message="$1"
    prompt "$message [Y/n]"
    read -r response
    [[ -z "$response" || "$response" =~ ^[Yy] ]]
}

config_get() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2-
    fi
}

# ── Version Helpers ───────────────────────────────────────────────────

get_current_version() {
    grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d+ -f1
}

get_build_number() {
    local full
    full=$(grep '^version:' "${PROJECT_ROOT}/pubspec.yaml" | head -1 | awk '{print $2}')
    if [[ "$full" == *"+"* ]]; then
        echo "${full#*+}"
    else
        echo "1"
    fi
}

bump_version() {
    local current="$1"
    local bump_type="$2"

    local major minor patch
    IFS='.' read -r major minor patch <<< "$current"
    patch="${patch:-0}"
    minor="${minor:-0}"
    major="${major:-0}"

    case "$bump_type" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
        *)     echo "$bump_type" ;;  # Explicit version
    esac
}

set_version() {
    local new_version="$1"
    local build_num="$2"
    local pubspec="${PROJECT_ROOT}/pubspec.yaml"

    # Replace the version line in pubspec.yaml
    local current_line
    current_line=$(grep '^version:' "$pubspec" | head -1)
    local new_line="version: ${new_version}+${build_num}"

    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^version:.*|${new_line}|" "$pubspec"
    else
        sed -i "s|^version:.*|${new_line}|" "$pubspec"
    fi
}

validate_version() {
    local version="$1"
    if [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    fi
    return 1
}

# ── Status ───────────────────────────────────────────────────────────

cmd_status() {
    echo ""
    echo -e "${BOLD}${CYAN}Coqui Release Status${NC}"
    echo ""

    local version
    version=$(get_current_version)
    local build
    build=$(get_build_number)
    echo -e "  ${BOLD}Version:${NC}        ${version}+${build}"
    echo -e "  ${BOLD}Bundle ID:${NC}      ${BUNDLE_ID}"

    # Git status
    local branch
    branch=$(cd "$PROJECT_ROOT" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    local last_tag
    last_tag=$(cd "$PROJECT_ROOT" && git describe --tags --abbrev=0 2>/dev/null || echo "none")
    local dirty
    dirty=$(cd "$PROJECT_ROOT" && git status --porcelain 2>/dev/null | head -1)
    echo -e "  ${BOLD}Branch:${NC}         ${branch}"
    echo -e "  ${BOLD}Last tag:${NC}       ${last_tag}"
    echo -e "  ${BOLD}Working tree:${NC}   $([ -n "$dirty" ] && echo -e "${YELLOW}dirty${NC}" || echo -e "${GREEN}clean${NC}")"

    # Signing status
    echo ""
    echo -e "  ${BOLD}Signing:${NC}"

    local identity
    identity=$(config_get "APPLE_SIGNING_IDENTITY")
    if [[ -n "$identity" ]]; then
        echo -e "    Apple cert:   ${GREEN}✓${NC} $identity"
    else
        echo -e "    Apple cert:   ${RED}✗${NC} not configured"
    fi

    if [[ -n "$(config_get IOS_PROVISIONING_PROFILE_B64)" ]]; then
        echo -e "    iOS profile:  ${GREEN}✓${NC} configured"
    else
        echo -e "    iOS profile:  ${RED}✗${NC} not configured"
    fi

    if [[ -n "$(config_get MACOS_PROVISIONING_PROFILE_B64)" ]]; then
        echo -e "    macOS profile: ${GREEN}✓${NC} configured"
    else
        echo -e "    macOS profile: ${RED}✗${NC} not configured"
    fi

    if [[ -f "${PROJECT_ROOT}/android/key.properties" ]]; then
        echo -e "    Android keys: ${GREEN}✓${NC} key.properties exists"
    else
        echo -e "    Android keys: ${RED}✗${NC} key.properties missing"
    fi

    echo ""
    echo "  Run 'scripts/release-setup.sh verify' for full verification."
    echo ""
}

# ── Build ────────────────────────────────────────────────────────────

cmd_build() {
    local platform="all"
    local skip_validation=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform) platform="${2:-all}"; shift 2 ;;
            --skip-validation) skip_validation=true; shift ;;
            -h|--help)
                echo "Usage: scripts/release.sh build [--platform PLATFORM]"
                echo ""
                echo "Platforms: macos, ios, android, linux, windows, web, all"
                echo ""
                echo "Options:"
                echo "  --platform P         Build for specific platform (default: all)"
                echo "  --skip-validation    Skip flutter analyze + test"
                return 0
                ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
    done

    local version
    version=$(get_current_version)
    step "Building Coqui v${version} (${platform})"

    # Pre-flight validation
    if [[ "$skip_validation" != "true" ]]; then
        info "Running pre-build validation..."
        echo ""

        info "flutter analyze..."
        if ! (cd "$PROJECT_ROOT" && flutter analyze --no-fatal-infos); then
            fail "Static analysis failed. Fix the issues above before building."
            return 1
        fi
        success "Static analysis passed"

        info "flutter test..."
        if ! (cd "$PROJECT_ROOT" && flutter test); then
            fail "Tests failed. Fix the failing tests before building."
            return 1
        fi
        success "Tests passed"
        echo ""
    fi

    # Validate signing prerequisites per platform
    _validate_signing "$platform"

    # Determine which platforms to build
    local targets=()
    case "$platform" in
        all)
            case "$(uname -s)" in
                Darwin) targets=(macos ios android web) ;;
                Linux)  targets=(linux android web) ;;
                *)      targets=(web) ;;
            esac
            ;;
        *) targets=("$platform") ;;
    esac

    for target in "${targets[@]}"; do
        _build_target "$target" "$version"
    done

    echo ""
    success "Build complete!"
    echo ""
    echo "  Built artifacts:"

    # List what was built
    for target in "${targets[@]}"; do
        case "$target" in
            macos)   echo "    macOS:   build/macos/Coqui-${version}-macos-arm64.dmg" ;;
            ios)     echo "    iOS:     build/ios/ipa/" ;;
            android) echo "    Android: build/app/outputs/flutter-apk/app-release.apk" ;;
            linux)   echo "    Linux:   build/linux/Coqui-${version}-linux-x64.tar.gz" ;;
            windows) echo "    Windows: build/windows/Coqui-${version}-windows-x64.zip" ;;
            web)     echo "    Web:     build/web/" ;;
        esac
    done
    echo ""
}

_validate_signing() {
    local platform="$1"

    local needs_apple=false
    local needs_android=false

    case "$platform" in
        macos|ios)  needs_apple=true ;;
        android)    needs_android=true ;;
        all)        needs_apple=true; needs_android=true ;;
    esac

    if [[ "$needs_apple" == "true" && "$(uname -s)" == "Darwin" ]]; then
        local identity
        identity=$(config_get "APPLE_SIGNING_IDENTITY")
        if [[ -z "$identity" ]]; then
            fail "No Apple signing identity configured."
            echo ""
            echo "  Run: scripts/release-setup.sh apple"
            echo "  This will help you create or select a signing certificate."
            echo ""
            return 1
        fi

        # Verify cert is still in Keychain
        if ! security find-identity -v -p codesigning 2>/dev/null | grep -q "$identity"; then
            fail "Apple signing certificate '$identity' not found in Keychain."
            echo ""
            echo "  The certificate may have expired or been removed."
            echo "  Run: scripts/release-setup.sh apple"
            echo ""
            return 1
        fi
        success "Apple signing identity: $identity"
    fi

    if [[ "$needs_android" == "true" ]]; then
        if [[ ! -f "${PROJECT_ROOT}/android/key.properties" ]]; then
            fail "android/key.properties not found."
            echo ""
            echo "  Run: scripts/release-setup.sh android"
            echo "  This will create a keystore and key.properties file."
            echo ""
            return 1
        fi
        success "Android key.properties exists"
    fi
}

_build_target() {
    local target="$1"
    local version="$2"

    step "Building ${target}"

    case "$target" in
        macos)
            _build_macos "$version"
            ;;
        ios)
            _build_ios "$version"
            ;;
        android)
            _build_android "$version"
            ;;
        linux)
            (cd "$PROJECT_ROOT" && flutter build linux --release)
            (cd "$PROJECT_ROOT" && ./scripts/package-linux.sh --version "$version")
            success "Linux build: build/linux/Coqui-${version}-linux-x64.tar.gz"
            ;;
        windows)
            (cd "$PROJECT_ROOT" && flutter build windows --release)
            info "Package with: scripts/package-windows.ps1 -Version $version"
            ;;
        web)
            (cd "$PROJECT_ROOT" && flutter build web --wasm --release)
            success "Web build: build/web/"
            ;;
        *)
            fail "Unknown platform: $target"
            return 1
            ;;
    esac
}

_build_macos() {
    local version="$1"
    local identity
    identity=$(config_get "APPLE_SIGNING_IDENTITY")

    info "Building macOS release..."
    (cd "$PROJECT_ROOT" && flutter build macos --release)

    info "Creating signed DMG..."
    local notarize_flag=""
    if [[ -n "$(config_get APPLE_APP_SPECIFIC_PASSWORD)" && -n "$(config_get APPLE_ID)" && -n "$(config_get APPLE_TEAM_ID)" ]]; then
        notarize_flag="--notarize"
        # Set env vars for notarization
        export APPLE_ID="$(config_get APPLE_ID)"
        export APPLE_APP_SPECIFIC_PASSWORD="$(config_get APPLE_APP_SPECIFIC_PASSWORD)"
        export APPLE_TEAM_ID="$(config_get APPLE_TEAM_ID)"
        info "Notarization credentials found — DMG will be notarized"
    else
        warn "Notarization credentials not configured. DMG will be signed but not notarized."
        echo -e "  ${DIM}Run: scripts/release-setup.sh apple  (to set up app-specific password)${NC}"
    fi

    export CODESIGN_IDENTITY="$identity"

    (cd "$PROJECT_ROOT" && ./scripts/package-macos.sh \
        --version "$version" \
        $notarize_flag)

    success "macOS DMG: build/macos/Coqui-${version}-macos-arm64.dmg"
}

_build_ios() {
    local version="$1"
    local export_plist="${PROJECT_ROOT}/ios/ExportOptions.plist"
    local generated_export_plist=""
    local team_id=""
    local -a build_cmd=(flutter build ipa --release)

    info "Building iOS IPA..."

    if [[ -f "$export_plist" && -n "$(config_get IOS_PROVISIONING_PROFILE_B64)" ]]; then
        info "Using manual export options from ios/ExportOptions.plist"
        build_cmd+=(--export-options-plist=ios/ExportOptions.plist)
    else
        team_id=$(config_get "APPLE_TEAM_ID")
        if [[ -z "$team_id" ]]; then
            fail "APPLE_TEAM_ID is not configured."
            echo "  Run: scripts/release-setup.sh apple"
            return 1
        fi

        generated_export_plist=$(mktemp "${TMPDIR:-/tmp}/coqui-ios-export.XXXXXX.plist")
        cat > "$generated_export_plist" <<EOF
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

        info "No local iOS provisioning profile configured; using automatic App Store export for team ${team_id}"
        build_cmd+=(--export-options-plist="$generated_export_plist")
    fi

    if ! (cd "$PROJECT_ROOT" && "${build_cmd[@]}"); then
        [[ -n "$generated_export_plist" ]] && rm -f "$generated_export_plist"
        return 1
    fi

    [[ -n "$generated_export_plist" ]] && rm -f "$generated_export_plist"

    local ipa_file
    ipa_file=$(find "${PROJECT_ROOT}/build/ios/ipa" -name "*.ipa" -type f 2>/dev/null | head -1)

    if [[ -n "$ipa_file" ]]; then
        success "iOS IPA: $ipa_file"
        echo ""
        echo "  To upload to TestFlight:"
        echo "    scripts/release.sh publish"
        echo ""
        echo "  Or manually with Transporter (download from Mac App Store) or:"
        echo "    xcrun altool --upload-app -f \"$ipa_file\" -t ios \\"
        echo "      -u \"$(config_get APPLE_ID)\" -p \"@keychain:AC_PASSWORD\""
    else
        fail "IPA file not found in build/ios/ipa/"
        echo "  Check the build output above for errors."
    fi
}

_build_android() {
    local version="$1"

    info "Building Android APK..."
    (cd "$PROJECT_ROOT" && flutter build apk --release)

    local apk_file="${PROJECT_ROOT}/build/app/outputs/flutter-apk/app-release.apk"
    if [[ -f "$apk_file" ]]; then
        success "Android APK: $apk_file"
    else
        fail "APK not found at expected path."
        echo "  Check the build output above for errors."
    fi
}

# ── Tag ──────────────────────────────────────────────────────────────

cmd_tag() {
    local version_arg="${1:-}"

    local current_version
    current_version=$(get_current_version)
    local current_build
    current_build=$(get_build_number)

    step "Release Tag"

    echo "  Current version: ${current_version}+${current_build}"
    echo ""

    # Determine new version
    local new_version
    if [[ -z "$version_arg" ]]; then
        echo "  Usage: scripts/release.sh tag [VERSION|patch|minor|major]"
        echo ""
        echo "  Examples:"
        echo "    scripts/release.sh tag patch    # ${current_version} → $(bump_version "$current_version" patch)"
        echo "    scripts/release.sh tag minor    # ${current_version} → $(bump_version "$current_version" minor)"
        echo "    scripts/release.sh tag major    # ${current_version} → $(bump_version "$current_version" major)"
        echo "    scripts/release.sh tag 1.0.0    # ${current_version} → 1.0.0"
        echo ""
        return 0
    fi

    case "$version_arg" in
        patch|minor|major)
            new_version=$(bump_version "$current_version" "$version_arg")
            ;;
        *)
            new_version="$version_arg"
            ;;
    esac

    if ! validate_version "$new_version"; then
        fail "Invalid version format: $new_version"
        echo "  Version must be semver: X.Y.Z (e.g., 1.0.0)"
        return 1
    fi

    # Increment build number
    local new_build=$((current_build + 1))

    echo "  New version:     ${new_version}+${new_build}"
    echo "  Tag:             v${new_version}"
    echo ""

    if ! confirm "Proceed?"; then
        info "Cancelled."
        return 0
    fi

    # Run validation
    step "Pre-release validation"

    info "Running flutter analyze..."
    if ! (cd "$PROJECT_ROOT" && flutter analyze --no-fatal-infos); then
        fail "Static analysis failed. Fix the issues before releasing."
        return 1
    fi
    success "Static analysis passed"

    info "Running flutter test..."
    if ! (cd "$PROJECT_ROOT" && flutter test); then
        fail "Tests failed. Fix the failing tests before releasing."
        return 1
    fi
    success "Tests passed"

    # Update version in pubspec.yaml
    step "Updating version"
    set_version "$new_version" "$new_build"
    success "pubspec.yaml updated to ${new_version}+${new_build}"

    # Commit and tag
    step "Creating release commit and tag"
    (cd "$PROJECT_ROOT" && git add pubspec.yaml)
    (cd "$PROJECT_ROOT" && git commit -m "chore: release v${new_version}")
    (cd "$PROJECT_ROOT" && git tag "v${new_version}")
    success "Created commit and tag v${new_version}"

    # Push
    echo ""
    if confirm "Push to origin? (this triggers the CI release pipeline)"; then
        local branch
        branch=$(cd "$PROJECT_ROOT" && git rev-parse --abbrev-ref HEAD)
        (cd "$PROJECT_ROOT" && git push origin "$branch" --tags)
        success "Pushed to origin"
        echo ""
        echo -e "${BOLD}What happens next:${NC}"
        echo ""
        echo "  GitHub Actions will now:"
        echo "  1. Run validation (analyze + test)"
        echo "  2. Build all 6 platforms in parallel:"
        echo "     - Android APK (signed)"
        echo "     - macOS DMG (signed + notarized)"
        echo "     - iOS IPA (signed)"
        echo "     - Linux tar.gz"
        echo "     - Windows zip"
        echo "     - Web WASM"
        echo "  3. Create a GitHub Release with all artifacts"
        echo "  4. Deploy the web build to Vercel (app.coquibot.ai)"
        echo ""
        echo "  Monitor progress at:"
        local repo
        repo=$(cd "$PROJECT_ROOT" && gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || echo "your-org/coqui-app")
        echo "    https://github.com/${repo}/actions"
        echo ""
        echo "  After CI completes, submit the iOS IPA to TestFlight:"
        echo "    scripts/release.sh publish"
    else
        info "Tag created locally but not pushed."
        echo ""
        echo "  When ready, push with:"
        echo "    git push origin $(cd "$PROJECT_ROOT" && git rev-parse --abbrev-ref HEAD) --tags"
    fi
}

# ── Publish (TestFlight) ─────────────────────────────────────────────

cmd_publish() {
    step "Publish to TestFlight"

    if [[ "$(uname -s)" != "Darwin" ]]; then
        fail "TestFlight upload requires macOS with Xcode installed."
        echo ""
        echo "  Alternative: download the iOS IPA from the GitHub Release"
        echo "  and upload it using Transporter (Mac App Store) on a Mac."
        return 1
    fi

    # Find the IPA
    local ipa_file
    ipa_file=$(find "${PROJECT_ROOT}/build/ios/ipa" -name "*.ipa" -type f 2>/dev/null | head -1)

    if [[ -z "$ipa_file" ]]; then
        fail "No IPA file found in build/ios/ipa/"
        echo ""
        echo "  Build the IPA first:"
        echo "    scripts/release.sh build --platform ios"
        echo ""
        echo "  Or download it from the GitHub Release and place it in build/ios/ipa/"
        return 1
    fi

    info "Found IPA: $ipa_file"
    echo ""

    local apple_id
    apple_id=$(config_get "APPLE_ID")
    local app_password
    app_password=$(config_get "APPLE_APP_SPECIFIC_PASSWORD")

    if [[ -z "$apple_id" || -z "$app_password" ]]; then
        fail "Apple ID or app-specific password not configured."
        echo ""
        echo "  Run: scripts/release-setup.sh apple"
        return 1
    fi

    # Check if this is a first-time submission
    _print_first_time_checklist

    # Validate the IPA first
    info "Validating IPA..."
    if xcrun altool --validate-app \
        -f "$ipa_file" \
        -t ios \
        -u "$apple_id" \
        -p "$app_password" 2>&1; then
        success "IPA validation passed"
    else
        fail "IPA validation failed. Check the errors above."
        echo ""
        echo "  Common fixes:"
        echo "  - Ensure your provisioning profile matches the certificate"
        echo "  - Check that the bundle ID is '${BUNDLE_ID}'"
        echo "  - Verify the app version hasn't been used before"
        echo "  - Re-run: scripts/release-setup.sh profiles"
        return 1
    fi

    echo ""
    if confirm "Upload IPA to App Store Connect / TestFlight?"; then
        info "Uploading..."
        if xcrun altool --upload-app \
            -f "$ipa_file" \
            -t ios \
            -u "$apple_id" \
            -p "$app_password" 2>&1; then
            success "IPA uploaded to App Store Connect!"
            echo ""
            echo -e "${BOLD}Next steps:${NC}"
            echo ""
            echo "  1. Open App Store Connect: https://appstoreconnect.apple.com"
            echo "  2. Go to your app → TestFlight"
            echo "  3. The build will appear after Apple processing (5-30 minutes)"
            echo "  4. Add test notes and submit for TestFlight review"
            echo "  5. Once approved, testers can install via the TestFlight app"
            echo ""
            echo "  For App Store release:"
            echo "  1. Go to App Store → version page"
            echo "  2. Select this build"
            echo "  3. Complete all metadata and screenshots"
            echo "  4. Submit for App Store review"
        else
            fail "Upload failed. Check the errors above."
            echo ""
            echo "  If you get authentication errors:"
            echo "  - Re-generate your app-specific password at https://appleid.apple.com"
            echo "  - Run: scripts/release-setup.sh apple"
            echo ""
            echo "  Alternatively, use Transporter (free on Mac App Store):"
            echo "  1. Open Transporter"
            echo "  2. Drag and drop: $ipa_file"
            echo "  3. Click 'Deliver'"
        fi
    fi
}

_print_first_time_checklist() {
    echo -e "${BOLD}First-time App Store submission checklist:${NC}"
    echo ""
    echo "  If this is your FIRST submission to App Store Connect, you need to"
    echo "  create an app record before uploading:"
    echo ""
    echo "  1. Go to: https://appstoreconnect.apple.com/apps"
    echo "  2. Click '+' → 'New App'"
    echo "  3. Fill in:"
    echo "     - Platform: iOS"
    echo "     - Name: Coqui"
    echo "     - Primary Language: English (US)"
    echo "     - Bundle ID: ${BUNDLE_ID}"
    echo "     - SKU: coqui-app (anything unique)"
    echo "  4. Click 'Create'"
    echo "  5. Complete the app information:"
    echo "     - App Privacy: describe data collection/usage"
    echo "     - Age Rating: fill out the questionnaire"
    echo "     - App category: Developer Tools"
    echo "  6. On the Version page:"
    echo "     - Add screenshots (required for each device size)"
    echo "     - Write description, keywords, support URL"
    echo "     - Set pricing (free or paid)"
    echo ""
    echo "  Screenshots can be taken from the iOS Simulator:"
    echo "    Simulator → File → Save Screen (Cmd+S)"
    echo ""
    echo "  Minimum required screenshot sizes:"
    echo "    - 6.7\" (iPhone 15 Pro Max): 1290 × 2796"
    echo "    - 6.5\" (iPhone 14 Plus):    1284 × 2778"
    echo "    - iPad Pro 12.9\":           2048 × 2732"
    echo ""

    if ! confirm "App record already created in App Store Connect?"; then
        echo ""
        echo "  Create the app record first, then re-run: scripts/release.sh publish"
        echo ""
        if command -v open &>/dev/null; then
            if confirm "Open App Store Connect?"; then
                open "https://appstoreconnect.apple.com/apps"
            fi
        fi
        echo ""
        warn "Continuing anyway — the upload will succeed but the build won't appear"
        warn "until the app record exists with matching bundle ID."
    fi
    echo ""
}

# ── Setup (delegate) ─────────────────────────────────────────────────

cmd_setup() {
    exec "${SCRIPT_DIR}/release-setup.sh" "$@"
}

# ── Main ─────────────────────────────────────────────────────────────

usage() {
    echo ""
    echo -e "${BOLD}Coqui Release Orchestrator${NC}"
    echo ""
    echo "Usage: scripts/release.sh <command> [options]"
    echo ""
    echo "Commands:"
    echo "  setup                Run first-time setup wizard"
    echo "  build [--platform P] Build signed release artifacts"
    echo "  tag [VERSION]        Bump version, commit, tag, and push"
    echo "  publish              Upload iOS IPA to TestFlight"
    echo "  status               Show current release readiness"
    echo ""
    echo "Examples:"
    echo "  scripts/release.sh setup              # First-time signing setup"
    echo "  scripts/release.sh status             # Check readiness"
    echo "  scripts/release.sh tag patch           # 0.0.1 → 0.0.2, tag, push"
    echo "  scripts/release.sh tag 1.0.0           # Set explicit version"
    echo "  scripts/release.sh build --platform ios  # Build signed IPA"
    echo "  scripts/release.sh publish             # Upload to TestFlight"
    echo ""
    echo "Typical release flow:"
    echo "  1. scripts/release.sh setup            # One-time setup"
    echo "  2. scripts/release.sh tag patch         # Bump, tag, push → CI builds"
    echo "  3. scripts/release.sh publish           # Upload iOS to TestFlight"
    echo ""
}

case "${1:-}" in
    setup)    shift; cmd_setup "$@" ;;
    build)    shift; cmd_build "$@" ;;
    tag)      shift; cmd_tag "${1:-}" ;;
    publish)  cmd_publish ;;
    status)   cmd_status ;;
    -h|--help) usage ;;
    "")       usage ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Run: scripts/release.sh --help" >&2
        exit 1
        ;;
esac
