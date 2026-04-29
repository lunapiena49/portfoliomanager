# install_hooks.ps1 -- enable the versioned .githooks/ directory for this repo.
# Run once after clone or when toggling hook activation.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts/security/install_hooks.ps1
#
# What it does:
#   git config core.hooksPath .githooks
# That single line makes git pick up scripts under .githooks/ (versioned)
# instead of the local-only .git/hooks/.

$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Host "[hooks] not inside a git repo." -ForegroundColor Red
    exit 1
}

Push-Location $repoRoot
try {
    & git config core.hooksPath .githooks
    Write-Host "[hooks] core.hooksPath -> .githooks (versioned)" -ForegroundColor Green
    Write-Host "[hooks] active hooks:" -ForegroundColor Cyan
    Get-ChildItem .githooks -File | ForEach-Object { Write-Host "  - $($_.Name)" }
} finally {
    Pop-Location
}
