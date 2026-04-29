# filter_repo_remove_secret.ps1 -- DESTRUCTIVE history rewrite.
# DO NOT RUN automatically. This is a template for the user to invoke manually
# when gitleaks finds a real secret committed in the past.
#
# Pre-requisites:
#   1. python -m pip install --user git-filter-repo
#   2. mirror clone of the repo to a side path (BACKUP):
#        git clone --mirror <upstream> ../portfolio_manager.bak.git
#   3. Manually inspect .claude/plan/output/gitleaks_report.json and pick the
#      exact secret strings to redact.
#
# Usage example:
#   powershell -NoProfile -ExecutionPolicy Bypass -File `
#       scripts/security/filter_repo_remove_secret.ps1 `
#       -Replacements @{ "AKIAxxxxxxxxxxxxxxxx" = "REDACTED_AWS_KEY" }
#
# After it runs:
#   - all collaborators must re-clone (history hashes have changed)
#   - tags and branches need force-push: git push --force --all && git push --force --tags
#   - rotate the leaked credential at the provider side anyway

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Replacements,

    [string]$ReplacementsFile = ".claude/plan/output/filter_repo_replacements.txt"
)

$ErrorActionPreference = "Stop"

$repoRoot = git rev-parse --show-toplevel
if (-not $repoRoot) {
    Write-Host "[filter-repo] not inside a git repo." -ForegroundColor Red
    exit 1
}

Push-Location $repoRoot
try {
    Write-Host "[filter-repo] checking git-filter-repo availability..." -ForegroundColor Cyan
    $check = & python -m git_filter_repo --version 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[filter-repo] git-filter-repo not installed." -ForegroundColor Red
        Write-Host "  Install with: python -m pip install --user git-filter-repo" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "[filter-repo] OK -- $check" -ForegroundColor Green

    Write-Host ""
    Write-Host "DANGER: this rewrites git history. Confirm you have a backup mirror." -ForegroundColor Red
    Write-Host "Type 'YES-REWRITE' to continue, anything else aborts:" -ForegroundColor Red
    $confirm = Read-Host
    if ($confirm -ne "YES-REWRITE") {
        Write-Host "[filter-repo] aborted by user." -ForegroundColor Yellow
        exit 0
    }

    # Build the replacements file expected by --replace-text
    $reportDir = Split-Path $ReplacementsFile -Parent
    if ($reportDir -and -not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    $lines = foreach ($key in $Replacements.Keys) {
        # format: literal:<secret>==><replacement>
        "literal:" + $key + "==>" + $Replacements[$key]
    }
    $lines | Set-Content -Path $ReplacementsFile -Encoding utf8

    Write-Host "[filter-repo] running rewrite with replacements file: $ReplacementsFile" -ForegroundColor Cyan
    & python -m git_filter_repo --replace-text $ReplacementsFile --force
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[filter-repo] FAILED" -ForegroundColor Red
        exit $LASTEXITCODE
    }

    Write-Host ""
    Write-Host "[filter-repo] done. Next steps for the user (in this order):" -ForegroundColor Green
    Write-Host "  1. ROTATE THE LEAKED CREDENTIAL AT THE PROVIDER FIRST." -ForegroundColor Yellow
    Write-Host "     History rewrite does not invalidate the credential -- the old"
    Write-Host "     value is already public via clones, forks, archives, and CDN"
    Write-Host "     caches. Rotation is the only thing that actually mitigates."
    Write-Host "  2. Verify with: gitleaks detect --source . --config .gitleaks.toml"
    Write-Host "  3. Force-push: git push --force --all; git push --force --tags"
    Write-Host "  4. Notify all collaborators to re-clone the repo"
} finally {
    Pop-Location
}
