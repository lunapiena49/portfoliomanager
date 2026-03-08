#!/usr/bin/env pwsh
<#!
.SYNOPSIS
Downloads latest market snapshot artifacts from GitHub Pages into dist/market-data.

.EXAMPLE
./scripts/eodhd/sync_market_snapshot_from_pages.ps1
./scripts/eodhd/sync_market_snapshot_from_pages.ps1 -Owner lunapiena49 -Repo portfoliomanager
#>
param(
    [string]$Owner = "lunapiena49",
    [string]$Repo = "portfoliomanager",
    [string]$OutputDir = "dist/market-data"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step([string]$message) {
    Write-Host "`n==> $message" -ForegroundColor Cyan
}

function Write-Ok([string]$message) {
    Write-Host "    OK: $message" -ForegroundColor Green
}

$baseUrl = "https://$Owner.github.io/$Repo"
$files = @(
    "top_movers.json",
    "prices_index.json",
    "daily_market.db.zip",
    "market_history.db.zip"
)

Write-Step "Preparing output directory"
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
Write-Ok "Output: $OutputDir"

Write-Step "Downloading artifacts from $baseUrl"
foreach ($file in $files) {
    $uri = "$baseUrl/$file"
    $target = Join-Path $OutputDir $file
    Write-Host "  -> $uri"
    Invoke-WebRequest -Uri $uri -OutFile $target
    $sizeMb = [Math]::Round(((Get-Item $target).Length / 1MB), 2)
    Write-Ok "$file ($sizeMb MB)"
}

Write-Host "`n[done] Market snapshot artifacts are up to date in $OutputDir" -ForegroundColor Green
