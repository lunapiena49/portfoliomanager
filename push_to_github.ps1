#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Stage, commit and push all changes to the current Git branch.

.PARAMETER Message
    Commit message.  Defaults to an auto-generated message with timestamp.

.PARAMETER Branch
    Branch to push to.  Defaults to the currently checked-out branch.

.PARAMETER Remote
    Git remote name.  Defaults to "origin".

.EXAMPLE
    .\push_to_github.ps1
    .\push_to_github.ps1 -Message "feat: aggiorno pipeline rolling history"
    .\push_to_github.ps1 -Message "fix: correzione" -Branch main
#>
param(
    [string]$Message = "",
    [string]$Branch  = "",
    [string]$Remote  = "origin"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── helpers ──────────────────────────────────────────────────────────────────
function Write-Step([string]$text) {
    Write-Host "`n==> $text" -ForegroundColor Cyan
}
function Write-Ok([string]$text) {
    Write-Host "    OK: $text" -ForegroundColor Green
}
function Write-Warn([string]$text) {
    Write-Host "    WARN: $text" -ForegroundColor Yellow
}
function Invoke-Git([string[]]$args) {
    $result = & git @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    git $($args -join ' ') failed:`n$result" -ForegroundColor Red
        exit 1
    }
    return $result
}

# ── resolve branch ────────────────────────────────────────────────────────────
Write-Step "Checking Git repository..."
$repoRoot = Invoke-Git @("rev-parse", "--show-toplevel")
$repoRoot = $repoRoot.Trim()
Write-Ok "Repo root: $repoRoot"

if (-not $Branch) {
    $Branch = (Invoke-Git @("rev-parse", "--abbrev-ref", "HEAD")).Trim()
    Write-Ok "Current branch: $Branch"
}

if ($Branch -eq "HEAD") {
    Write-Host "    ERROR: detached HEAD state. Checkout a branch first." -ForegroundColor Red
    exit 1
}

# ── check for changes ────────────────────────────────────────────────────────
Write-Step "Checking for changes..."
$status = Invoke-Git @("status", "--porcelain")
if (-not $status) {
    Write-Warn "Nothing to commit. Working tree is clean."
    exit 0
}
Write-Host $status

# ── stage all ────────────────────────────────────────────────────────────────
Write-Step "Staging all changes..."
Invoke-Git @("add", "-A") | Out-Null
Write-Ok "All changes staged."

# ── build commit message ─────────────────────────────────────────────────────
if (-not $Message) {
    $ts = (Get-Date -Format "yyyy-MM-dd HH:mm")
    $Message = "chore: aggiornamento pipeline e app [$ts]"
}
Write-Ok "Commit message: $Message"

# ── commit ───────────────────────────────────────────────────────────────────
Write-Step "Committing..."
Invoke-Git @("commit", "-m", $Message) | Out-Null
Write-Ok "Commit created."

# ── push ─────────────────────────────────────────────────────────────────────
Write-Step "Pushing to $Remote/$Branch..."
Invoke-Git @("push", $Remote, $Branch) | Out-Null
Write-Ok "Push completed."

Write-Host "`n[done] Changes pushed to $Remote/$Branch" -ForegroundColor Green
