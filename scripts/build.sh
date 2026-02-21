#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  scripts/build.sh --platform PLATFORM --mode MODE [options]

Required:
  --platform macos|ios|linux|android|windows|all
  --mode debug|release

Options:
  --image PATH            Source icon image for padding (default: assets/images/coqui-icon.png)
  --inner-size VALUE      Inner artwork size (e.g. 83% or 860). Default: 83%
  --padding PERCENT       Alternate to --inner-size (mutually exclusive)
  --no-icons              Skip icon padding + launcher icon generation
  --no-backup             Do not create backup when padding icon
  --no-open               Do not open built artifact/folder after build
  --dry-run               Print commands without executing
  -h, --help              Show this help

Examples:
  scripts/build.sh --platform macos --mode debug
  scripts/build.sh --platform ios --mode release
  scripts/build.sh --platform all --mode debug
  scripts/build.sh --platform macos --mode release --inner-size 82%
EOF
}

scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
projectRoot="$(cd "$scriptDir/.." && pwd)"

platform=""
mode=""
imagePath="assets/images/coqui-icon.png"
innerSize="83%"
padding=""
runIcons='true'
createBackup='true'
openAfterBuild='true'
dryRun='false'

while [[ $# -gt 0 ]]; do
  case "$1" in
    --platform)
      platform="${2:-}"
      shift 2
      ;;
    --mode)
      mode="${2:-}"
      shift 2
      ;;
    --image)
      imagePath="${2:-}"
      shift 2
      ;;
    --inner-size)
      innerSize="${2:-}"
      shift 2
      ;;
    --padding)
      padding="${2:-}"
      shift 2
      ;;
    --no-icons)
      runIcons='false'
      shift
      ;;
    --no-backup)
      createBackup='false'
      shift
      ;;
    --no-open)
      openAfterBuild='false'
      shift
      ;;
    --dry-run)
      dryRun='true'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$platform" || -z "$mode" ]]; then
  echo "Error: --platform and --mode are required." >&2
  usage >&2
  exit 1
fi

case "$platform" in
  macos|ios|linux|android|windows|all) ;;
  *)
    echo "Error: invalid --platform: $platform" >&2
    exit 1
    ;;
esac

case "$mode" in
  debug|release) ;;
  *)
    echo "Error: invalid --mode: $mode" >&2
    exit 1
    ;;
esac

if [[ -n "$padding" && -n "$innerSize" ]]; then
  if [[ "$innerSize" != "83%" ]]; then
    echo "Error: use either --inner-size or --padding, not both." >&2
    exit 1
  fi
fi

hostOs="$(uname -s)"
hostPlatform='unknown'
case "$hostOs" in
  Darwin) hostPlatform='macos' ;;
  Linux) hostPlatform='linux' ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT) hostPlatform='windows' ;;
esac

runCmd() {
  local command="$1"
  if [[ "$dryRun" == 'true' ]]; then
    echo "[dry-run] $command"
  else
    echo "[run] $command"
    eval "$command"
  fi
}

warn() {
  echo "[warn] $1"
}

info() {
  echo "[info] $1"
}

cleanupOldArtifact() {
  local target="$1"
  local targetMode="$2"

  case "$target" in
    macos)
      if [[ "$targetMode" == 'debug' ]]; then
        runCmd "rm -rf '$projectRoot/build/macos/Build/Products/Debug/Coqui.app'"
      else
        runCmd "rm -rf '$projectRoot/build/macos/Build/Products/Release/Coqui.app'"
      fi
      ;;
    ios)
      if [[ "$targetMode" == 'debug' ]]; then
        runCmd "rm -rf '$projectRoot/build/ios/iphoneos'"
      else
        runCmd "rm -rf '$projectRoot/build/ios/ipa' '$projectRoot/build/ios/archive'"
      fi
      ;;
    linux)
      runCmd "rm -rf '$projectRoot/build/linux'"
      ;;
    android)
      runCmd "rm -rf '$projectRoot/build/app/outputs/flutter-apk' '$projectRoot/build/app/outputs/bundle'"
      ;;
    windows)
      runCmd "rm -rf '$projectRoot/build/windows'"
      ;;
  esac
}

openPath() {
  local path="$1"
  if [[ "$openAfterBuild" != 'true' ]]; then
    return
  fi

  if [[ "$dryRun" == 'true' ]]; then
    case "$hostPlatform" in
      macos)
        runCmd "open '$path'"
        ;;
      linux)
        runCmd "xdg-open '$path'"
        ;;
      windows)
        runCmd "cmd /c start '' '$path'"
        ;;
      *)
        warn "Unknown host platform; open manually: $path"
        ;;
    esac
    return
  fi

  if [[ ! -e "$path" ]]; then
    warn "Open skipped; path not found: $path"
    return
  fi

  case "$hostPlatform" in
    macos)
      runCmd "open '$path'"
      ;;
    linux)
      if command -v xdg-open >/dev/null 2>&1; then
        runCmd "xdg-open '$path'"
      else
        warn "xdg-open not found; open manually: $path"
      fi
      ;;
    windows)
      runCmd "cmd /c start '' '$path'"
      ;;
    *)
      warn "Unknown host platform; open manually: $path"
      ;;
  esac
}

buildTarget() {
  local target="$1"
  local targetMode="$2"

  case "$target" in
    macos)
      if [[ "$hostPlatform" != 'macos' ]]; then
        warn "Skipping macOS build: requires macOS host."
        return
      fi
      cleanupOldArtifact "macos" "$targetMode"
      runCmd "cd '$projectRoot' && flutter build macos --$targetMode"
      if [[ "$targetMode" == 'debug' ]]; then
        openPath "$projectRoot/build/macos/Build/Products/Debug/Coqui.app"
      else
        openPath "$projectRoot/build/macos/Build/Products/Release/Coqui.app"
      fi
      ;;
    ios)
      if [[ "$hostPlatform" != 'macos' ]]; then
        warn "Skipping iOS build: requires macOS host + Xcode."
        return
      fi
      cleanupOldArtifact "ios" "$targetMode"
      if [[ "$targetMode" == 'debug' ]]; then
        runCmd "cd '$projectRoot' && flutter build ios --debug"
        openPath "$projectRoot/build/ios/iphoneos"
      else
        runCmd "cd '$projectRoot' && flutter build ipa --release"
        openPath "$projectRoot/build/ios/ipa"
      fi
      ;;
    linux)
      if [[ "$hostPlatform" != 'linux' ]]; then
        warn "Skipping Linux build: requires Linux host."
        return
      fi
      cleanupOldArtifact "linux" "$targetMode"
      runCmd "cd '$projectRoot' && flutter build linux --$targetMode"
      openPath "$projectRoot/build/linux"
      ;;
    android)
      cleanupOldArtifact "android" "$targetMode"
      if [[ "$targetMode" == 'debug' ]]; then
        runCmd "cd '$projectRoot' && flutter build apk --debug"
        openPath "$projectRoot/build/app/outputs/flutter-apk"
      else
        runCmd "cd '$projectRoot' && flutter build appbundle --release"
        openPath "$projectRoot/build/app/outputs/bundle/release"
      fi
      ;;
    windows)
      if [[ "$hostPlatform" != 'windows' ]]; then
        warn "Skipping Windows build: use a Windows host (or Windows CI runner). Wine cross-build is not supported for reliable Flutter desktop release builds."
        return
      fi
      cleanupOldArtifact "windows" "$targetMode"
      runCmd "cd '$projectRoot' && flutter build windows --$targetMode"
      openPath "$projectRoot/build/windows"
      ;;
  esac
}

runIconPipeline() {
  if [[ "$runIcons" != 'true' ]]; then
    info "Icon pipeline skipped (--no-icons)."
    return
  fi

  local padCmd
  padCmd="cd '$projectRoot' && ./scripts/pad-icon.sh --image '$imagePath'"

  if [[ -n "$padding" ]]; then
    padCmd+=" --padding '$padding'"
  else
    padCmd+=" --inner-size '$innerSize'"
  fi

  if [[ "$createBackup" == 'true' ]]; then
    padCmd+=" --backup"
  fi

  runCmd "$padCmd"
  runCmd "cd '$projectRoot' && dart run flutter_launcher_icons"
}

resolveTargets() {
  case "$platform" in
    all)
      if [[ "$hostPlatform" == 'macos' ]]; then
        echo "macos ios android linux windows"
      elif [[ "$hostPlatform" == 'linux' ]]; then
        echo "linux android windows macos ios"
      elif [[ "$hostPlatform" == 'windows' ]]; then
        echo "windows android linux macos ios"
      else
        echo "macos ios android linux windows"
      fi
      ;;
    *)
      echo "$platform"
      ;;
  esac
}

info "Host platform: $hostPlatform"
info "Requested platform: $platform"
info "Build mode: $mode"

runIconPipeline

for target in $(resolveTargets); do
  info "Starting target: $target"
  buildTarget "$target" "$mode"
done

info "Build script completed."
