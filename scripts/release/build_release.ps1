# build_release.ps1
# One-shot Portfolio Manager release builder.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\build_release.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\build_release.ps1 -Targets aab,apk
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\release\build_release.ps1 -Targets web
#
# Behavior:
#   - Runs flutter analyze + flutter test as a hard gate (fail = no build).
#   - Builds the requested targets with --obfuscate and per-version
#     --split-debug-info, then archives the symbols under
#     ~/.plurifin/symbols/<version>/<target>/.
#   - Generates symbols-manifest.json with sha256 hashes so de-obfuscation
#     can verify integrity before consuming a symbols set.
#   - Never commits anything. Caller is responsible for tagging + pushing.
#
# ASCII-only by design (Windows PowerShell 5.1 reads .ps1 as Windows-1252).

[CmdletBinding()]
param(
    [ValidateSet("aab", "apk", "web")]
    [string[]]$Targets = @("aab", "apk"),
    [string]$BaseHref = "/portfoliomanager-data/app/",
    [string]$MarketSnapshotBaseUrl =
        "https://lunapiena49.github.io/portfoliomanager-data",
    [switch]$SkipGate
)

$ErrorActionPreference = "Stop"

function Write-Section($Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Get-PubspecVersion {
    $pubspec = Join-Path $PSScriptRoot "..\..\pubspec.yaml"
    $line = (Get-Content $pubspec | Where-Object { $_ -match '^version:' })[0]
    if (-not $line) { throw "Cannot read version from pubspec.yaml" }
    $value = ($line -replace '^version:\s*', '').Trim()
    return $value
}

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
}

function Invoke-Flutter {
    param([string[]]$Args)
    & flutter @Args
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Args -join ' ') failed with exit code $LASTEXITCODE."
    }
}

function Invoke-Gate {
    Write-Section "Gate: flutter analyze"
    Invoke-Flutter @("analyze", "--no-fatal-infos")

    Write-Section "Gate: flutter test"
    Invoke-Flutter @("test", "--no-pub")
}

function Compute-Sha256($Path) {
    $hash = Get-FileHash -Algorithm SHA256 -Path $Path
    return $hash.Hash.ToLower()
}

function Save-SymbolManifest {
    param(
        [string]$Target,
        [string]$Version,
        [string]$SymbolsDir,
        [string]$ArchiveDir
    )

    if (-not (Test-Path $SymbolsDir)) {
        Write-Host "  [skip] No symbols generated for $Target" -ForegroundColor Yellow
        return
    }

    $files = Get-ChildItem -Path $SymbolsDir -Recurse -File
    if ($files.Count -eq 0) {
        Write-Host "  [skip] Empty symbols dir for $Target" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $ArchiveDir)) {
        New-Item -ItemType Directory -Path $ArchiveDir -Force | Out-Null
    }

    $manifestEntries = @()
    foreach ($file in $files) {
        $destination = Join-Path $ArchiveDir $file.Name
        Copy-Item -Path $file.FullName -Destination $destination -Force
        $manifestEntries += [pscustomobject]@{
            name   = $file.Name
            sha256 = Compute-Sha256 $destination
            size   = (Get-Item $destination).Length
        }
    }

    $manifest = [pscustomobject]@{
        version  = $Version
        target   = $Target
        builtAt  = (Get-Date).ToUniversalTime().ToString("o")
        symbols  = $manifestEntries
    }

    $manifestPath = Join-Path $ArchiveDir "symbols-manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Out-File -FilePath $manifestPath -Encoding utf8
    Write-Host "  Symbols archived: $ArchiveDir"
}

# ---- Setup ----
$repoRoot = Get-RepoRoot
Set-Location $repoRoot

if (-not $SkipGate) {
    Invoke-Gate
} else {
    Write-Host "Skipping analyze + test gate (forced via -SkipGate)." -ForegroundColor Yellow
}

$version = Get-PubspecVersion
$versionShort = ($version -split '\+')[0]
Write-Section "Building Portfolio Manager v$version"

$symbolsRoot = Join-Path $env:USERPROFILE ".plurifin\symbols\$versionShort"
if (-not (Test-Path $symbolsRoot)) {
    New-Item -ItemType Directory -Path $symbolsRoot -Force | Out-Null
}

# ---- Targets ----
foreach ($target in $Targets) {
    switch ($target) {
        "aab" {
            Write-Section "Build: Android App Bundle (release)"
            $debugSymbolsDir = "build/symbols/android/$versionShort"
            Invoke-Flutter @(
                "build", "appbundle",
                "--release",
                "--obfuscate",
                "--split-debug-info=$debugSymbolsDir"
            )
            Save-SymbolManifest -Target "android-aab" -Version $versionShort `
                -SymbolsDir $debugSymbolsDir `
                -ArchiveDir (Join-Path $symbolsRoot "android-aab")
            Write-Host "  Output: build/app/outputs/bundle/release/app-release.aab"
        }
        "apk" {
            Write-Section "Build: Android APK (release, sideload-friendly)"
            $debugSymbolsDir = "build/symbols/android/$versionShort"
            Invoke-Flutter @(
                "build", "apk",
                "--release",
                "--obfuscate",
                "--split-debug-info=$debugSymbolsDir"
            )
            Save-SymbolManifest -Target "android-apk" -Version $versionShort `
                -SymbolsDir $debugSymbolsDir `
                -ArchiveDir (Join-Path $symbolsRoot "android-apk")
            Write-Host "  Output: build/app/outputs/flutter-apk/app-release.apk"
        }
        "web" {
            Write-Section "Build: Web (release)"
            $debugSymbolsDir = "build/symbols/web/$versionShort"
            Invoke-Flutter @(
                "build", "web",
                "--release",
                "--obfuscate",
                "--split-debug-info=$debugSymbolsDir",
                "--base-href=$BaseHref",
                "--dart-define=MARKET_SNAPSHOT_BASE_URL=$MarketSnapshotBaseUrl",
                "--dart-define=APP_DEPLOYMENT=web"
            )
            Save-SymbolManifest -Target "web" -Version $versionShort `
                -SymbolsDir $debugSymbolsDir `
                -ArchiveDir (Join-Path $symbolsRoot "web")
            Write-Host "  Output: build/web/"
        }
    }
}

Write-Section "Done"
Write-Host "Symbols archive: $symbolsRoot"
Write-Host ""
Write-Host "Reminder: keep the symbols archive together with the release tag." -ForegroundColor Yellow
Write-Host "Crash reports from Play Console / Sentry need them to de-obfuscate stack traces."
