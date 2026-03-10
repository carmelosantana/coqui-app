# Package a Flutter Windows release build into a zip archive.
#
# Usage:
#   scripts/package-windows.ps1 -Version 0.1.0 [-Arch x64] [-BundlePath <path>] [-OutputDir <path>]

param(
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [string]$Arch = "x64",

    [string]$BundlePath = "build\windows\x64\runner\Release",

    [string]$OutputDir = "build\windows"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $BundlePath)) {
    Write-Error "Bundle not found at $BundlePath"
    exit 1
}

$archiveName = "Coqui-${Version}-windows-${Arch}"
$archivePath = Join-Path $OutputDir "${archiveName}.zip"

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "[package] Creating ${archivePath}..."

# Create a temporary staging directory
$stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$stagingTarget = Join-Path $stagingDir $archiveName
New-Item -ItemType Directory -Path $stagingTarget -Force | Out-Null

try {
    # Copy build output into the staging directory
    Copy-Item -Path (Join-Path $BundlePath "*") -Destination $stagingTarget -Recurse -Force

    # Create zip archive
    if (Test-Path $archivePath) {
        Remove-Item $archivePath -Force
    }
    Compress-Archive -Path $stagingTarget -DestinationPath $archivePath -CompressionLevel Optimal

    Write-Host "[done] ${archivePath}"

    # GitHub Actions output
    if ($env:GITHUB_OUTPUT) {
        "artifact-path=${archivePath}" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
        "artifact-name=${archiveName}.zip" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    }
}
finally {
    # Cleanup staging directory
    if (Test-Path $stagingDir) {
        Remove-Item -Path $stagingDir -Recurse -Force
    }
}
