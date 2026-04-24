#!/usr/bin/env bash
set -euo pipefail

# ── Coqui Release Setup Wizard ─────────────────────────────────────────
#
# Interactive first-time setup for code signing, certificates,
# provisioning profiles, keystores, and CI secrets.
#
# Usage:
#   scripts/release-setup.sh              Run full setup flow
#   scripts/release-setup.sh apple        Apple certificate setup
#   scripts/release-setup.sh profiles     Provisioning profile setup
#   scripts/release-setup.sh android      Android keystore setup
#   scripts/release-setup.sh github       Push secrets to GitHub Actions
#   scripts/release-setup.sh vercel       Vercel deployment setup
#   scripts/release-setup.sh verify       Verify all signing requirements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Local config directory — outside repo, survives clones
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

# ── Helpers ───────────────────────────────────────────────────────────

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

read_input() {
    local message="$1"
    local var_name="$2"
    local default="${3:-}"
    if [[ -n "$default" ]]; then
        prompt "$message [$default]:"
    else
        prompt "$message:"
    fi
    read -r value
    if [[ -z "$value" && -n "$default" ]]; then
        value="$default"
    fi
    eval "$var_name=\$value"
}

read_secret() {
    local message="$1"
    local var_name="$2"
    prompt "$message:"
    read -rs value
    echo ""
    eval "$var_name=\$value"
}

config_get() {
    local key="$1"
    if [[ -f "$CONFIG_FILE" ]]; then
        grep "^${key}=" "$CONFIG_FILE" 2>/dev/null | head -1 | cut -d= -f2- || true
    fi
}

config_set() {
    local key="$1"
    local value="$2"
    mkdir -p "$CONFIG_DIR"
    if [[ -f "$CONFIG_FILE" ]] && grep -q "^${key}=" "$CONFIG_FILE" 2>/dev/null; then
        # Use a temp file for portable sed -i
        local tmp="${CONFIG_FILE}.tmp"
        sed "s|^${key}=.*|${key}=${value}|" "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    else
        echo "${key}=${value}" >> "$CONFIG_FILE"
    fi
    chmod 600 "$CONFIG_FILE"
}

check_command() {
    local cmd="$1"
    local install_msg="$2"
    if ! command -v "$cmd" &>/dev/null; then
        fail "$cmd is not installed."
        echo ""
        echo -e "  ${DIM}$install_msg${NC}"
        echo ""
        return 1
    fi
    return 0
}

detect_github_repo() {
    if [[ -n "${GITHUB_REPO:-}" ]]; then
        echo "$GITHUB_REPO"
        return 0
    fi

    local configured_repo
    configured_repo=$(config_get "GITHUB_REPO")
    if [[ -n "$configured_repo" ]]; then
        echo "$configured_repo"
        return 0
    fi

    local remote_url
    remote_url=$(cd "$PROJECT_ROOT" && git remote get-url origin 2>/dev/null || true)

    if [[ -n "$remote_url" ]]; then
        case "$remote_url" in
            git@github.com:*/*.git)
                echo "${remote_url#git@github.com:}" | sed 's/\.git$//'
                return 0
                ;;
            git@github.com:*/*)
                echo "${remote_url#git@github.com:}"
                return 0
                ;;
            https://github.com/*/*.git)
                echo "${remote_url#https://github.com/}" | sed 's/\.git$//'
                return 0
                ;;
            https://github.com/*/*)
                echo "${remote_url#https://github.com/}"
                return 0
                ;;
        esac
    fi

    GH_PAGER=cat GH_NO_UPDATE_NOTIFIER=1 \
        gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || true
}

# ── Prerequisites ─────────────────────────────────────────────────────

check_prerequisites() {
    step "Checking prerequisites"
    local all_ok=true

    if [[ "$(uname -s)" == "Darwin" ]]; then
        check_command "xcodebuild" "Install Xcode from the Mac App Store, then run: sudo xcode-select --install" || all_ok=false
        check_command "codesign" "Part of Xcode Command Line Tools: xcode-select --install" || all_ok=false
        check_command "xcrun" "Part of Xcode Command Line Tools: xcode-select --install" || all_ok=false
        check_command "hdiutil" "Built into macOS — if missing, your system may need repair" || all_ok=false
        check_command "security" "Built into macOS — if missing, your system may need repair" || all_ok=false
    fi

    check_command "flutter" "Install Flutter: https://docs.flutter.dev/get-started/install" || all_ok=false
    check_command "git" "Install git: https://git-scm.com/downloads" || all_ok=false

    if command -v keytool &>/dev/null; then
        success "keytool (Java) is available"
    else
        warn "keytool not found — needed for Android keystore generation."
        echo -e "  ${DIM}Install Java JDK 17+: brew install openjdk@17${NC}"
        all_ok=false
    fi

    if command -v gh &>/dev/null; then
        success "GitHub CLI (gh) is available"
    else
        warn "GitHub CLI (gh) not found — needed for pushing secrets to GitHub."
        echo -e "  ${DIM}Install: brew install gh${NC}"
        echo -e "  ${DIM}Then authenticate: gh auth login${NC}"
    fi

    if "$all_ok"; then
        success "All prerequisites met"
    else
        echo ""
        warn "Some prerequisites are missing. Install them and re-run this script."
        echo -e "  ${DIM}You can skip to specific sections (e.g., scripts/release-setup.sh android)${NC}"
    fi

    return 0
}

# ── Apple Certificate Setup ──────────────────────────────────────────

setup_apple() {
    step "Apple Certificate Setup"

    if [[ "$(uname -s)" != "Darwin" ]]; then
        warn "Apple certificate setup requires macOS."
        echo ""
        echo "  You need a Mac to create and manage Apple signing certificates."
        echo "  Run this script on your Mac, then use 'scripts/release-setup.sh github'"
        echo "  to push the secrets to GitHub Actions for CI builds."
        return 1
    fi

    echo "This will help you create an Apple Distribution certificate for signing"
    echo "iOS and macOS builds. You need an active Apple Developer Program membership."
    echo ""

    # Check for existing distribution certificates
    info "Checking for existing Apple signing certificates..."
    local existing_certs
    existing_certs=$(security find-identity -v -p codesigning 2>/dev/null | grep -i "apple distribution\|developer id application\|iPhone distribution" || true)

    if [[ -n "$existing_certs" ]]; then
        echo ""
        success "Found existing signing certificates:"
        echo "$existing_certs" | while IFS= read -r line; do
            echo -e "  ${DIM}$line${NC}"
        done
        echo ""

        if confirm "Use an existing certificate?"; then
            echo ""
            echo "Available identities:"
            echo ""
            local i=1
            local identities=()
            while IFS= read -r line; do
                local name
                name=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
                identities+=("$name")
                echo "  $i) $name"
                ((i++))
            done <<< "$existing_certs"
            echo ""
            read_input "Enter number" cert_choice "1"
            local idx=$(( cert_choice - 1 ))
            if [[ $idx -ge 0 && $idx -lt ${#identities[@]} ]]; then
                local selected_identity="${identities[$idx]}"
                config_set "APPLE_SIGNING_IDENTITY" "$selected_identity"
                success "Selected: $selected_identity"
            else
                fail "Invalid selection."
                return 1
            fi

            # Extract Team ID from the certificate
            _extract_team_id "$selected_identity"
            _export_p12 "$selected_identity"
            return 0
        fi
    fi

    # Generate new certificate
    echo ""
    info "We'll generate a Certificate Signing Request (CSR) and guide you through"
    info "creating a new Apple Distribution certificate."
    echo ""

    local csr_path="${CONFIG_DIR}/CoquiDistribution.certSigningRequest"
    local key_path="${CONFIG_DIR}/CoquiDistribution.key"

    mkdir -p "$CONFIG_DIR"

    read_input "Your email (for the CSR)" csr_email "$(config_get APPLE_ID)"

    info "Generating private key and CSR..."
    openssl req -new -newkey rsa:2048 -nodes \
        -keyout "$key_path" \
        -out "$csr_path" \
        -subj "/emailAddress=${csr_email}/CN=Coqui Distribution/C=US" \
        2>/dev/null

    chmod 600 "$key_path"
    success "CSR created at: $csr_path"
    echo ""

    echo -e "${BOLD}Now follow these steps in the Apple Developer portal:${NC}"
    echo ""
    echo "  1. Open the URL below in your browser"
    echo "  2. Click the '+' button to create a new certificate"
    echo "  3. Select 'Apple Distribution' (works for both iOS and macOS)"
    echo "  4. Click 'Continue'"
    echo "  5. Upload the CSR file: $csr_path"
    echo "  6. Click 'Continue' then 'Download'"
    echo "  7. The downloaded file will be named something like 'distribution.cer'"
    echo ""
    echo -e "  ${CYAN}https://developer.apple.com/account/resources/certificates/add${NC}"
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open the Apple Developer portal in your browser?"; then
            open "https://developer.apple.com/account/resources/certificates/add"
        fi
    fi

    echo ""
    read_input "Path to the downloaded .cer file" cer_path "$HOME/Downloads/distribution.cer"

    if [[ ! -f "$cer_path" ]]; then
        fail "Certificate file not found at: $cer_path"
        echo ""
        echo "  Download the certificate from the Apple Developer portal and try again."
        echo "  Re-run: scripts/release-setup.sh apple"
        return 1
    fi

    # Import into Keychain
    info "Importing certificate into Keychain..."
    security import "$cer_path" -k ~/Library/Keychains/login.keychain-db 2>/dev/null || \
        security import "$cer_path" 2>/dev/null || true

    # Also import the private key
    # Convert key + cert to p12 for import
    local temp_p12="${CONFIG_DIR}/temp_import.p12"
    # First convert .cer (DER) to .pem
    local pem_path="${CONFIG_DIR}/CoquiDistribution.pem"
    openssl x509 -inform DER -in "$cer_path" -out "$pem_path" 2>/dev/null || \
        cp "$cer_path" "$pem_path"

    read_secret "Choose a password for the .p12 export (remember this)" p12_password

    openssl pkcs12 -export \
        -inkey "$key_path" \
        -in "$pem_path" \
        -out "$temp_p12" \
        -passout "pass:${p12_password}" \
        2>/dev/null

    security import "$temp_p12" -P "$p12_password" -k ~/Library/Keychains/login.keychain-db -A 2>/dev/null || true
    rm -f "$temp_p12"

    # Find the newly imported identity
    sleep 1  # Give Keychain a moment to index
    local new_identity
    new_identity=$(security find-identity -v -p codesigning 2>/dev/null | grep -i "apple distribution" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)

    if [[ -z "$new_identity" ]]; then
        # Try Developer ID Application as fallback
        new_identity=$(security find-identity -v -p codesigning 2>/dev/null | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
    fi

    if [[ -n "$new_identity" ]]; then
        config_set "APPLE_SIGNING_IDENTITY" "$new_identity"
        success "Certificate imported: $new_identity"
        _extract_team_id "$new_identity"
        _export_p12 "$new_identity"
    else
        warn "Could not find the imported certificate in Keychain."
        echo ""
        echo "  Try opening Keychain Access (Applications → Utilities → Keychain Access)"
        echo "  and look for your distribution certificate under 'My Certificates'."
        echo "  Then re-run: scripts/release-setup.sh apple"
    fi
}

_extract_team_id() {
    local identity="$1"
    # Team ID is typically in parentheses at the end of the identity name
    local team_id
    team_id=$(echo "$identity" | grep -oE '\([A-Z0-9]+\)$' | tr -d '()' || true)

    if [[ -z "$team_id" ]]; then
        echo ""
        info "Could not auto-detect your Apple Team ID from the certificate."
        echo ""
        echo "  Find your Team ID at: https://developer.apple.com/account#MembershipDetailsCard"
        echo ""
        read_input "Enter your Apple Team ID (10-character alphanumeric)" team_id "$(config_get APPLE_TEAM_ID)"
    fi

    if [[ -n "$team_id" ]]; then
        config_set "APPLE_TEAM_ID" "$team_id"
        success "Apple Team ID: $team_id"
    fi
}

_export_p12() {
    local identity="$1"
    local p12_path="${CONFIG_DIR}/apple-distribution.p12"

    echo ""
    info "Exporting certificate as .p12 for CI use..."
    echo ""
    echo "  macOS will show a dialog asking you to allow access to the certificate."
    echo "  You may need to enter your macOS login password and choose a .p12 export password."
    echo ""

    if confirm "Export .p12 now? (macOS will show a Keychain prompt)"; then
        read_secret "Choose a password for the .p12 export" p12_export_password

        # Try to export via security command
        local hash
        hash=$(security find-identity -v -p codesigning 2>/dev/null | grep "$identity" | head -1 | awk '{print $2}' || true)

        if [[ -n "$hash" ]]; then
            # Export using security cms
            security export -k ~/Library/Keychains/login.keychain-db \
                -t identities -f pkcs12 \
                -P "$p12_export_password" \
                -o "$p12_path" 2>/dev/null || {
                    warn "Automatic export failed. Please export manually:"
                    echo ""
                    echo "  1. Open Keychain Access (Applications → Utilities → Keychain Access)"
                    echo "  2. Select 'My Certificates' in the sidebar"
                    echo "  3. Right-click your Apple Distribution certificate → Export"
                    echo "  4. Save as .p12 to: $p12_path"
                    echo "  5. Re-run: scripts/release-setup.sh apple"
                    echo ""
                    read_input "Or enter path to manually exported .p12" p12_path "$p12_path"
                }
        fi

        if [[ -f "$p12_path" ]]; then
            config_set "APPLE_CERTIFICATE_P12_PATH" "$p12_path"
            config_set "APPLE_CERTIFICATE_PASSWORD" "$p12_export_password"

            # Base64 encode for GitHub secrets
            local p12_b64
            p12_b64=$(base64 -i "$p12_path")
            config_set "APPLE_CERTIFICATE_P12_B64" "$p12_b64"

            chmod 600 "$p12_path"
            success "Certificate exported and base64-encoded for CI"
        fi
    else
        echo ""
        echo "  You can export later from Keychain Access and re-run this command."
    fi
}

# ── Apple App-Specific Password ──────────────────────────────────────

setup_apple_password() {
    step "Apple App-Specific Password"

    echo "An app-specific password is required for notarization and TestFlight uploads."
    echo "This is NOT your Apple ID password — it's a separate password generated at Apple."
    echo ""

    local existing_email
    existing_email=$(config_get "APPLE_ID")

    read_input "Your Apple ID email" apple_id "${existing_email}"
    config_set "APPLE_ID" "$apple_id"

    echo ""
    echo -e "${BOLD}Generate an app-specific password:${NC}"
    echo ""
    echo "  1. Go to https://appleid.apple.com/account/manage"
    echo "  2. Sign in with your Apple ID"
    echo "  3. In the 'App-Specific Passwords' section, click 'Generate'"
    echo "     (or look under Security → App-Specific Passwords)"
    echo "  4. Name it 'Coqui CI' (or anything you'll recognize)"
    echo "  5. Copy the generated password (format: xxxx-xxxx-xxxx-xxxx)"
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open Apple ID settings in your browser?"; then
            open "https://appleid.apple.com/account/manage"
        fi
    fi

    echo ""
    read_secret "Paste the app-specific password" app_password

    if [[ -n "$app_password" ]]; then
        config_set "APPLE_APP_SPECIFIC_PASSWORD" "$app_password"
        success "App-specific password saved"
    else
        warn "No password entered. You can set this later by re-running: scripts/release-setup.sh apple"
    fi
}

# ── Provisioning Profiles ────────────────────────────────────────────

setup_profiles() {
    step "Provisioning Profile Setup"

    if [[ "$(uname -s)" != "Darwin" ]]; then
        warn "Provisioning profile setup requires macOS."
        return 1
    fi

    echo "Provisioning profiles link your app's bundle ID to your signing certificate"
    echo "and specify which devices can run the app."
    echo ""
    echo "You need two profiles:"
    echo "  1. iOS Distribution — for App Store / TestFlight"
    echo "  2. macOS Developer ID — for direct distribution (signed + notarized DMG)"
    echo ""

    # Check if App ID is registered
    echo -e "${BOLD}Step 1: Register your App ID${NC}"
    echo ""
    echo "  First, ensure '${BUNDLE_ID}' is registered as an App ID."
    echo ""
    echo "  1. Go to: https://developer.apple.com/account/resources/identifiers/list"
    echo "  2. Look for '${BUNDLE_ID}' in the list"
    echo "  3. If it's not there, click '+' and register it:"
    echo "     - Select 'App IDs' → 'App'"
    echo "     - Description: Coqui"
    echo "     - Bundle ID: Explicit → ${BUNDLE_ID}"
    echo "     - Enable capabilities your app uses (Push Notifications, etc.)"
    echo "     - Click 'Continue' then 'Register'"
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open the App IDs page in your browser?"; then
            open "https://developer.apple.com/account/resources/identifiers/list"
        fi
    fi

    if ! confirm "Is the App ID '${BUNDLE_ID}' registered?"; then
        warn "Register the App ID first, then re-run: scripts/release-setup.sh profiles"
        return 1
    fi

    # iOS Distribution Profile
    echo ""
    echo -e "${BOLD}Step 2: Create iOS Distribution Provisioning Profile${NC}"
    echo ""
    echo "  1. Go to: https://developer.apple.com/account/resources/profiles/add"
    echo "  2. Select 'App Store Connect' under Distribution"
    echo "  3. Click 'Continue'"
    echo "  4. Select App ID: ${BUNDLE_ID}"
    echo "  5. Click 'Continue'"
    echo "  6. Select your Apple Distribution certificate"
    echo "  7. Click 'Continue'"
    echo "  8. Name it: 'Coqui iOS Distribution'"
    echo "  9. Click 'Generate' then 'Download'"
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open the provisioning profiles page?"; then
            open "https://developer.apple.com/account/resources/profiles/add"
        fi
    fi

    echo ""
    read_input "Path to downloaded iOS provisioning profile (.mobileprovision)" ios_profile_path "$HOME/Downloads/Coqui_iOS_Distribution.mobileprovision"

    if [[ -f "$ios_profile_path" ]]; then
        # Install to standard location
        mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
        cp "$ios_profile_path" ~/Library/MobileDevice/Provisioning\ Profiles/
        cp "$ios_profile_path" "${CONFIG_DIR}/ios_distribution.mobileprovision"

        # Base64 encode for CI
        local ios_b64
        ios_b64=$(base64 -i "$ios_profile_path")
        config_set "IOS_PROVISIONING_PROFILE_B64" "$ios_b64"
        config_set "IOS_PROVISIONING_PROFILE_PATH" "$ios_profile_path"

        success "iOS provisioning profile installed and encoded for CI"
    else
        warn "iOS provisioning profile not found at: $ios_profile_path"
        echo "  Download it from the Apple Developer portal and re-run this command."
    fi

    # macOS Developer ID Profile (for direct distribution outside Mac App Store)
    echo ""
    echo -e "${BOLD}Step 3: Create macOS Developer ID Provisioning Profile${NC}"
    echo ""
    echo "  Since we're distributing macOS builds as signed DMGs (not via the Mac App Store),"
    echo "  you need a Developer ID provisioning profile."
    echo ""
    echo "  1. Go to: https://developer.apple.com/account/resources/profiles/add"
    echo "  2. Select 'Developer ID' under Distribution"
    echo "  3. Select your Developer ID Application certificate"
    echo "     (If you don't have one, create it at: https://developer.apple.com/account/resources/certificates/add"
    echo "      → select 'Developer ID Application')"
    echo "  4. Select App ID: ${BUNDLE_ID}"
    echo "  5. Name it: 'Coqui macOS Developer ID'"
    echo "  6. Click 'Generate' then 'Download'"
    echo ""
    echo "  Note: If you only have an Apple Distribution certificate (not Developer ID),"
    echo "  the macOS build will use that certificate for App Store distribution."
    echo "  For direct DMG downloads, a Developer ID certificate is recommended."
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open the provisioning profiles page?"; then
            open "https://developer.apple.com/account/resources/profiles/add"
        fi
    fi

    echo ""
    read_input "Path to downloaded macOS provisioning profile (.provisionprofile)" macos_profile_path "$HOME/Downloads/Coqui_macOS_Developer_ID.provisionprofile"

    if [[ -f "$macos_profile_path" ]]; then
        mkdir -p ~/Library/MobileDevice/Provisioning\ Profiles/
        cp "$macos_profile_path" ~/Library/MobileDevice/Provisioning\ Profiles/
        cp "$macos_profile_path" "${CONFIG_DIR}/macos_developer_id.provisionprofile"

        local macos_b64
        macos_b64=$(base64 -i "$macos_profile_path")
        config_set "MACOS_PROVISIONING_PROFILE_B64" "$macos_b64"
        config_set "MACOS_PROVISIONING_PROFILE_PATH" "$macos_profile_path"

        success "macOS provisioning profile installed and encoded for CI"
    else
        warn "macOS provisioning profile not found at: $macos_profile_path"
        echo "  Download it and re-run: scripts/release-setup.sh profiles"
    fi
}

# ── Android Keystore ─────────────────────────────────────────────────

setup_android() {
    step "Android Keystore Setup"

    echo "An Android keystore is needed to sign release APKs. The same keystore"
    echo "must be used for all future releases — if you lose it, you cannot update"
    echo "the app on the Play Store or via sideloading on devices that have the old version."
    echo ""

    local keystore_path="${CONFIG_DIR}/coqui-release.jks"

    if [[ -f "$keystore_path" ]]; then
        success "Existing keystore found at: $keystore_path"
        if ! confirm "Create a new keystore? (this will NOT overwrite the existing one)"; then
            _configure_android_key_properties "$keystore_path"
            return 0
        fi
        # Don't overwrite — use a different name
        keystore_path="${CONFIG_DIR}/coqui-release-$(date +%Y%m%d).jks"
    fi

    if ! command -v keytool &>/dev/null; then
        fail "keytool is not installed (part of Java JDK)."
        echo ""
        echo "  Install Java JDK 17+:"
        echo "    macOS:   brew install openjdk@17"
        echo "    Ubuntu:  sudo apt install openjdk-17-jdk"
        echo ""
        echo "  Then re-run: scripts/release-setup.sh android"
        return 1
    fi

    local key_alias="coqui"
    read_input "Key alias" key_alias "$key_alias"
    read_secret "Choose a keystore password (min 6 characters)" ks_password

    if [[ ${#ks_password} -lt 6 ]]; then
        fail "Password must be at least 6 characters."
        return 1
    fi

    read_secret "Choose a key password (press Enter to use same as keystore)" key_password
    if [[ -z "$key_password" ]]; then
        key_password="$ks_password"
    fi

    info "Generating keystore..."
    mkdir -p "$CONFIG_DIR"

    keytool -genkey -v \
        -keystore "$keystore_path" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -alias "$key_alias" \
        -storepass "$ks_password" \
        -keypass "$key_password" \
        -dname "CN=Coqui, O=Coqui, C=US"

    chmod 600 "$keystore_path"

    config_set "ANDROID_KEYSTORE_PATH" "$keystore_path"
    config_set "ANDROID_KEYSTORE_PASSWORD" "$ks_password"
    config_set "ANDROID_KEY_ALIAS" "$key_alias"
    config_set "ANDROID_KEY_PASSWORD" "$key_password"

    # Base64 encode for CI
    local ks_b64
    ks_b64=$(base64 -i "$keystore_path")
    config_set "ANDROID_KEYSTORE_B64" "$ks_b64"

    success "Android keystore created at: $keystore_path"

    _configure_android_key_properties "$keystore_path"

    echo ""
    warn "IMPORTANT: Back up your keystore! If you lose it, you cannot update"
    warn "your app. Store a copy somewhere safe outside this machine."
}

_configure_android_key_properties() {
    local keystore_path="$1"
    local key_alias
    key_alias=$(config_get "ANDROID_KEY_ALIAS")
    local ks_password
    ks_password=$(config_get "ANDROID_KEYSTORE_PASSWORD")
    local key_password
    key_password=$(config_get "ANDROID_KEY_PASSWORD")

    if [[ -z "$key_alias" || -z "$ks_password" ]]; then
        warn "Keystore credentials not found in config. Skipping key.properties."
        return
    fi

    local props_file="${PROJECT_ROOT}/android/key.properties"
    cat > "$props_file" <<EOF
storePassword=${ks_password}
keyPassword=${key_password}
keyAlias=${key_alias}
storeFile=${keystore_path}
EOF
    chmod 600 "$props_file"
    success "Created android/key.properties (gitignored — never committed)"
}

# ── GitHub Secrets ───────────────────────────────────────────────────

setup_github() {
    step "GitHub Secrets Setup"

    if ! command -v gh &>/dev/null; then
        fail "GitHub CLI (gh) is not installed."
        echo ""
        echo "  Install it:"
        echo "    macOS:   brew install gh"
        echo "    Ubuntu:  sudo apt install gh"
        echo ""
        echo "  Then authenticate:"
        echo "    gh auth login"
        echo ""
        echo "  And re-run: scripts/release-setup.sh github"
        return 1
    fi

    # Check auth
    if ! gh auth status &>/dev/null 2>&1; then
        fail "Not authenticated with GitHub CLI."
        echo ""
        echo "  Run: gh auth login"
        echo "  Then re-run: scripts/release-setup.sh github"
        return 1
    fi

    # Detect repo
    local repo
    repo=$(detect_github_repo)

    if [[ -z "$repo" ]]; then
        warn "Could not detect GitHub repo from current directory."
        read_input "Enter repo (owner/name)" repo ""
        if [[ -z "$repo" ]]; then
            fail "No repo specified."
            return 1
        fi
    fi

    info "Pushing secrets to: $repo"
    echo ""

    local secrets_set=0
    local secrets_failed=0

    _push_secret() {
        local name="$1"
        local config_key="$2"
        local value
        value=$(config_get "$config_key")

        if [[ -n "$value" ]]; then
            if echo "$value" | gh secret set "$name" -R "$repo" 2>/dev/null; then
                success "$name"
                ((secrets_set += 1))
            else
                fail "$name — failed to set"
                ((secrets_failed += 1))
            fi
        else
            warn "$name — no value found in config (key: $config_key)"
            echo -e "  ${DIM}Run the relevant setup step first, then re-run: scripts/release-setup.sh github${NC}"
            ((secrets_failed += 1))
        fi
    }

    echo "── Apple Signing ──"
    _push_secret "APPLE_CERTIFICATE_P12" "APPLE_CERTIFICATE_P12_B64"
    _push_secret "APPLE_CERTIFICATE_PASSWORD" "APPLE_CERTIFICATE_PASSWORD"
    _push_secret "APPLE_TEAM_ID" "APPLE_TEAM_ID"
    _push_secret "APPLE_ID" "APPLE_ID"
    _push_secret "APPLE_APP_SPECIFIC_PASSWORD" "APPLE_APP_SPECIFIC_PASSWORD"

    # Generate a random keychain password for CI
    local kc_pass
    kc_pass=$(openssl rand -base64 24 2>/dev/null || head -c 32 /dev/urandom | base64)
    config_set "KEYCHAIN_PASSWORD" "$kc_pass"
    _push_secret "KEYCHAIN_PASSWORD" "KEYCHAIN_PASSWORD"

    echo ""
    echo "── Provisioning Profiles ──"
    _push_secret "IOS_PROVISIONING_PROFILE" "IOS_PROVISIONING_PROFILE_B64"
    _push_secret "MACOS_PROVISIONING_PROFILE" "MACOS_PROVISIONING_PROFILE_B64"

    echo ""
    echo "── Android Signing ──"
    _push_secret "ANDROID_KEYSTORE_BASE64" "ANDROID_KEYSTORE_B64"
    _push_secret "ANDROID_KEYSTORE_PASSWORD" "ANDROID_KEYSTORE_PASSWORD"
    _push_secret "ANDROID_KEY_ALIAS" "ANDROID_KEY_ALIAS"
    _push_secret "ANDROID_KEY_PASSWORD" "ANDROID_KEY_PASSWORD"

    echo ""
    info "$secrets_set secrets set, $secrets_failed skipped/failed"

    if [[ $secrets_failed -gt 0 ]]; then
        echo ""
        warn "Some secrets were not set. Run the corresponding setup step:"
        echo "  Apple certs:  scripts/release-setup.sh apple"
        echo "  Profiles:     scripts/release-setup.sh profiles"
        echo "  Android:      scripts/release-setup.sh android"
        echo "  Then re-run:  scripts/release-setup.sh github"
    fi
}

# ── Vercel Setup ─────────────────────────────────────────────────────

setup_vercel() {
    step "Vercel Deployment Setup"

    echo "Vercel deploys the web WASM build to app.coquibot.ai."
    echo "You need a Vercel account and a project linked to this repo."
    echo ""

    if ! command -v gh &>/dev/null; then
        warn "GitHub CLI (gh) is needed to push Vercel secrets. Install it first."
        return 1
    fi

    local repo
    repo=$(detect_github_repo)

    echo -e "${BOLD}Step 1: Get your Vercel token${NC}"
    echo ""
    echo "  1. Go to: https://vercel.com/account/tokens"
    echo "  2. Click 'Create Token'"
    echo "  3. Name it: 'Coqui GitHub Actions'"
    echo "  4. Copy the token"
    echo ""

    if command -v open &>/dev/null; then
        if confirm "Open Vercel tokens page?"; then
            open "https://vercel.com/account/tokens"
        fi
    fi

    echo ""
    read_secret "Paste your Vercel token" vercel_token

    echo ""
    echo -e "${BOLD}Step 2: Get your Vercel project IDs${NC}"
    echo ""
    echo "  1. Go to your Vercel project dashboard"
    echo "  2. Click 'Settings' → 'General'"
    echo "  3. Scroll to 'Project ID' — copy it"
    echo "  4. Your Org ID is on your account settings page: https://vercel.com/account"
    echo "     (look for 'Team ID' or 'User ID')"
    echo ""

    read_input "Vercel Org ID" vercel_org_id "$(config_get VERCEL_ORG_ID)"
    read_input "Vercel Project ID" vercel_project_id "$(config_get VERCEL_PROJECT_ID)"

    if [[ -n "$vercel_token" ]]; then
        config_set "VERCEL_TOKEN" "$vercel_token"
    fi
    if [[ -n "$vercel_org_id" ]]; then
        config_set "VERCEL_ORG_ID" "$vercel_org_id"
    fi
    if [[ -n "$vercel_project_id" ]]; then
        config_set "VERCEL_PROJECT_ID" "$vercel_project_id"
    fi

    if [[ -n "$repo" ]]; then
        echo ""
        info "Pushing Vercel secrets to GitHub..."
        local ok=true
        echo "$vercel_token" | gh secret set "VERCEL_TOKEN" -R "$repo" 2>/dev/null && success "VERCEL_TOKEN" || { fail "VERCEL_TOKEN"; ok=false; }
        echo "$vercel_org_id" | gh secret set "VERCEL_ORG_ID" -R "$repo" 2>/dev/null && success "VERCEL_ORG_ID" || { fail "VERCEL_ORG_ID"; ok=false; }
        echo "$vercel_project_id" | gh secret set "VERCEL_PROJECT_ID" -R "$repo" 2>/dev/null && success "VERCEL_PROJECT_ID" || { fail "VERCEL_PROJECT_ID"; ok=false; }

        if "$ok"; then
            success "All Vercel secrets pushed to GitHub"
        fi
    else
        warn "Could not detect GitHub repo. Push secrets manually with: scripts/release-setup.sh github"
    fi
}

# ── Verify ───────────────────────────────────────────────────────────

verify() {
    step "Release Readiness Verification"

    local total=0
    local passed=0

    _check() {
        local label="$1"
        local ok="$2"
        ((total += 1))
        if [[ "$ok" == "true" ]]; then
            success "$label"
            ((passed += 1))
        else
            fail "$label"
        fi
    }

    echo "── Local Environment ──"
    echo ""

    _check "Flutter SDK installed" "$(command -v flutter &>/dev/null && echo true || echo false)"
    _check "Git installed" "$(command -v git &>/dev/null && echo true || echo false)"
    _check "GitHub CLI (gh) installed" "$(command -v gh &>/dev/null && echo true || echo false)"

    if [[ "$(uname -s)" == "Darwin" ]]; then
        _check "Xcode CLI tools installed" "$(command -v xcodebuild &>/dev/null && echo true || echo false)"
        _check "codesign available" "$(command -v codesign &>/dev/null && echo true || echo false)"

        local has_identity="false"
        local identity
        identity=$(config_get "APPLE_SIGNING_IDENTITY")
        if [[ -n "$identity" ]]; then
            if security find-identity -v -p codesigning 2>/dev/null | grep -q "$identity"; then
                has_identity="true"
            fi
        fi
        _check "Apple signing certificate in Keychain" "$has_identity"
    fi

    _check "keytool (Java) available" "$(command -v keytool &>/dev/null && echo true || echo false)"

    echo ""
    echo "── Config (~/.coqui-release/) ──"
    echo ""

    _check "Config directory exists" "$([[ -d "$CONFIG_DIR" ]] && echo true || echo false)"
    _check "Apple signing identity set" "$([[ -n "$(config_get APPLE_SIGNING_IDENTITY)" ]] && echo true || echo false)"
    _check "Apple Team ID set" "$([[ -n "$(config_get APPLE_TEAM_ID)" ]] && echo true || echo false)"
    _check "Apple ID (email) set" "$([[ -n "$(config_get APPLE_ID)" ]] && echo true || echo false)"
    _check "Apple app-specific password set" "$([[ -n "$(config_get APPLE_APP_SPECIFIC_PASSWORD)" ]] && echo true || echo false)"
    _check "Certificate .p12 exported" "$([[ -n "$(config_get APPLE_CERTIFICATE_P12_B64)" ]] && echo true || echo false)"
    _check "iOS provisioning profile" "$([[ -n "$(config_get IOS_PROVISIONING_PROFILE_B64)" ]] && echo true || echo false)"
    _check "macOS provisioning profile" "$([[ -n "$(config_get MACOS_PROVISIONING_PROFILE_B64)" ]] && echo true || echo false)"
    _check "Android keystore exists" "$([[ -f "$(config_get ANDROID_KEYSTORE_PATH 2>/dev/null || echo /nonexistent)" ]] && echo true || echo false)"
    _check "Android key.properties exists" "$([[ -f "${PROJECT_ROOT}/android/key.properties" ]] && echo true || echo false)"

    echo ""
    echo "── GitHub Secrets ──"
    echo ""

    if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
        local repo
        repo=$(detect_github_repo)
        if [[ -n "$repo" ]]; then
            local secret_list
            secret_list=$(gh secret list -R "$repo" 2>/dev/null || true)

            local required_secrets=(
                "APPLE_CERTIFICATE_P12"
                "APPLE_CERTIFICATE_PASSWORD"
                "APPLE_TEAM_ID"
                "APPLE_ID"
                "APPLE_APP_SPECIFIC_PASSWORD"
                "KEYCHAIN_PASSWORD"
                "IOS_PROVISIONING_PROFILE"
                "MACOS_PROVISIONING_PROFILE"
                "ANDROID_KEYSTORE_BASE64"
                "ANDROID_KEYSTORE_PASSWORD"
                "ANDROID_KEY_ALIAS"
                "ANDROID_KEY_PASSWORD"
                "VERCEL_TOKEN"
                "VERCEL_ORG_ID"
                "VERCEL_PROJECT_ID"
            )

            for secret in "${required_secrets[@]}"; do
                _check "GitHub: $secret" "$(echo "$secret_list" | grep -q "^${secret}" && echo true || echo false)"
            done
        else
            warn "Could not detect GitHub repo — skipping secret verification"
        fi
    else
        warn "GitHub CLI not authenticated — skipping secret verification"
        echo -e "  ${DIM}Run: gh auth login${NC}"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${BOLD}  Result: ${passed}/${total} checks passed${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ $passed -lt $total ]]; then
        local missing=$((total - passed))
        echo "  To fix the $missing failing checks, run the relevant setup steps:"
        echo ""
        echo "    scripts/release-setup.sh apple     # Apple certificates"
        echo "    scripts/release-setup.sh profiles   # Provisioning profiles"
        echo "    scripts/release-setup.sh android    # Android keystore"
        echo "    scripts/release-setup.sh github     # Push secrets to GitHub"
        echo "    scripts/release-setup.sh vercel     # Vercel deployment"
        echo ""
    else
        success "All checks passed! You're ready to release."
        echo ""
        echo "  Next steps:"
        echo "    scripts/release.sh tag 0.1.0       # Tag and push a release"
        echo "    scripts/release.sh build --platform all  # Build all platforms locally"
        echo ""
    fi
}

# ── Full Setup Flow ──────────────────────────────────────────────────

full_setup() {
    echo ""
    echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║         Coqui Release Setup Wizard                   ║${NC}"
    echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  This wizard will walk you through setting up everything"
    echo "  needed to build, sign, and publish Coqui for all platforms."
    echo ""
    echo "  What we'll set up:"
    echo "    1. Prerequisites check"
    echo "    2. Apple signing certificate"
    echo "    3. Apple app-specific password"
    echo "    4. iOS + macOS provisioning profiles"
    echo "    5. Android release keystore"
    echo "    6. GitHub Actions secrets"
    echo "    7. Vercel deployment (web)"
    echo ""
    echo "  Everything is stored in: ~/.coqui-release/"
    echo "  You can re-run any step independently."
    echo ""

    if ! confirm "Ready to begin?"; then
        echo "  Run any step individually:"
        echo "    scripts/release-setup.sh apple"
        echo "    scripts/release-setup.sh profiles"
        echo "    scripts/release-setup.sh android"
        echo "    scripts/release-setup.sh github"
        echo "    scripts/release-setup.sh vercel"
        echo "    scripts/release-setup.sh verify"
        return 0
    fi

    check_prerequisites

    if [[ "$(uname -s)" == "Darwin" ]]; then
        setup_apple
        setup_apple_password
        setup_profiles
    else
        warn "Skipping Apple setup (not on macOS)."
        echo "  Run Apple setup steps on a Mac, then use 'github' to push secrets."
    fi

    setup_android

    if confirm "Set up GitHub secrets now?"; then
        setup_github
    fi

    if confirm "Set up Vercel deployment?"; then
        setup_vercel
    fi

    verify
}

# ── Main ─────────────────────────────────────────────────────────────

case "${1:-}" in
    apple)       setup_apple && setup_apple_password ;;
    profiles)    setup_profiles ;;
    android)     setup_android ;;
    github)      setup_github ;;
    vercel)      setup_vercel ;;
    verify)      verify ;;
    -h|--help)
        echo "Usage: scripts/release-setup.sh [command]"
        echo ""
        echo "Commands:"
        echo "  (none)      Run full setup wizard"
        echo "  apple       Apple certificate + app-specific password setup"
        echo "  profiles    iOS + macOS provisioning profile setup"
        echo "  android     Android keystore setup"
        echo "  github      Push all secrets to GitHub Actions"
        echo "  vercel      Vercel deployment setup"
        echo "  verify      Verify all signing requirements"
        ;;
    "")          full_setup ;;
    *)
        echo "Unknown command: $1" >&2
        echo "Run: scripts/release-setup.sh --help" >&2
        exit 1
        ;;
esac
