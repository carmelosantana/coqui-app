#!/usr/bin/env bash
set -euo pipefail

# Package a Flutter Linux release build into a tar.gz archive.
#
# Usage:
#   scripts/package-linux.sh --version 0.1.0 [options]
#
# Required:
#   --version VERSION       Semantic version (e.g. 0.1.0)
#
# Options:
#   --arch ARCH             Architecture label (default: x64)
#   --bundle-path PATH      Path to Flutter bundle (default: build/linux/x64/release/bundle)
#   --output-dir DIR        Output directory (default: build/linux)
#   -h, --help              Show this help

usage() {
  sed -n '3,16p' "$0" | sed 's/^# \?//'
}

version=""
arch="x64"
bundlePath="build/linux/x64/release/bundle"
outputDir="build/linux"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) version="${2:-}"; shift 2 ;;
    --arch) arch="${2:-}"; shift 2 ;;
    --bundle-path) bundlePath="${2:-}"; shift 2 ;;
    --output-dir) outputDir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ -z "$version" ]]; then
  echo "Error: --version is required." >&2
  usage >&2
  exit 1
fi

if [[ ! -d "$bundlePath" ]]; then
  echo "Error: bundle not found at $bundlePath" >&2
  exit 1
fi

archiveName="Coqui-${version}-linux-${arch}"
archivePath="${outputDir}/${archiveName}.tar.gz"

mkdir -p "$outputDir"

echo "[package] Creating ${archivePath}..."

# Create a clean staging directory with the expected top-level folder name
stagingDir="$(mktemp -d)"
trap 'rm -rf "$stagingDir"' EXIT

cp -a "$bundlePath" "${stagingDir}/${archiveName}"

# Create tar.gz from the staging directory
tar -czf "$archivePath" -C "$stagingDir" "$archiveName"

echo "[done] ${archivePath}"
echo "::set-output name=artifact-path::${archivePath}"
echo "::set-output name=artifact-name::${archiveName}.tar.gz"
